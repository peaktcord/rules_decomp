"""Run a project script under the current interpreter and record success as a marker."""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def unquote(value):
    """Bazel shell-quotes $(location) paths containing spaces; scripts want the bare path."""
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1]
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--script", required=True)
    parser.add_argument("--marker", required=True, type=Path)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("--chdir", default="")
    parser.add_argument("script_args", nargs="*")
    args = parser.parse_args()

    execroot = Path.cwd()
    environment = os.environ.copy()
    for assignment in args.env:
        key, _, value = assignment.partition("=")
        environment[key] = unquote(value)
    # Scripts see the execroot so relative labels resolve without knowing Bazel.
    environment["EXECROOT"] = str(execroot)

    script = str(Path(args.script).resolve())
    command = [sys.executable, "-B", script] + [unquote(value) for value in args.script_args]
    cwd = str((execroot / args.chdir).resolve()) if args.chdir else None
    marker = args.marker.resolve()
    log_path = args.log.resolve()
    log_path.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        command,
        env=environment,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
    )
    log_path.write_text(result.stdout, encoding="utf-8", newline="\n")
    if result.returncode:
        sys.stderr.write(result.stdout)
        sys.stderr.write("check failed (%d): %s\n" % (result.returncode, subprocess.list2cmdline(command)))
        return 1
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text("ok\n", encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
