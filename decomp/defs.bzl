"""Public build APIs for rules_decomp consumers."""

load("//decomp:checks.bzl", _check_test = "check_test", _script_check = "script_check")
load("//decomp:ghidra.bzl", _ghidra_oracle = "ghidra_oracle", _ghidra_pipeline = "ghidra_pipeline", _ghidra_session = "ghidra_session")
load("//decomp:image_splice.bzl", _image_splice = "image_splice")
load("//decomp:sentinel.bzl", _sentinel_test = "sentinel_test")
load("//decomp:staging.bzl", _staged_file = "staged_file")
load("//decomp:verified_inputs.bzl", _verified_files = "verified_files")

check_test = _check_test
ghidra_oracle = _ghidra_oracle
ghidra_pipeline = _ghidra_pipeline
ghidra_session = _ghidra_session
image_splice = _image_splice
script_check = _script_check
sentinel_test = _sentinel_test
staged_file = _staged_file
verified_files = _verified_files
