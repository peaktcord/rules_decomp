"""Bzlmod extension for shared decompilation tool and source repositories."""

load("//repositories:patched_archive.bzl", "patched_archive_repository")
load("//repositories:pypy.bzl", "pypy_repository")
load("//repositories:vice.bzl", "vice_repository")

_pypy = tag_class(attrs = {
    "version": attr.string(default = "7.3.23"),
})

_vice = tag_class(attrs = {
    "version": attr.string(default = "3.10"),
})

_source_archive = tag_class(attrs = {
    "build_file": attr.label(allow_single_file = True),
    "name": attr.string(mandatory = True),
    "patch_strip": attr.int(default = 1),
    "patches": attr.label_list(allow_files = [".diff", ".patch"]),
    "sha256": attr.string(mandatory = True),
    "strip_prefix": attr.string(),
    "urls": attr.string_list(mandatory = True),
})

def _single_version(module_ctx, tag_name, default):
    versions = {}
    for module in module_ctx.modules:
        for tag in getattr(module.tags, tag_name):
            versions[tag.version] = True
    if len(versions) > 1:
        fail("conflicting %s versions requested: %s" % (tag_name, sorted(versions.keys())))
    return versions.keys()[0] if versions else default

def _decomp_impl(module_ctx):
    want_pypy = False
    want_vice = False
    source_names = {}
    for module in module_ctx.modules:
        if module.tags.pypy:
            want_pypy = True
        if module.tags.vice:
            want_vice = True
        for source in module.tags.source_archive:
            if source.name in source_names:
                fail("source_archive repository name requested more than once: %s" % source.name)
            source_names[source.name] = True
            kwargs = {
                "name": source.name,
                "patch_strip": source.patch_strip,
                "patches": source.patches,
                "sha256": source.sha256,
                "strip_prefix": source.strip_prefix,
                "urls": source.urls,
            }
            if source.build_file:
                kwargs["build_file"] = source.build_file
            patched_archive_repository(**kwargs)

    if want_pypy:
        pypy_repository(
            name = "decomp_pypy",
            version = _single_version(module_ctx, "pypy", "7.3.23"),
        )
    if want_vice:
        vice_repository(
            name = "decomp_vice",
            version = _single_version(module_ctx, "vice", "3.10"),
        )

decomp = module_extension(
    implementation = _decomp_impl,
    tag_classes = {
        "pypy": _pypy,
        "source_archive": _source_archive,
        "vice": _vice,
    },
)
