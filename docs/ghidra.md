# Ghidra rules

`rules_decomp` treats deterministic headless Ghidra work as a build graph and
keeps interactive analysis as an explicit local session. The shared rules own
runtime selection, Java selection, disposable project isolation, script staging,
logging, timeouts, and private-action policy. Processor knowledge and Ghidra
scripts remain in the consuming repository.

## Configure the local toolchain

Ghidra is currently exposed from a local installation. This avoids downloading
several gigabytes separately in every neighboring checkout and permits an exact
version check without committing a workstation path.

```starlark
decomp = use_extension("@rules_decomp//:extensions.bzl", "decomp")
decomp.ghidra(version = "12.1.3", java_version = "21")
decomp.pypy(version = "7.3.23")

use_repo(decomp, "decomp_ghidra", "decomp_pypy")

register_toolchains(
    "@decomp_ghidra//:toolchain",
    "@decomp_pypy//:toolchain",
)
```

Set the roots without placing absolute paths in `MODULE.bazel`:

```powershell
bazelisk build //analysis:reports `
  --repo_env=GHIDRA_ROOT=S:\Apps\ghidra_12.1.3_PUBLIC `
  --repo_env=GHIDRA_JAVA_HOME=C:\path\to\jdk-21
```

The repository rule validates `Ghidra/application.properties`, required
launchers, the requested Java major version, `javac`, and the `java.desktop`
module. A reduced Bazel/server runtime is not a substitute for a full Ghidra
JDK. The Ghidra and JDK trees are complete toolchain inputs.

## Headless pipeline

Use `ghidra_pipeline` when imports and processing passes must share one project.
The project and Ghidra user directories are created below the declared output
tree and deleted after the steps finish. Only reports remain as the cached tree
artifact. On failure the disposable Ghidra log is emitted to Bazel's stderr.

```starlark
load("@rules_decomp//decomp:defs.bzl", "ghidra_pipeline")

ghidra_pipeline(
    name = "recon",
    srcs = [":verified_images", "imports.tsv"],
    scripts = [
        "PrepareImage.java",
        "ApplyImports.java",
        "ExportReports.java",
    ],
    project_name = "Recon",
    steps = [
        {
            "action": "import",
            "input": "$VERIFIED(PROGRAM.BIN)",
            "processor": "6502:LE:16:default",
            "loader": "BinaryLoader",
            "overwrite": True,
            "pre_scripts": [{
                "name": "PrepareImage.java",
                "args": ["$OUTPUT_DIR/program"],
            }],
            "post_scripts": [{
                "name": "ApplyImports.java",
                "args": ["$(location imports.tsv)"],
            }],
        },
        {
            "action": "process",
            "program": "PROGRAM.BIN",
            "noanalysis": True,
            "post_scripts": [{
                "name": "ExportReports.java",
                "args": ["$OUTPUT_DIR/program"],
            }],
        },
    ],
)
```

Step fields are:

- `action`: required `import` or `process`.
- `input`: required for imports. Use `$(location LABEL)` for an ordinary source
  or `$VERIFIED(basename)` for a file carried by `verified_files`.
- `program`: required for processing an imported project program.
- `processor`, `cspec`, and `loader`: corresponding Ghidra import options.
- `overwrite`, `noanalysis`, `read_only`: boolean headless options.
- `analysis_timeout`: Ghidra's per-file analysis timeout in seconds.
- `extra_args`: loader or other headless options, placed before scripts.
- `pre_scripts` and `post_scripts`: ordered `{name, args}` dictionaries.
- `script_paths`: additional advanced script search directories. Scripts listed
  in the rule's `scripts` attribute are staged automatically.

All script arguments may contain `$OUTPUT_DIR` or `$PROJECT_DIR`. Only
`$OUTPUT_DIR` survives the action. Do not write reports into the source tree.

`private = True` is the default. It prevents remote execution and remote-cache
upload. Set it false only when every binary and report is redistributable; the
local toolchain still forces local execution.

## Emulation oracle

`ghidra_oracle` is deliberately distinct from static analysis. Every step must
set `noanalysis = True`, a wall-clock timeout defaults to ten minutes, and at
least one completion check is required.

```starlark
load("@rules_decomp//decomp:defs.bzl", "ghidra_oracle", "sentinel_test")

ghidra_oracle(
    name = "conditions_oracle",
    srcs = [":verified_snapshot"],
    scripts = ["TraceConditions.java"],
    completion_markers = [{
        "path": "conditions.txt",
        "contains": "complete=true",
    }],
    steps = [{
        "action": "import",
        "input": "$VERIFIED(city-memory.bin)",
        "processor": "6502:LE:16:default",
        "loader": "BinaryLoader",
        "noanalysis": True,
        "post_scripts": [{
            "name": "TraceConditions.java",
            "args": ["$OUTPUT_DIR/conditions.txt"],
        }],
    }],
)

sentinel_test(
    name = "conditions_test",
    actual = ":conditions_oracle",
    actual_path = "conditions.txt",
    expected = "reference/conditions.txt",
)
```

A completion marker may be a path string, which checks existence, or a
`{path, contains}` dictionary, which also checks text content. Directory-shaped
corpora use a marker such as `trace.complete` and can expose individual files to
`sentinel_test` with `actual_path`.

## Interactive sessions

```starlark
load("@rules_decomp//decomp:defs.bzl", "ghidra_session")

ghidra_session(name = "gui")
```

`bazel run //analysis:gui -- <project.gpr>` launches the configured Ghidra GUI.
The project remains a local, ignored working database. It must never share a
path with a headless action, and GUI sessions are not cached build steps.

## Repository mappings

- Hallways: one pipeline imports `TUNNELS.EXE`, applies symbols, boundaries,
  prototypes and context in their required order, then exports reports. Python
  evidence generation is an upstream target; avoid a cyclic Ghidra/Python graph.
- Lightlock: one pipeline imports both E32 programs with per-image loader
  arguments, prepares them, exports reports, and performs selected-function
  decompilation before discarding the shared project.
- SameOld static analysis: one pipeline target per 64 KiB snapshot/profile so
  overlays at the same addresses remain distinct. Coverage annotations are
  declared script data.
- SameOld emulation: `ghidra_oracle` runs `EmulatorHelper` scripts with analysis
  disabled, bounded time, declared output trees, and checked completion markers.
