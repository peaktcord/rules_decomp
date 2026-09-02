"""Run a project's existing validation script as a cached, gated Bazel action.

Decompilation projects accumulate Python gates (comparator self-tests,
manifest audits, layout ratchets, module matchers). `script_check` runs one of
them under the pinned PyPy runtime with declared inputs and records success as
an `.ok` marker plus the captured log. `check_test` exposes that marker as a
Bazel test so the gate participates in `bazel test` suites. On Windows this
avoids generating test executables, which would need runfiles-aware wrappers.
"""

load("//decomp:sentinel.bzl", "sentinel_test")
load("//decomp:staging.bzl", "staged_file")
load("//decomp:verified_inputs.bzl", "VerifiedFilesInfo")
load("//toolchains/pypy:toolchain.bzl", "PYPY_TOOLCHAIN_TYPE")

_LOCAL_ONLY = {
    "no-remote": "1",
    "no-remote-cache": "1",
    "no-remote-exec": "1",
}

def _script_check_impl(ctx):
    pypy = ctx.toolchains[PYPY_TOOLCHAIN_TYPE]
    marker = ctx.actions.declare_file(ctx.label.name + ".ok")
    log = ctx.actions.declare_file(ctx.label.name + ".log")
    targets = ctx.attr.data + ctx.attr.verified
    direct = [ctx.file._runner, ctx.file.script, marker] + ctx.files.data
    for target in ctx.attr.verified:
        info = target[VerifiedFilesInfo]
        direct.append(info.verification)
        direct.extend(info.files.to_list())

    args = ctx.actions.args()
    args.add("-B")
    args.add(ctx.file._runner.path)
    args.add("--script", ctx.file.script.path)
    args.add("--marker", marker.path)
    args.add("--log", log.path)
    outs = ctx.outputs.outs

    def expand(value):
        # $(OUT_DIR) is the package's output directory, where `outs` are written.
        value = value.replace("$(OUT_DIR)", marker.dirname)
        return ctx.expand_location(value, targets = targets)

    for key, value in ctx.attr.env.items():
        args.add("--env", "%s=%s" % (key, expand(value)))
    if ctx.attr.chdir:
        args.add("--chdir", ctx.attr.chdir)
    args.add("--")
    for value in ctx.attr.args:
        args.add(expand(value))

    ctx.actions.run(
        executable = pypy.interpreter,
        arguments = [args],
        inputs = depset(direct = [f for f in direct if f != marker], transitive = [pypy.files]),
        outputs = [marker, log] + outs,
        mnemonic = "ScriptCheck",
        progress_message = "Checking %s" % ctx.label,
        execution_requirements = _LOCAL_ONLY if ctx.attr.private else {"no-remote-exec": "1"},
        env = {
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONHASHSEED": "0",
        },
    )
    return [
        DefaultInfo(files = depset([marker])),
        OutputGroupInfo(log = depset([log]), outs = depset(outs)),
    ]

script_check = rule(
    implementation = _script_check_impl,
    doc = "Run a project Python script; succeed only when it exits zero.",
    attrs = {
        "script": attr.label(allow_single_file = [".py"], mandatory = True),
        "args": attr.string_list(doc = "Script arguments; $(location LABEL) is expanded against data."),
        "data": attr.label_list(allow_files = True, doc = "Files the script reads or imports."),
        "env": attr.string_dict(doc = "Environment variables; values may use $(location LABEL)."),
        "verified": attr.label_list(
            providers = [VerifiedFilesInfo],
            doc = "verified_files targets whose files and verification markers are inputs.",
        ),
        "chdir": attr.string(doc = "Execroot-relative working directory for the script."),
        "outs": attr.output_list(doc = "Extra files the script writes below $(OUT_DIR)."),
        "private": attr.bool(default = True, doc = "Keep the action local and out of remote caches."),
        "_runner": attr.label(
            default = Label("//decomp:run_check.py"),
            allow_single_file = [".py"],
        ),
    },
    toolchains = [PYPY_TOOLCHAIN_TYPE],
)

def check_test(name, check, tags = [], **kwargs):
    """Expose a script_check marker as a Bazel test.

    The expected marker is staged into the consumer's package because Windows
    test runfiles cannot reach files of another repository.
    """
    staged_file(
        name = name + "_expected",
        out = name + ".expected.ok",
        src = Label("//testing:ok.txt"),
        tags = tags,
        visibility = ["//visibility:private"],
    )
    sentinel_test(
        name = name,
        actual = check,
        expected = ":" + name + "_expected",
        tags = tags,
        **kwargs
    )
