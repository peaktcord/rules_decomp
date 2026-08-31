"""Exact file-comparison tests for generated sentinel outputs."""

load("@rules_cc//cc:cc_test.bzl", "cc_test")

def sentinel_test(
        name,
        actual,
        expected,
        actual_path = "",
        expected_path = "",
        tags = [],
        **kwargs):
    """Compare a generated file (or file within a tree artifact) byte-for-byte."""
    actual_arg = "$(rootpath %s)" % actual
    expected_arg = "$(rootpath %s)" % expected
    if actual_path:
        actual_arg += "/" + actual_path
    if expected_path:
        expected_arg += "/" + expected_path
    cc_test(
        name = name,
        srcs = ["@rules_decomp//testing:compare_files.cpp"],
        args = [actual_arg, expected_arg],
        data = [actual, expected],
        tags = tags,
        **kwargs
    )
