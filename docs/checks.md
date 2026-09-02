# Checks, staging, local tools, and image splicing

These rules wrap the validation scripts a reconstruction project already owns.
They do not change what a project counts as correct; they give each gate
declared inputs, a cached result, and a place in `bazel test`.

## script_check and check_test

```starlark
load("@rules_decomp//decomp:defs.bzl", "check_test", "script_check")

script_check(
    name = "comparator_selftest",
    script = "//tools:selftest.py",
    args = ["--app", "$(location //:verified_images)"],
    data = ["//tools:coff.py", "//tools:common.py", "//:data/functions.tsv"],
    env = {"PROJECT_COMPILER": "$(location @project_tool//:compiler)"},
    verified = ["//:verified_images", "//:verified_tools"],
    tags = ["manual", "requires-private-data"],
)

check_test(name = "comparator_selftest_test", check = ":comparator_selftest")
```

The script runs under the pinned PyPy interpreter with the execroot as its
working directory (`chdir` overrides that). Success writes `<name>.ok`; the
captured output is in the `log` output group and is printed on failure. Scripts
that locate inputs relative to their own file keep working when their support
modules are listed in `data`. Scripts that write scratch files need an
environment override so they do not write into the execroot; the `EXECROOT`
variable is provided for scripts that want to resolve relative paths.

Scripts that produce files declare them in `outs` and write them below
`$(OUT_DIR)`, which expands to the package's output directory; the files are
then available through the `outs` output group or by their own labels, so a
rebuilt image can feed a `sentinel_test`. Values from `$(location)` that contain
spaces arrive at the script unquoted.

`private = True` (the default) keeps the action local and out of remote caches,
which is right whenever a closed tool or private image is an input.

## staged_file

```starlark
staged_file(
    name = "reference_object",
    src = "@project_tool//:calibration/reference.o",
    out = "reference.o",
)
```

Use it when a `sentinel_test` needs a file from an external repository. On
Windows the test's runfiles are a manifest, and a `../repo/...` rootpath does
not resolve; the staged copy is an ordinary output.

## local_tool_repository

```starlark
local_tool_repository = use_repo_rule(
    "@rules_decomp//repositories:local_tool.bzl",
    "local_tool_repository",
)

local_tool_repository(
    name = "project_ngage",
    env_var = "NGAGE_TOOLCHAIN_ROOT",
    default_path = "extern/ngage-toolchain",
    links = {
        "gcc": "sdk/sdk/6.1/Shared/EPOC32/gcc",
        "calibration/entry.cpp": "sdk/ngagesdk_entry.cpp",
    },
    required = ["sdk/sdk/6.1/Shared/EPOC32/gcc/bin/g++.exe"],
    runtime_globs = ["gcc/**"],
    aliases = {"g++": "gcc/bin/g++.exe"},
    exports = ["calibration/entry.cpp"],
    hint = "Run tools/bootstrap-ngage-sdk.ps1 first.",
)
```

The root comes from `--repo_env=<env_var>=...` or, when unset, from
`default_path` below the workspace (normally an ignored checkout). The rule
only symlinks and declares a `:runtime` filegroup covering the tool tree, so
executables see their adjacent DLLs, specs, and libraries as action inputs.
Hash-verify the executables with `verified_files` in the project and feed that
target's marker to every action that runs them.

## image_splice

```starlark
image_splice(
    name = "rebuilt_image",
    original = "//:verified_images",
    original_basename = "GAME.EXE",
    placements = ":placements",   # TSV: offset, length, piece
    pieces = [":regenerated_ranges"],
    base_offset = 0x7c,
    out = "GAME.rebuilt.EXE",
)

sentinel_test(
    name = "image_test",
    actual = ":rebuilt_image",
    expected = ":staged_original",
)
```

Each placement names a piece by basename, gives its offset relative to
`base_offset`, and its length. The rule copies the original, writes every piece
in place, and produces the rebuilt image plus `<name>.provenance.tsv`
(`start`, `end`, `kind`, `piece`, where kind is `regenerated`, `differs`, or
`copied`) and `<name>.report.txt` with byte totals and hashes. By default the
action fails when any regenerated range differs from the original. A splice is
not a relink: it proves the regenerated ranges and reports the copied ones. Do
not describe a spliced image as a rebuilt executable.
