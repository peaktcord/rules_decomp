"""Public BUILD APIs for rules_decomp."""

load("//decomp:sentinel.bzl", _sentinel_test = "sentinel_test")
load("//decomp:verified_inputs.bzl", _verified_files = "verified_files")

sentinel_test = _sentinel_test
verified_files = _verified_files
