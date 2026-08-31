# Migration checklist

Use this reference for a new Bazel configuration or a material migration.

## Inventory

- Record source languages, current compilers, exact compiler versions, and build
  entry points.
- Classify each tool as downloadable and redistributable, locally installed and
  non-redistributable, built from source, or interactive-only.
- Locate private disks, executables, symbols, captures, extracted assets, and
  reference outputs. Check their ignore rules before running generators.
- Trace validation from original input through generated oracle to comparison.
- Identify Windows-only assumptions and distinguish host tools from target
  binaries.

## Initial target tiers

Prefer explicit suites rather than making `//...` unexpectedly require private
data or start an emulator:

- `test_fast`: sealed, deterministic, no private inputs or emulator.
- Generated-oracle tests: private verified inputs, deterministic generation.
- Refresh tests: manual, local emulator/compiler execution followed by exact
  comparison.
- Diagnostic or interactive tools: manual targets with declared outputs where
  possible.

Names may follow the existing project, but preserve the separation.

## Tool decisions

- Keep MSVC when binary compatibility or an old runtime is part of the evidence;
  adding Bazel does not imply switching to LLVM.
- Add clang-cl or LLVM as a second configuration when cross-compiler validation
  is useful. Do not replace the reference compiler until outputs and behavior are
  understood.
- For an SDL3 port, keep reconstruction/gameplay logic in an SDL-free
  `cc_library`, place SDL integration in a platform library, and use the shared
  `@decomp_sdl3//:sdl3` target. Verify the final shared-library runfiles and
  distributable package on each supported OS.
- Prefer a checked-in patch against a pinned upstream source archive for emulator
  automation. Do not mutate a shared checkout in place.
- A Docker or emulator invocation may be a Bazel action when all inputs and
  outputs are declared, but keep machine services, GUI interaction, and mutable
  profiles outside ordinary test suites.
- Distinguish Ghidra static analysis from `EmulatorHelper` execution. Keep
  ordered passes over one disposable project in one `ghidra_pipeline`; use
  `ghidra_oracle` for bounded execution with completion checks. Do not let a GUI
  and a headless action operate on the same project directory.

## Verification

- Run `bazelisk mod deps` or `bazelisk mod tidy` after module changes.
- Use `--toolchain_resolution_debug` when selection is ambiguous.
- Run the new narrow target once uncached when practical, then confirm the
  expected cache behavior.
- Compare newly generated reference material byte-for-byte. Investigate drift;
  do not normalize it away or promote it automatically.
- Run the pre-existing validation path when feasible to show Bazel has not
  silently changed semantics.
- Update the project guide with commands actually run and platform limitations
  not yet tested.
