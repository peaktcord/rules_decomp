"""Public BUILD APIs for rules_decomp."""

load("//decomp:ghidra.bzl", _ghidra_oracle = "ghidra_oracle", _ghidra_pipeline = "ghidra_pipeline", _ghidra_session = "ghidra_session")
load("//decomp:sentinel.bzl", _sentinel_test = "sentinel_test")
load("//decomp:verified_inputs.bzl", _verified_files = "verified_files")

ghidra_oracle = _ghidra_oracle
ghidra_pipeline = _ghidra_pipeline
ghidra_session = _ghidra_session
sentinel_test = _sentinel_test
verified_files = _verified_files
