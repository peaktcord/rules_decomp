# rules_decomp

Experimental shared Bazel rules and toolchains for the decompilation and
native-port projects under `C:\git-recompile`.

The module owns reusable mechanisms: checksummed tool downloads, PyPy and VICE
toolchains, verified private inputs, patched source archives, and exact sentinel
comparisons. Each consuming project continues to own its source manifests,
patches, emulator scripts, reference data, compiler flags, and test suites.

## Local use

Add the dependency to a project's `MODULE.bazel` while this module is developed
as a neighboring checkout:

```starlark
bazel_dep(name = "rules_decomp", version = "0.1.0")

local_path_override(
    module_name = "rules_decomp",
    path = "../rules_decomp",
)

decomp = use_extension(
    "@rules_decomp//:extensions.bzl",
    "decomp",
)
decomp.pypy(version = "7.3.23")
decomp.vice(version = "3.10")

use_repo(decomp, "decomp_pypy", "decomp_vice")

register_toolchains(
    "@decomp_pypy//:toolchain",
    "@decomp_vice//:toolchain",
)
```

Adjust the relative override path for repositories outside
`C:\git-recompile`. Do not commit an absolute machine path.

Load reusable BUILD APIs from `@rules_decomp//decomp:defs.bzl`.

## Development checks

```powershell
bazelisk test //... --config=windows
bazelisk mod deps
```

The canonical Codex skill is in `skills/decompilation-bazel`. Use
`tools/sync-skill.ps1` to copy it into a consuming project's
`.agents/skills/decompilation-bazel` directory.

This initial version deliberately does not claim stable APIs. Exercise a rule in
at least two projects before treating its interface as stable.
