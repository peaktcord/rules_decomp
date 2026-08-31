"""Hermetic boundaries for headless and interactive Ghidra workflows."""

load("//toolchains/ghidra:toolchain.bzl", "GHIDRA_TOOLCHAIN_TYPE")
load("//toolchains/pypy:toolchain.bzl", "PYPY_TOOLCHAIN_TYPE")
load("//decomp:verified_inputs.bzl", "VerifiedFilesInfo")

def _private_requirements(private):
    requirements = {
        "local": "1",
        "no-remote-exec": "1",
    }
    if private:
        requirements.update({
            "no-remote": "1",
            "no-remote-cache": "1",
        })
    return requirements

def _ghidra_pipeline_impl(ctx):
    ghidra = ctx.toolchains[GHIDRA_TOOLCHAIN_TYPE]
    pypy = ctx.toolchains[PYPY_TOOLCHAIN_TYPE]
    output = ctx.actions.declare_directory(ctx.label.name)
    manifest = ctx.actions.declare_file(ctx.label.name + ".ghidra.json")
    expanded = ctx.expand_location(ctx.attr.manifest, targets = ctx.attr.srcs + ctx.attr.scripts)
    source_files = []
    for source in ctx.attr.srcs:
        source_files.extend(source[DefaultInfo].files.to_list())
        if VerifiedFilesInfo in source:
            verified = source[VerifiedFilesInfo]
            source_files.extend(verified.files.to_list())
            for verified_file in verified.files.to_list():
                expanded = expanded.replace(
                    "$VERIFIED(%s)" % verified_file.basename,
                    verified_file.path,
                )
    if "$VERIFIED(" in expanded:
        fail("unresolved $VERIFIED(basename) in Ghidra steps; add its verified_files target to srcs")
    ctx.actions.write(manifest, expanded)

    args = ctx.actions.args()
    args.add("-B")
    args.add(ctx.file._runner.path)
    args.add("--analyzer", ghidra.analyzer.path)
    args.add("--java-home", ghidra.java_home)
    args.add("--manifest", manifest.path)
    args.add("--output-dir", output.path)
    args.add("--project-name", ctx.attr.project_name)
    for script in ctx.files.scripts:
        args.add("--script", script.path)
    if ctx.attr.timeout:
        args.add("--timeout", ctx.attr.timeout)
    if ghidra.windows:
        args.add("--windows")

    ctx.actions.run(
        executable = pypy.interpreter,
        arguments = [args],
        inputs = depset(
            direct = [ctx.file._runner, manifest] + source_files + ctx.files.scripts,
            transitive = [ghidra.files, pypy.files],
        ),
        outputs = [output],
        mnemonic = "GhidraOracle" if ctx.attr.oracle else "GhidraPipeline",
        progress_message = "Running isolated Ghidra pipeline for %s" % ctx.label,
        execution_requirements = _private_requirements(ctx.attr.private),
        env = {
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONHASHSEED": "0",
        },
    )
    return [DefaultInfo(files = depset([output]))]

_ghidra_pipeline = rule(
    implementation = _ghidra_pipeline_impl,
    attrs = {
        "manifest": attr.string(mandatory = True),
        "oracle": attr.bool(default = False),
        "private": attr.bool(default = True),
        "project_name": attr.string(mandatory = True),
        "srcs": attr.label_list(allow_files = True),
        "scripts": attr.label_list(allow_files = True),
        "timeout": attr.int(default = 0),
        "_runner": attr.label(
            allow_single_file = [".py"],
            default = Label("//decomp:ghidra_runner.py"),
        ),
    },
    toolchains = [GHIDRA_TOOLCHAIN_TYPE, PYPY_TOOLCHAIN_TYPE],
)

def _validate_steps(steps, oracle):
    if not steps:
        fail("steps must contain at least one Ghidra invocation")
    for index, step in enumerate(steps):
        if type(step) != "dict":
            fail("steps[%d] must be a dict" % index)
        action = step.get("action")
        if action not in ("import", "process"):
            fail("steps[%d].action must be 'import' or 'process'" % index)
        if action == "import" and not step.get("input"):
            fail("steps[%d] import requires input" % index)
        if action == "process" and not step.get("program"):
            fail("steps[%d] process requires program" % index)
        if oracle and not step.get("noanalysis", False):
            fail("ghidra_oracle requires noanalysis=True in every step (steps[%d])" % index)

def ghidra_pipeline(
        name,
        steps,
        srcs = [],
        scripts = [],
        project_name = "Analysis",
        timeout = 0,
        private = True,
        **kwargs):
    """Run ordered analyzeHeadless imports/processes in one disposable project.

    Paths in steps may use $(location LABEL), $OUTPUT_DIR, and $PROJECT_DIR.
    Reports written below $OUTPUT_DIR comprise the rule's tree-artifact output.
    """
    _validate_steps(steps, False)
    _ghidra_pipeline(
        name = name,
        manifest = json.encode({"steps": steps}),
        oracle = False,
        private = private,
        project_name = project_name,
        srcs = srcs,
        scripts = scripts,
        timeout = timeout,
        **kwargs
    )

def ghidra_oracle(
        name,
        steps,
        completion_markers,
        srcs = [],
        scripts = [],
        project_name = "Oracle",
        timeout = 600,
        private = True,
        **kwargs):
    """Run deterministic Ghidra emulation and require declared marker files."""
    _validate_steps(steps, True)
    if not completion_markers:
        fail("ghidra_oracle requires at least one completion marker")
    normalized_markers = []
    for marker in completion_markers:
        if type(marker) == "string":
            normalized_markers.append({"path": marker})
        elif type(marker) == "dict" and marker.get("path"):
            normalized_markers.append(marker)
        else:
            fail("completion markers must be paths or dicts containing path")
    _ghidra_pipeline(
        name = name,
        manifest = json.encode({
            "completion_markers": normalized_markers,
            "steps": steps,
        }),
        oracle = True,
        private = private,
        project_name = project_name,
        srcs = srcs,
        scripts = scripts,
        timeout = timeout,
        **kwargs
    )

def _runfiles_key(file, workspace_name):
    path = file.short_path.replace("\\", "/")
    if path.startswith("../"):
        return path[3:]
    return workspace_name + "/" + path

def _ghidra_session_impl(ctx):
    ghidra = ctx.toolchains[GHIDRA_TOOLCHAIN_TYPE]
    extension = ".bat" if ghidra.windows else ".sh"
    executable = ctx.actions.declare_file(ctx.label.name + extension)
    key = _runfiles_key(ghidra.gui, ctx.workspace_name)
    java_key = _runfiles_key(ghidra.java, ctx.workspace_name)
    if ghidra.windows:
        content = """@echo off
setlocal
if not defined RUNFILES_DIR set "RUNFILES_DIR=%~f0.runfiles"
if not defined RUNFILES_MANIFEST_FILE set "RUNFILES_MANIFEST_FILE=%~f0.runfiles_manifest"
set "_ghidra_gui=%RUNFILES_DIR%\\{key_windows}"
set "_ghidra_java=%RUNFILES_DIR%\\{java_key_windows}"
if defined RUNFILES_MANIFEST_FILE for /f "tokens=1,*" %%A in ('findstr /b /c:"{key} " "%RUNFILES_MANIFEST_FILE%"') do set "_ghidra_gui=%%B"
if defined RUNFILES_MANIFEST_FILE for /f "tokens=1,*" %%A in ('findstr /b /c:"{java_key} " "%RUNFILES_MANIFEST_FILE%"') do set "_ghidra_java=%%B"
if not exist "%_ghidra_gui%" echo Unable to locate Ghidra launcher in runfiles.& exit /b 1
if not exist "%_ghidra_java%" echo Unable to locate Ghidra Java in runfiles.& exit /b 1
for %%I in ("%_ghidra_java%") do set "_ghidra_java_bin=%%~dpI"
for %%I in ("%_ghidra_java_bin%..") do set "JAVA_HOME=%%~fI"
call "%_ghidra_gui%" %*
""".format(
            java_key = java_key,
            java_key_windows = java_key.replace("/", "\\"),
            key = key,
            key_windows = key.replace("/", "\\"),
        )
    else:
        content = """#!/usr/bin/env bash
set -euo pipefail
resolve_runfile() {{
  local key="$1"
  if [[ -n "${{RUNFILES_DIR:-}}" && -e "${{RUNFILES_DIR}}/$key" ]]; then
    printf '%s\\n' "${{RUNFILES_DIR}}/$key"
  elif [[ -n "${{RUNFILES_MANIFEST_FILE:-}}" ]]; then
    awk -v key="$key" 'index($0, key " ") == 1 {{ print substr($0, length(key) + 2); exit }}' "${{RUNFILES_MANIFEST_FILE}}"
  fi
}}
launcher="$(resolve_runfile '{key}')"
java="$(resolve_runfile '{java_key}')"
[[ -n "$launcher" && -x "$launcher" ]] || {{ echo 'Unable to locate Ghidra launcher in runfiles.' >&2; exit 1; }}
[[ -n "$java" && -x "$java" ]] || {{ echo 'Unable to locate Ghidra Java in runfiles.' >&2; exit 1; }}
export JAVA_HOME="$(cd "$(dirname "$java")/.." && pwd)"
exec "$launcher" "$@"
""".format(key = key, java_key = java_key)
    ctx.actions.write(executable, content, is_executable = True)
    runfiles = ctx.runfiles(files = [ghidra.gui, ghidra.java]).merge(
        ctx.runfiles(transitive_files = ghidra.files),
    )
    return [DefaultInfo(executable = executable, runfiles = runfiles)]

ghidra_session = rule(
    implementation = _ghidra_session_impl,
    executable = True,
    toolchains = [GHIDRA_TOOLCHAIN_TYPE],
)
