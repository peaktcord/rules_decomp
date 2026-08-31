"""Verification gate for private, user-supplied binary inputs."""

load("//toolchains/pypy:toolchain.bzl", "PYPY_TOOLCHAIN_TYPE")

VerifiedFilesInfo = provider(
    doc = "Files whose sizes and SHA-256 hashes matched a checked-in manifest.",
    fields = {
        "files": "depset of verified files",
        "verification": "marker File produced by the verification action",
    },
)

def _verified_files_impl(ctx):
    runtime = ctx.toolchains[PYPY_TOOLCHAIN_TYPE]
    marker = ctx.actions.declare_file(ctx.label.name + ".verified")
    args = ctx.actions.args()
    args.add("-B")
    args.add(ctx.file._verifier.path)
    args.add("--manifest", ctx.file.manifest.path)
    args.add("--output", marker.path)
    for source in ctx.files.srcs:
        args.add("--file", source.basename + "=" + source.path)
    ctx.actions.run(
        executable = runtime.interpreter,
        arguments = [args],
        inputs = depset(
            direct = [ctx.file._verifier, ctx.file.manifest] + ctx.files.srcs,
            transitive = [runtime.files],
        ),
        outputs = [marker],
        mnemonic = "VerifyPrivateInputs",
        progress_message = "Verifying private inputs for %s" % ctx.label,
        execution_requirements = {
            "no-remote": "1",
            "no-remote-cache": "1",
            "no-remote-exec": "1",
        },
        env = {
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONHASHSEED": "0",
        },
    )
    files = depset(ctx.files.srcs)
    return [
        DefaultInfo(files = depset([marker])),
        VerifiedFilesInfo(files = files, verification = marker),
    ]

verified_files = rule(
    implementation = _verified_files_impl,
    attrs = {
        "manifest": attr.label(allow_single_file = True, mandatory = True),
        "srcs": attr.label_list(allow_files = True),
        "_verifier": attr.label(
            default = Label("//decomp:verify_files.py"),
            allow_single_file = [".py"],
        ),
    },
    toolchains = [PYPY_TOOLCHAIN_TYPE],
)
