#!/usr/bin/env python3
"""Execute an ordered Ghidra analyzeHeadless manifest in an isolated project."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


TOKENS = ("$OUTPUT_DIR", "$PROJECT_DIR")


def substitute(value, output_dir, project_dir):
    if not isinstance(value, str):
        return value
    return value.replace(TOKENS[0], str(output_dir)).replace(TOKENS[1], str(project_dir))


def append_scripts(command, flag, scripts, output_dir, project_dir):
    for script in scripts:
        command.extend([flag, substitute(script["name"], output_dir, project_dir)])
        command.extend(substitute(arg, output_dir, project_dir) for arg in script.get("args", []))


def command_for(analyzer, project_dir, project_name, step, output_dir, staged_scripts):
    command = [str(analyzer), str(project_dir), project_name]
    action = step.get("action")
    if action == "import":
        command.extend(["-import", substitute(step["input"], output_dir, project_dir)])
    elif action == "process":
        command.extend(["-process", step["program"]])
    else:
        raise ValueError("step action must be 'import' or 'process': %r" % action)

    for key, flag in (("processor", "-processor"), ("cspec", "-cspec"), ("loader", "-loader")):
        if step.get(key):
            command.extend([flag, step[key]])
    if step.get("overwrite"):
        command.append("-overwrite")
    if step.get("noanalysis"):
        command.append("-noanalysis")
    if step.get("read_only"):
        command.append("-readOnly")
    if step.get("analysis_timeout"):
        command.extend(["-analysisTimeoutPerFile", str(step["analysis_timeout"])])
    command.extend(substitute(arg, output_dir, project_dir) for arg in step.get("extra_args", []))

    script_paths = [str(staged_scripts)] if staged_scripts else []
    script_paths.extend(substitute(path, output_dir, project_dir) for path in step.get("script_paths", []))
    if script_paths:
        command.extend(["-scriptPath", os.pathsep.join(script_paths)])
    append_scripts(command, "-preScript", step.get("pre_scripts", []), output_dir, project_dir)
    append_scripts(command, "-postScript", step.get("post_scripts", []), output_dir, project_dir)
    return command


def run_command(command, windows, env, timeout, log):
    display = subprocess.list2cmdline(command) if windows else " ".join(command)
    log.write("COMMAND %s\n" % display)
    log.flush()
    if windows:
        # Pass one literal command line. A list would make subprocess escape
        # the inner quotes around arguments containing spaces, and cmd.exe
        # would then see \" sequences and fail with "... was unexpected".
        actual = 'cmd.exe /d /s /c "%s"' % display
    else:
        actual = command
    started = time.monotonic()
    process = subprocess.run(
        actual,
        env=env,
        stdout=log,
        stderr=subprocess.STDOUT,
        timeout=timeout if timeout else None,
        check=False,
    )
    log.write("EXIT %d elapsed=%.3fs\n" % (process.returncode, time.monotonic() - started))
    log.flush()
    if process.returncode:
        raise RuntimeError("analyzeHeadless exited with code %d" % process.returncode)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--analyzer", required=True)
    parser.add_argument("--java-home", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--project-name", required=True)
    parser.add_argument("--script", action="append", default=[])
    parser.add_argument("--timeout", type=int, default=0)
    parser.add_argument("--windows", action="store_true")
    args = parser.parse_args()

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    # Ghidra rejects project path elements beginning with a dot. The project is
    # already disposable and removed in the finally block, so it need not be
    # hidden from directory listings.
    project_dir = output_dir / "ghidra-project"
    environment_root = output_dir / ".ghidra-environment"
    for directory in (project_dir, environment_root):
        directory.mkdir(parents=True, exist_ok=True)

    staged_scripts = None
    if args.script:
        staged_scripts = environment_root / "scripts"
        staged_scripts.mkdir(parents=True, exist_ok=True)
        names = set()
        for source_text in args.script:
            source = Path(source_text).resolve()
            if source.name in names:
                raise ValueError("Ghidra script basename appears more than once: %s" % source.name)
            names.add(source.name)
            shutil.copy2(source, staged_scripts / source.name)

    with open(args.manifest, "r", encoding="utf-8") as stream:
        manifest = json.load(stream)
    steps = manifest.get("steps", [])
    if not steps:
        raise ValueError("the Ghidra pipeline contains no steps")

    env = os.environ.copy()
    env.update({
        "APPDATA": str(environment_root / "appdata"),
        "HOME": str(environment_root / "home"),
        "JAVA_HOME": str(Path(args.java_home).resolve()),
        "LOCALAPPDATA": str(environment_root / "localappdata"),
        "USERPROFILE": str(environment_root / "profile"),
    })
    for value in env.values():
        if value.startswith(str(environment_root)):
            Path(value).mkdir(parents=True, exist_ok=True)

    log_path = environment_root / "ghidra-pipeline.log"
    try:
        with log_path.open("w", encoding="utf-8", newline="\n") as log:
            for index, step in enumerate(steps, 1):
                log.write("STEP %d/%d\n" % (index, len(steps)))
                command = command_for(
                    Path(args.analyzer).resolve(),
                    project_dir,
                    args.project_name,
                    step,
                    output_dir,
                    staged_scripts,
                )
                run_command(command, args.windows, env, args.timeout, log)

        missing = []
        invalid = []
        for marker in manifest.get("completion_markers", []):
            marker_path = output_dir / marker["path"]
            if not marker_path.is_file():
                missing.append(marker["path"])
            elif marker.get("contains") is not None:
                contents = marker_path.read_text(encoding="utf-8")
                if marker["contains"] not in contents:
                    invalid.append("%s does not contain %r" % (marker["path"], marker["contains"]))
        if missing:
            raise RuntimeError("missing Ghidra completion markers: %s" % ", ".join(missing))
        if invalid:
            raise RuntimeError("invalid Ghidra completion markers: %s" % "; ".join(invalid))
    except Exception:
        if log_path.is_file():
            print("--- Ghidra pipeline log ---", file=sys.stderr)
            print(log_path.read_text(encoding="utf-8", errors="replace"), file=sys.stderr)
            print("--- end Ghidra pipeline log ---", file=sys.stderr)
        raise
    finally:
        shutil.rmtree(project_dir, ignore_errors=True)
        shutil.rmtree(environment_root, ignore_errors=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.TimeoutExpired as error:
        print("Ghidra pipeline timed out: %s" % error, file=sys.stderr)
        sys.exit(124)
    except Exception as error:
        print("Ghidra pipeline failed: %s" % error, file=sys.stderr)
        sys.exit(1)
