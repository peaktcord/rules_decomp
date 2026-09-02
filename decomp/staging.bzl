"""Stage an external-repository file as a main-repository output.

Windows test runfiles cannot reach external-repository files through their
`../repo/...` rootpaths, so a `sentinel_test` whose expected file lives in a
local tool repository must compare against a staged copy instead.
"""

load("//toolchains/pypy:toolchain.bzl", "PYPY_TOOLCHAIN_TYPE")

def _staged_file_impl(ctx):
    pypy = ctx.toolchains[PYPY_TOOLCHAIN_TYPE]
    output = ctx.actions.declare_file(ctx.attr.out or ctx.label.name)
    args = ctx.actions.args()
    args.add("-B")
    args.add(ctx.file._stager.path)
    args.add("--input", ctx.file.src.path)
    args.add("--output", output.path)
    ctx.actions.run(
        executable = pypy.interpreter,
        arguments = [args],
        inputs = depset(direct = [ctx.file._stager, ctx.file.src], transitive = [pypy.files]),
        outputs = [output],
        mnemonic = "StageFile",
        progress_message = "Staging %s" % ctx.label,
        env = {
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONHASHSEED": "0",
        },
    )
    return [DefaultInfo(files = depset([output]))]

staged_file = rule(
    implementation = _staged_file_impl,
    doc = "Copy one file (typically from a local tool repository) into this repository's outputs.",
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.string(doc = "Output file name; defaults to the target name."),
        "_stager": attr.label(
            default = Label("//decomp:stage_file.py"),
            allow_single_file = [".py"],
        ),
    },
    toolchains = [PYPY_TOOLCHAIN_TYPE],
)
