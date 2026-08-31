"""Pinned SDL3 repositories with a uniform C++ dependency surface."""

_RELEASES = {
    "3.4.14": {
        "source": struct(
            archive = "SDL3-3.4.14.tar.gz",
            sha256 = "30d4aa2b3037718142b32dffd4e72f917ebb6cc5227150e7bb9c45efb2153aeb",
        ),
        "windows_vc": struct(
            archive = "SDL3-devel-3.4.14-VC.zip",
            sha256 = "2fe279e70d426e9c644b625acb3083eb3cfb263a92f2c5718aff18d24a8b6e96",
        ),
    },
}

def _windows_build_file():
    return """
load("@rules_cc//cc:cc_import.bzl", "cc_import")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

cc_import(
    name = "sdl3_binary",
    interface_library = "lib/x64/SDL3.lib",
    shared_library = "lib/x64/SDL3.dll",
)

cc_library(
    name = "sdl3",
    hdrs = glob(["include/SDL3/*.h"]),
    includes = ["include"],
    deps = [":sdl3_binary"],
)

filegroup(
    name = "runtime",
    srcs = ["lib/x64/SDL3.dll"],
)

filegroup(
    name = "license",
    srcs = ["LICENSE.txt"],
)
"""

def _linux_build_file():
    return """
load("@rules_foreign_cc//foreign_cc:defs.bzl", "cmake")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

filegroup(
    name = "sources",
    srcs = glob(["**"], exclude = ["BUILD.bazel"]),
)

cmake(
    name = "sdl3",
    cache_entries = {
        "SDL_DISABLE_INSTALL_DOCS": "ON",
        "SDL_EXAMPLES": "OFF",
        "SDL_INSTALL_TESTS": "OFF",
        "SDL_SHARED": "ON",
        "SDL_STATIC": "OFF",
        "SDL_TESTS": "OFF",
        "SDL_TEST_LIBRARY": "OFF",
    },
    lib_source = ":sources",
    out_include_dir = "include",
    out_shared_libs = ["libSDL3.so"],
)

# The foreign build's installed tree carries the shared object in DefaultInfo.
# Packaging rules may consume this label; ordinary binaries should depend on
# :sdl3 and let Bazel propagate its runtime files.
alias(
    name = "runtime",
    actual = ":sdl3",
)

filegroup(
    name = "license",
    srcs = ["LICENSE.txt"],
)
"""

def _unsupported_build_file(message):
    return """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "unsupported",
    srcs = ["unsupported.txt"],
)

alias(name = "sdl3", actual = ":unsupported")
alias(name = "runtime", actual = ":unsupported")
""", message

def _sdl3_repository_impl(repository_ctx):
    version = repository_ctx.attr.version
    if version not in _RELEASES:
        fail("unsupported SDL3 version %s; supported versions: %s" % (
            version,
            sorted(_RELEASES.keys()),
        ))

    release = _RELEASES[version]
    os_name = repository_ctx.attr.platform
    if not os_name:
        os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()
    strip_prefix = "SDL3-%s" % version

    if arch not in ("amd64", "x86_64", "x64"):
        build, message = _unsupported_build_file(
            "SDL3 %s is currently configured for x86-64 hosts; host architecture is %s.\n" % (
                version,
                repository_ctx.os.arch,
            ),
        )
        repository_ctx.file("unsupported.txt", message)
        repository_ctx.file("BUILD.bazel", build)
        return

    if os_name.startswith("windows"):
        artifact = release["windows_vc"]
        repository_ctx.download_and_extract(
            url = "https://github.com/libsdl-org/SDL/releases/download/release-%s/%s" % (
                version,
                artifact.archive,
            ),
            sha256 = artifact.sha256,
            stripPrefix = strip_prefix,
        )
        repository_ctx.file("BUILD.bazel", _windows_build_file())
        return

    if os_name.startswith("linux"):
        artifact = release["source"]
        repository_ctx.download_and_extract(
            url = "https://github.com/libsdl-org/SDL/releases/download/release-%s/%s" % (
                version,
                artifact.archive,
            ),
            sha256 = artifact.sha256,
            stripPrefix = strip_prefix,
        )
        repository_ctx.file("BUILD.bazel", _linux_build_file())
        return

    build, message = _unsupported_build_file(
        "SDL3 %s is currently configured for Windows and Linux; host is %s.\n" % (
            version,
            repository_ctx.os.name,
        ),
    )
    repository_ctx.file("unsupported.txt", message)
    repository_ctx.file("BUILD.bazel", build)

sdl3_repository = repository_rule(
    implementation = _sdl3_repository_impl,
    attrs = {
        "platform": attr.string(
            values = ["", "linux", "windows"],
            default = "",
        ),
        "version": attr.string(mandatory = True),
    },
    doc = "Downloads a verified SDL3 release with a uniform :sdl3 target.",
)
