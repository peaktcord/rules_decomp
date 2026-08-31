"""Checksummed VICE runtime repositories."""

_RELEASES = {
    "3.10": struct(
        archive = "SDL2VICE-3.10-win64.zip",
        sha256 = "dfa7e0223ea1357bae988b5c88b332c3b8f80dc3c7a2b51233f50bab5263dca5",
        strip_prefix = "SDL2VICE-3.10-win64",
        url = "https://github.com/VICE-Team/svn-mirror/releases/download/3.10.0/SDL2VICE-3.10-win64.zip",
    ),
}

def _write_build(repository_ctx, emulator, runtime_sources):
    repository_ctx.file("BUILD.bazel", """
load("@rules_decomp//toolchains/vice:toolchain.bzl", "vice_runtime")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "emulator",
    srcs = ["{emulator}"],
)

filegroup(
    name = "runtime_files",
    srcs = {runtime_sources},
)

vice_runtime(
    name = "runtime",
    emulator = ":emulator",
    files = ":runtime_files",
)

toolchain(
    name = "toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    toolchain = ":runtime",
    toolchain_type = "@rules_decomp//toolchains/vice:toolchain_type",
)
""".format(
        emulator = emulator,
        runtime_sources = runtime_sources,
    ))

def _vice_repository_impl(repository_ctx):
    if repository_ctx.attr.version not in _RELEASES:
        fail("unsupported VICE version %s; supported versions: %s" % (
            repository_ctx.attr.version,
            sorted(_RELEASES.keys()),
        ))

    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()
    if not os_name.startswith("windows") or arch not in ("amd64", "x86_64", "x64"):
        repository_ctx.file(
            "unsupported.txt",
            "VICE %s is currently pinned for Windows x86-64; host is %s %s.\n" % (
                repository_ctx.attr.version,
                repository_ctx.os.name,
                repository_ctx.os.arch,
            ),
        )
        _write_build(repository_ctx, "unsupported.txt", '["unsupported.txt"]')
        return

    artifact = _RELEASES[repository_ctx.attr.version]
    repository_ctx.download_and_extract(
        url = artifact.url,
        sha256 = artifact.sha256,
        stripPrefix = artifact.strip_prefix,
    )
    _write_build(
        repository_ctx,
        "x64sc.exe",
        'glob(["**"], exclude = ["BUILD.bazel"])',
    )

vice_repository = repository_rule(
    implementation = _vice_repository_impl,
    attrs = {
        "version": attr.string(mandatory = True),
    },
    doc = "Downloads and verifies a supported VICE runtime.",
)
