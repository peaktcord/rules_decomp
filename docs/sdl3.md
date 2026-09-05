# SDL3 for portable C++ ports

`rules_decomp` provides one SDL3 dependency label on Windows and Linux:

```starlark
@decomp_sdl3//:sdl3
```

The current pin is SDL 3.4.14. Windows uses SDL's official Visual C++
development archive, which contains both x86 and x64 libraries; Linux builds
the same release source through SDL's upstream
CMake project. Both paths use the shared library and retain SDL's native
platform configuration.

## Module configuration

```starlark
bazel_dep(name = "rules_decomp", version = "0.1.0")

decomp = use_extension("@rules_decomp//:extensions.bzl", "decomp")
decomp.sdl3(version = "3.4.14")
use_repo(decomp, "decomp_sdl3")
```

`rules_decomp` itself depends on `rules_foreign_cc`; consumers do not need a
second declaration merely to use the generated SDL repository.

## BUILD targets

Keep the portable game model independent from SDL and make the platform adapter
the SDL consumer:

```starlark
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_library(
    name = "game_core",
    srcs = glob(["core/*.cpp"]),
    hdrs = glob(["include/game/*.h"]),
    includes = ["include"],
)

cc_library(
    name = "sdl_platform",
    srcs = ["platform/sdl_platform.cpp"],
    deps = [
        ":game_core",
        "@decomp_sdl3//:sdl3",
    ],
)

cc_binary(
    name = "game",
    srcs = ["main.cpp"],
    deps = [":sdl_platform"],
)
```

Run and test through Bazel so shared-library runfiles are available:

```powershell
bazelisk run //port:game --config=windows
bazelisk test //port/... --config=windows
```

The Windows `cc_import` propagates `SDL3.dll`; the Linux foreign-CMake target
propagates `libSDL3.so`. `@decomp_sdl3//:runtime` is available to an explicit
packaging rule. A distributable directory must contain the game executable, the
SDL shared library, the SDL license, and project assets; do not rely on copying
files from `bazel-bin` by hand.

## Windows target architecture

The Windows repository selects `lib/x86/SDL3.lib` and `SDL3.dll` for
`@platforms//cpu:x86_32`, or `lib/x64` for `@platforms//cpu:x86_64`.
Both selections also require `@platforms//os:windows`. The same target-platform
selection applies to `:sdl3` and `:runtime`, so packaging receives the matching
DLL. An unsupported target produces a configuration error instead of silently
falling back to x64. Host architecture does not select the Windows library.

Shared platform labels are `@rules_decomp//platforms:windows_x86` and
`@rules_decomp//platforms:windows_x86_64`. In the `rules_decomp` checkout:

```powershell
bazelisk test //tests:sdl3_smoke --config=windows
bazelisk test //tests:sdl3_smoke --config=windows_x86
```

Both configurations compile, link, and load SDL3 at runtime. The smoke test
also asserts that the compiler's pointer width matches the selected target.

For a consumer using the local MSVC toolchain on an x64 Windows host, expose
`rules_cc`'s existing cross-toolchain in `MODULE.bazel`:

```starlark
cc_configure = use_extension("@rules_cc//cc:extensions.bzl", "cc_configure_extension")
use_repo(cc_configure, "local_config_cc")
```

Then add an opt-in consumer `.bazelrc` configuration:

```text
build:windows_x86 --platforms=@rules_decomp//platforms:windows_x86
build:windows_x86 --extra_toolchains=@local_config_cc//:cc-toolchain-x64_x86_windows
```

`rules_cc` 0.2.22 creates that x86 toolchain but does not include it in its
default registered set. Consumers with their own registered x86 compiler need
only select the target platform. Repository configuration files are not
inherited by consuming projects.

## Platform and compiler policy

- Supported targets: Windows x86 and x86-64 with a matching MSVC-compatible
  toolchain, and Linux x86-64. The smoke tests were executed with MSVC for both
  Windows architectures.
- Use shared SDL. It keeps the Windows dependency small and preserves SDL's
  dynamic Linux backend behavior.
- Pin one SDL version across all projects. Upgrade centrally and run every
  project's platform smoke tests before changing the default.
- Do not put SDL includes in the portable core. Core tests should run without a
  display, audio device, or SDL initialization.
- Add SDL_image, SDL_ttf, or SDL_mixer as separate pinned dependencies only when
  a project needs them.

## Release checksums

| Artifact | SHA-256 |
| --- | --- |
| `SDL3-devel-3.4.14-VC.zip` | `2fe279e70d426e9c644b625acb3083eb3cfb263a92f2c5718aff18d24a8b6e96` |
| `SDL3-3.4.14.tar.gz` | `30d4aa2b3037718142b32dffd4e72f917ebb6cc5227150e7bb9c45efb2153aeb` |

The Windows archive checksum was verified against the downloaded official
release asset. Repository downloads use both the exact release URL and SHA-256.
