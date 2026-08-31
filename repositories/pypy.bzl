"""Checksummed PyPy runtime repositories."""

_RELEASES = {
    "7.3.23": {
        "linux": struct(
            archive = "pypy3.11-v7.3.23-linux64.tar.gz",
            interpreter = "bin/pypy3",
            sha256 = "2bcab031cef7a37fe1930b51f7091e78a191ae63f80eca00a265d3378c3a645b",
            strip_prefix = "pypy3.11-v7.3.23-linux64",
        ),
        "windows": struct(
            archive = "pypy3.11-v7.3.23-win64.zip",
            interpreter = "pypy3.exe",
            sha256 = "948b8ea58dea5b9917210fe4afd242c788fbfaba1c3f1a25e696a404f703389a",
            strip_prefix = "pypy3.11-v7.3.23-win64",
        ),
    },
}

def _pypy_repository_impl(repository_ctx):
    if repository_ctx.attr.version not in _RELEASES:
        fail("unsupported PyPy version %s; supported versions: %s" % (
            repository_ctx.attr.version,
            sorted(_RELEASES.keys()),
        ))

    os_name = repository_ctx.os.name.lower()
    if os_name.startswith("windows"):
        platform = "windows"
        os_constraint = "@platforms//os:windows"
    elif os_name.startswith("linux"):
        platform = "linux"
        os_constraint = "@platforms//os:linux"
    else:
        fail("PyPy is pinned for Windows and Linux x86-64; host is %s" % repository_ctx.os.name)

    if repository_ctx.os.arch.lower() not in ("amd64", "x86_64", "x64"):
        fail("PyPy is pinned for x86-64; host architecture is %s" % repository_ctx.os.arch)

    artifact = _RELEASES[repository_ctx.attr.version][platform]
    repository_ctx.download_and_extract(
        url = "https://downloads.python.org/pypy/" + artifact.archive,
        sha256 = artifact.sha256,
        stripPrefix = artifact.strip_prefix,
    )
    warmup = repository_ctx.execute(
        [repository_ctx.path(artifact.interpreter), "-B", "-c", "pass"],
        environment = {
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONHASHSEED": "0",
        },
        quiet = True,
    )
    if warmup.return_code:
        fail("downloaded PyPy failed its bootstrap probe: %s" % warmup.stderr)

    repository_ctx.file("BUILD.bazel", """
load("@rules_decomp//toolchains/pypy:toolchain.bzl", "pypy_runtime")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "interpreter",
    srcs = ["{interpreter}"],
)

filegroup(
    name = "runtime_files",
    srcs = glob(["**"], exclude = ["BUILD.bazel"]),
)

pypy_runtime(
    name = "runtime",
    interpreter = ":interpreter",
    files = ":runtime_files",
)

toolchain(
    name = "toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "{os_constraint}",
    ],
    toolchain = ":runtime",
    toolchain_type = "@rules_decomp//toolchains/pypy:toolchain_type",
)
""".format(
        interpreter = artifact.interpreter,
        os_constraint = os_constraint,
    ))

pypy_repository = repository_rule(
    implementation = _pypy_repository_impl,
    attrs = {
        "version": attr.string(mandatory = True),
    },
    doc = "Downloads and verifies a supported PyPy runtime for the host.",
)
