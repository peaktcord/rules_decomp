"""Ghidra and Java runtime toolchain provider."""

GHIDRA_TOOLCHAIN_TYPE = "@rules_decomp//toolchains/ghidra:toolchain_type"

def _ghidra_runtime_impl(ctx):
    return [platform_common.ToolchainInfo(
        analyzer = ctx.file.analyzer,
        files = depset(ctx.files.files),
        gui = ctx.file.gui,
        java = ctx.file.java,
        java_home = ctx.file.java.dirname + "/..",
        windows = ctx.attr.windows,
    )]

ghidra_runtime = rule(
    implementation = _ghidra_runtime_impl,
    attrs = {
        "analyzer": attr.label(allow_single_file = True, mandatory = True),
        "files": attr.label(allow_files = True, mandatory = True),
        "gui": attr.label(allow_single_file = True, mandatory = True),
        "java": attr.label(allow_single_file = True, mandatory = True),
        "windows": attr.bool(mandatory = True),
    },
)
