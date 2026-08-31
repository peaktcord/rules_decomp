# rules_decomp module usage

Use this reference when adding shared repositories, toolchains, verified inputs,
sentinel comparisons, or patched third-party source.

## Local module dependency

During development beside `C:\git-recompile\rules_decomp`:

```starlark
bazel_dep(name = "rules_decomp", version = "0.1.0")

local_path_override(
    module_name = "rules_decomp",
    path = "../rules_decomp",
)
```

The path is relative to the consuming module and may be `../../rules_decomp` for
a nested checkout. Replace the override with a released module source when one
exists.

## Runtime toolchains

Request only tools the project uses:

```starlark
decomp = use_extension("@rules_decomp//:extensions.bzl", "decomp")
decomp.pypy(version = "7.3.23")
decomp.vice(version = "3.10")
decomp.ghidra(version = "12.1.3", java_version = "21")

use_repo(decomp, "decomp_ghidra", "decomp_pypy", "decomp_vice")

register_toolchains(
    "@decomp_pypy//:toolchain",
    "@decomp_vice//:toolchain",
    "@decomp_ghidra//:toolchain",
)
```

Request Ghidra only in repositories that use it. Configure the installation with
`--repo_env=GHIDRA_ROOT=...` and its compatible JDK with
`--repo_env=GHIDRA_JAVA_HOME=...`; do not commit either absolute path.

Module extensions create repositories but cannot register toolchains. Keep
`register_toolchains` in the consumer's `MODULE.bazel`.

## Verified private files

The manifest accepts either `SHA256 NAME` or `SHA256 SIZE NAME` per line. Input
basenames must be unique.

```starlark
load("@rules_decomp//decomp:defs.bzl", "verified_files")

verified_files(
    name = "verified_roms",
    srcs = glob(["roms/*.d64"]),
    manifest = "docs/roms.sha256",
    tags = ["requires-private-data"],
)
```

The rule intentionally accepts an empty `srcs` list so a clean checkout reaches
the verifier and receives a missing-input diagnostic.

## Exact sentinel comparison

```starlark
load("@rules_decomp//decomp:defs.bzl", "sentinel_test")

sentinel_test(
    name = "test_generated_digest",
    actual = ":generated_digest",
    expected = "ref/digest.txt",
)
```

For a file inside a declared tree artifact, add `actual_path = "digest.txt"`.

## Patched source archives

Keep patches and the BUILD overlay in the consuming project:

```starlark
decomp.source_archive(
    name = "altirra",
    urls = ["https://upstream.example/altirra-COMMIT.zip"],
    sha256 = "...",
    strip_prefix = "altirra-COMMIT",
    patches = [
        "//third_party/altirra/patches:0001-add-automation.patch",
    ],
    patch_strip = 1,
    build_file = "//third_party/altirra:altirra.BUILD.bazel",
)

use_repo(decomp, "altirra")
```

Record the upstream revision, archive hash, patch purpose, rebase instructions,
and verification command next to the patch. A project-specific behavioral patch
does not belong in `rules_decomp`.
