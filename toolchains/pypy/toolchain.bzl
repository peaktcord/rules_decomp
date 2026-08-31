"""PyPy toolchain provider."""

PYPY_TOOLCHAIN_TYPE = "@rules_decomp//toolchains/pypy:toolchain_type"

def _pypy_runtime_impl(ctx):
    return [platform_common.ToolchainInfo(
        files = depset(ctx.files.files),
        interpreter = ctx.file.interpreter,
    )]

pypy_runtime = rule(
    implementation = _pypy_runtime_impl,
    attrs = {
        "files": attr.label(allow_files = True, mandatory = True),
        "interpreter": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
    },
)
