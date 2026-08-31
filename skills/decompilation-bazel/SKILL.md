---
name: decompilation-bazel
description: Configure, migrate, or review Bazel builds for decompilation and native-port projects that combine reconstructed source, private binary inputs, emulators, pinned public tools, legacy compilers, and sentinel validation. Use for these projects' Bazel architecture and workflows; do not use for an ordinary application that only needs generic Bazel help.
---

# Decompilation Bazel

Build a reproducible layer around the existing reconstruction workflow without
changing what counts as correct. Prefer a small working vertical slice over a
repository-wide rewrite.

## Start from evidence

Before editing, inspect the repository's `MODULE.bazel`, `.bazelrc`, build and
validation scripts, tool-discovery code, private-input layout, emulator setup,
sentinel data, documentation, and worktree status. Identify which artifacts are
source inputs, generated intermediates, sealed references, or disposable
outputs. Preserve unrelated and user-authored changes.

Do not treat a compiler migration, source cleanup, emulator change, or reference
refresh as an implicit part of adopting Bazel. Those require their own evidence
and authorization.

## Keep the boundary clear

Use `rules_decomp` for reusable mechanisms and keep project semantics in the
consumer:

- Shared: pinned runtime repositories, toolchain providers, private-action
  policy, verified-file gates, exact comparisons, and patch application.
- Project-owned: ROM names and hashes, source patches, capture protocols,
  expected outputs, compile flags, environment adapters, and suite composition.

If `rules_decomp` does not yet express a requirement cleanly, keep a thin local
rule. Generalize it only after another project demonstrates the same interface.
Never copy an entire project-specific rule into the shared module merely to make
it appear reusable.

For module declarations, toolchain registration, and patched-source examples,
read [references/module-usage.md](references/module-usage.md). For a migration or
new configuration, also read
[references/migration-checklist.md](references/migration-checklist.md).

## Preserve these invariants

- Pin Bazel with `.bazelversion` and invoke it through Bazelisk.
- Use Bzlmod. During local `rules_decomp` development, use a relative
  `local_path_override`; do not commit an absolute workstation path.
- Download redistributable tools only from identified upstream releases with a
  committed SHA-256. Make the complete runtime tree an action input when the
  executable depends on adjacent DLLs, ROMs, palettes, or data.
- Represent closed or non-redistributable tools as explicit local toolchains.
  Discover their roots through documented `--repo_env` settings, and keep their
  actions local and out of remote caches.
- Keep copyrighted or user-supplied disks gitignored but declared as Bazel
  inputs. Verify their exact set, sizes where known, and hashes before derived
  actions consume them. Mark those actions `no-remote`, `no-remote-cache`, and
  `no-remote-exec`.
- Separate sealed validation from manual emulator-backed refreshes. Refresh into
  `bazel-bin` for review; never overwrite a reference corpus automatically.
- Give unsupported platforms constrained or inert tool repositories when
  possible so an unavailable emulator does not block unrelated portable targets.
- Isolate emulator configuration and allocate dynamic control ports when parallel
  actions could collide.
- Make generated outputs declared artifacts. Avoid writing into the source tree
  during builds and tests.
- Put deterministic Ghidra imports, analysis scripts, reports, decompilation,
  and `EmulatorHelper` oracles behind the shared isolated rules. Keep a complete
  ordered workflow in one disposable project action. Keep interactive mutation
  of a personal Ghidra database in a local `ghidra_session` target.

For a Ghidra workflow, read [references/ghidra.md](references/ghidra.md) before
choosing the target boundary.

## Deliver a migration increment

Establish one useful path end to end: declared inputs, pinned tools, generated
output, sentinel comparison, and a documented command. Run the smallest relevant
tests plus a query or build that proves toolchain resolution. Report cached and
executed results accurately, and call out any reproducibility drift instead of
promoting it.

Update the project's Bazel guide with tool versions, hashes, private-data
requirements, target tiers, output locations, known platform gaps, and the exact
commands that were verified.
