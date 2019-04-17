load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
    "http_file",
    "http_jar",
)

def _create_coordinates(fully_qualified_name, packaging = "jar"):
    parts = fully_qualified_name.split(":")
    classifier = None

    if len(parts) == 3:
        group_id, artifact_id, version = parts

        # Updates the FQN with the default packaging so that the Maven plugin
        # downloads the correct artifact.
        fully_qualified_name = "%s:%s" % (fully_qualified_name, packaging)
    elif len(parts) == 4:
        group_id, artifact_id, version, packaging = parts
    elif len(parts) == 5:
        group_id, artifact_id, version, packaging, classifier = parts
    else:
        fail("Invalid fully qualified name for artifact: %s" % fully_qualified_name)

    return struct(
        fully_qualified_name = fully_qualified_name,
        group_id = group_id,
        artifact_id = artifact_id,
        packaging = packaging,
        classifier = classifier,
        version = version,
    )

def run_bazel_deps_for_deps_file(repo_ctx, deps_file):
    # TODO: to avoid bugs, create another repo
    # to be the real repository and make it third_party instead.
    repo_ctx.download_and_extract(
        "https://github.com/reflexe/bazel-deps/archive/master.zip",
        stripPrefix = "bazel-deps-master",
    )

    args = [
        "bazel",
        "run",
        "//:parse",
        "--",
        "generate",
        "-d",
        deps_file.basename,
        "-s",
        "workspace.bzl",
        "--repo-root",
        str(deps_file.dirname),
    ]

    repo_ctx.execute(args, quiet = False)

DEPENDENCIES_YML_TEMPLATE = """
# GENERATED by maven_lib.bzl
options:
    resolvers:
        - id: "mavencentral"
          type: "default"
          url: https://repo.maven.apache.org/maven2/
        - id: "myserver"
          type: "default"
          url: https://dl.bintray.com/kotlin/exposed
    thirdPartyDirectory: ""
    #strictVisibility: false
replacements:
# Replace the kotlin standard libraries to the builtin ones from rules-kotlin.
    org.jetbrains.kotlin:
        kotlin-stdlib:
            target: "@com_github_jetbrains_kotlin//:kotlin-stdlib"
            lang: java
        kotlin-reflect:
            target: "@com_github_jetbrains_kotlin//:kotlin-reflect"
            lang: java
        kotlin-stdlib-common:
            target: "@com_github_jetbrains_kotlin//:kotlin-stdlib"
            lang: java
dependencies:
{dependencies}


"""

DEPENDENCY_TEMPLATE = """
  {group_id}:
    {artifact_id}:
      version: "{version}"
      lang: {lang}
"""

def generate_deps_file_for_artifact_list(artifacts):
    dependencies_content = ""
    for artifact in artifacts:
        coordinates = _create_coordinates(artifact)

        dependencies_content += DEPENDENCY_TEMPLATE.format(
            group_id = coordinates.group_id,
            artifact_id = coordinates.artifact_id,
            version = coordinates.version,
            lang = "java",
        )

        print(dependencies_content)

    return DEPENDENCIES_YML_TEMPLATE.format(dependencies = dependencies_content)

def _impl(repo_ctx):
    dep_file_path = "dependencies.yml"

    repo_ctx.file(
        dep_file_path,
        content = generate_deps_file_for_artifact_list(repo_ctx.attr.artifacts),
        executable = False,
    )

    deps_file = repo_ctx.path(dep_file_path)

    run_bazel_deps_for_deps_file(repo_ctx, deps_file)

maven_libs = repository_rule(
    implementation = _impl,
    attrs = {
        "artifacts": attr.string_list(mandatory = True),
    },
)