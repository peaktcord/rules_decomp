"""Expose a closed, locally installed tool tree as a Bazel repository.

Historical compilers and SDKs cannot be downloaded from an upstream release, so
each project keeps them ignored and Bazel discovers the root through a
documented environment variable, optionally defaulting to an ignored directory
below the workspace. The repository only symlinks; verification of the tool
binaries belongs to a `verified_files` target in the consuming project.

    local_tool_repository(
        name = "project_ngage",
        env_var = "NGAGE_TOOLCHAIN_ROOT",
        default_path = "extern/ngage-toolchain",
        links = {"gcc": "sdk/sdk/6.1/Shared/EPOC32/gcc"},
        required = ["sdk/sdk/6.1/Shared/EPOC32/gcc/bin/g++.exe"],
        runtime_globs = ["gcc/**"],
        aliases = {"g++": "gcc/bin/g++.exe"},
    )
"""

def _child(path, relative):
    for part in relative.replace("\\", "/").split("/"):
        if part:
            path = path.get_child(part)
    return path

def _local_tool_repository_impl(repository_ctx):
    env_var = repository_ctx.attr.env_var
    root_value = repository_ctx.getenv(env_var, "")
    if root_value:
        root = repository_ctx.path(root_value)
    elif repository_ctx.attr.default_path:
        root = _child(repository_ctx.workspace_root, repository_ctx.attr.default_path)
    else:
        fail("%s is required; pass --repo_env=%s=<absolute path>" % (env_var, env_var))
    if not root.exists:
        fail("%s root does not exist: %s. %s" % (env_var, root, repository_ctx.attr.hint))
    for relative in repository_ctx.attr.required:
        if not _child(root, relative).exists:
            fail("%s is missing %s under %s. %s" % (env_var, relative, root, repository_ctx.attr.hint))

    for link, relative in repository_ctx.attr.links.items():
        target = _child(root, relative)
        if not target.exists:
            fail("%s is missing %s under %s. %s" % (env_var, relative, root, repository_ctx.attr.hint))
        repository_ctx.symlink(target, link)

    lines = [
        'package(default_visibility = ["//visibility:public"])',
        "",
    ]
    if repository_ctx.attr.exports:
        lines.append("exports_files(%s)" % repr(repository_ctx.attr.exports))
        lines.append("")
    globs = repository_ctx.attr.runtime_globs or [link + "/**" for link in repository_ctx.attr.links]
    lines.extend([
        "# The complete tool tree is an action input: executables load adjacent",
        "# DLLs, specs, headers, and libraries.",
        "filegroup(",
        '    name = "runtime",',
        "    srcs = glob(%s, allow_empty = False)," % repr(globs),
        ")",
        "",
    ])
    for alias, actual in repository_ctx.attr.aliases.items():
        lines.append('alias(name = "%s", actual = "%s")' % (alias, actual))
    repository_ctx.file("BUILD.bazel", "\n".join(lines) + "\n")

local_tool_repository = repository_rule(
    implementation = _local_tool_repository_impl,
    attrs = {
        "env_var": attr.string(mandatory = True, doc = "Environment variable naming the tool root."),
        "default_path": attr.string(doc = "Workspace-relative fallback root, typically an ignored checkout."),
        "links": attr.string_dict(
            mandatory = True,
            doc = "Repository path to root-relative source path; directories or files.",
        ),
        "required": attr.string_list(doc = "Root-relative paths that must exist."),
        "runtime_globs": attr.string_list(doc = "Globs for the :runtime filegroup; defaults to every link."),
        "aliases": attr.string_dict(doc = "Alias name to repository-relative file."),
        "exports": attr.string_list(doc = "Repository-relative files to export."),
        "hint": attr.string(doc = "Appended to failure messages, e.g. the bootstrap command."),
    },
    configure = True,
    local = True,
)
