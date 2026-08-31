# Ghidra workflow classification

Inspect the existing launcher and every pre/post script before creating targets.
Classify the operation as one of these:

- Static pipeline: imports, analysis, database mutation, report export, or
  decompilation whose complete inputs and outputs are known. Use
  `ghidra_pipeline` and keep every pass that shares a database in one action.
- Execution oracle: a script uses `EmulatorHelper` or otherwise executes target
  instructions under controlled state. Use `ghidra_oracle`, disable analysis,
  impose a timeout, and check a completion marker before comparing sentinels.
- Interactive session: a person explores or mutates a long-lived ignored
  project. Use `ghidra_session`; do not represent the project as a cached output.

Pin the exact Ghidra version and a compatible JDK through the shared toolchain.
Declare private images through `verified_files` and reference them as
`$VERIFIED(basename)` in pipeline steps. Keep project-specific processors,
addresses, loader arguments, scripts, symbols, and expected reports in the game
repository.

Prefer reports and oracle corpora as the stable action boundary. Ghidra database
files are version-sensitive and may include incidental state. If several
headless invocations need the database, execute them in order inside one action
instead of passing the project between independently cached actions.

For exact syntax and examples, consult the shared module's `docs/ghidra.md`.
