"""Local, version-checked Ghidra and JDK repository."""

def _require_directory(repository_ctx, variable):
    value = repository_ctx.os.environ.get(variable, "")
    if not value:
        fail("%s is required; pass --repo_env=%s=<absolute path>" % (variable, variable))
    path = repository_ctx.path(value)
    if not path.exists:
        fail("%s does not exist: %s" % (variable, value))
    return path

def _ghidra_repository_impl(repository_ctx):
    ghidra_root = _require_directory(repository_ctx, "GHIDRA_ROOT")
    java_home = _require_directory(repository_ctx, "GHIDRA_JAVA_HOME")
    windows = repository_ctx.os.name.lower().startswith("windows")

    analyzer_rel = "support/analyzeHeadless.bat" if windows else "support/analyzeHeadless"
    gui_rel = "ghidraRun.bat" if windows else "ghidraRun"
    java_rel = "bin/java.exe" if windows else "bin/java"
    javac_rel = "bin/javac.exe" if windows else "bin/javac"
    for root, relative, description in [
        (ghidra_root, analyzer_rel, "Ghidra headless analyzer"),
        (ghidra_root, gui_rel, "Ghidra GUI launcher"),
        (java_home, java_rel, "Java executable"),
        (java_home, javac_rel, "Java compiler"),
    ]:
        if not repository_ctx.path(str(root) + "/" + relative).exists:
            fail("%s was not found under the configured root: %s" % (description, root))

    properties = repository_ctx.path(str(ghidra_root) + "/Ghidra/application.properties")
    if not properties.exists:
        fail("Ghidra/application.properties was not found under GHIDRA_ROOT: %s" % ghidra_root)
    contents = repository_ctx.read(properties)
    expected = "application.version=%s" % repository_ctx.attr.version
    if expected not in [line.strip() for line in contents.split("\n")]:
        fail("GHIDRA_ROOT is not Ghidra %s (missing %s in application.properties)" % (
            repository_ctx.attr.version,
            expected,
        ))

    probe = repository_ctx.execute(
        [repository_ctx.path(str(java_home) + "/" + java_rel), "-version"],
        quiet = True,
    )
    if probe.return_code:
        fail("GHIDRA_JAVA_HOME Java probe failed: %s" % probe.stderr)
    version_output = probe.stdout + probe.stderr
    version_token = 'version "%s' % repository_ctx.attr.java_version
    if version_token not in version_output:
        fail("GHIDRA_JAVA_HOME is not Java %s; java -version reported: %s" % (
            repository_ctx.attr.java_version,
            version_output,
        ))
    modules = repository_ctx.execute(
        [repository_ctx.path(str(java_home) + "/" + java_rel), "--list-modules"],
        quiet = True,
    )
    if modules.return_code or "java.desktop@" not in modules.stdout:
        fail("GHIDRA_JAVA_HOME must be a full JDK containing the java.desktop module")

    repository_ctx.symlink(ghidra_root, "ghidra")
    repository_ctx.symlink(java_home, "jdk")
    os_constraint = "@platforms//os:windows" if windows else "@platforms//os:linux"
    repository_ctx.file("BUILD.bazel", """
load("@rules_decomp//toolchains/ghidra:toolchain.bzl", "ghidra_runtime")

package(default_visibility = ["//visibility:public"])

filegroup(name = "analyzer", srcs = ["ghidra/{analyzer}"])
filegroup(name = "gui", srcs = ["ghidra/{gui}"])
filegroup(name = "java", srcs = ["jdk/{java}"])
filegroup(
    name = "runtime_files",
    srcs = glob(["ghidra/**", "jdk/**"], exclude = ["BUILD.bazel"]),
)

ghidra_runtime(
    name = "runtime",
    analyzer = ":analyzer",
    files = ":runtime_files",
    gui = ":gui",
    java = ":java",
    windows = {windows},
)

toolchain(
    name = "toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "{os_constraint}",
    ],
    toolchain = ":runtime",
    toolchain_type = "@rules_decomp//toolchains/ghidra:toolchain_type",
)
""".format(
        analyzer = analyzer_rel,
        gui = gui_rel,
        java = java_rel,
        os_constraint = os_constraint,
        windows = "True" if windows else "False",
    ))

ghidra_repository = repository_rule(
    implementation = _ghidra_repository_impl,
    attrs = {
        "java_version": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
    environ = ["GHIDRA_ROOT", "GHIDRA_JAVA_HOME"],
    local = True,
    doc = "Exposes a local Ghidra installation and compatible JDK as a Bazel toolchain.",
)
