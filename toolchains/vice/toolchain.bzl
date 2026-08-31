"""VICE toolchain provider."""

VICE_TOOLCHAIN_TYPE = "@rules_decomp//toolchains/vice:toolchain_type"

def _vice_runtime_impl(ctx):
    return [platform_common.ToolchainInfo(
        emulator = ctx.file.emulator,
        files = depset(ctx.files.files),
    )]

vice_runtime = rule(
    implementation = _vice_runtime_impl,
    attrs = {
        "emulator": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "files": attr.label(allow_files = True, mandatory = True),
    },
)
