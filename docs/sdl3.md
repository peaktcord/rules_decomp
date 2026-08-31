# SDL3 for portable C++ ports

`rules_decomp` provides one SDL3 dependency label on Windows and Linux:

```starlark
@decomp_sdl3//:sdl3
```

The current pin is SDL 3.4.14. Windows uses SDL's official Visual C++ x64
development archive; Linux builds the same release source through SDL's upstream
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

## Platform and compiler policy

- Supported initially: Windows x86-64 with MSVC or `clang-cl`, and Linux x86-64.
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
