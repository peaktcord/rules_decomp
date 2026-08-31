"""A checksummed source archive with project-owned patches and BUILD overlay."""

def _patched_archive_impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = repository_ctx.attr.urls,
        sha256 = repository_ctx.attr.sha256,
        stripPrefix = repository_ctx.attr.strip_prefix,
    )
    for patch in repository_ctx.attr.patches:
        repository_ctx.patch(patch, strip = repository_ctx.attr.patch_strip)
    if repository_ctx.attr.build_file:
        repository_ctx.file("BUILD.bazel", repository_ctx.read(repository_ctx.attr.build_file))
    elif not repository_ctx.path("BUILD.bazel").exists:
        repository_ctx.file("BUILD.bazel", "package(default_visibility = [\"//visibility:public\"])\n")

patched_archive_repository = repository_rule(
    implementation = _patched_archive_impl,
    attrs = {
        "build_file": attr.label(allow_single_file = True),
        "patch_strip": attr.int(default = 1),
        "patches": attr.label_list(allow_files = [".diff", ".patch"]),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "urls": attr.string_list(mandatory = True),
    },
    doc = "Downloads a verified archive, applies checked-in patches, and optionally overlays BUILD.bazel.",
)
