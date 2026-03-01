"""
mozbuild_package rule: multi-phase Firefox/mach build with discrete caching.

Five cacheable actions:

1. src_unpack    — obtain source from source dep (shared with all rules)
2. src_prepare   — apply patches + pre_configure_cmds
3. configure     — ./mach configure (isolated MOZBUILD_STATE_PATH)
4. build         — ./mach build (with pre-warmed cargo deps from cache)
5. install       — DESTDIR=$OUT ./mach install
"""

load("//defs:providers.bzl", "PackageInfo")
load("//defs/rules:_common.bzl",
     "COMMON_PACKAGE_ATTRS",
     "add_flag_file", "build_package_tsets", "collect_dep_tsets",
     "src_prepare",
     "write_dep_prefixes",
)
load("//defs:toolchain_helpers.bzl", "toolchain_path_args")
load("//defs:host_tools.bzl", "host_tool_path_args")

# ── Phase helpers ─────────────────────────────────────────────────────

def _configure(ctx, source, dep_prefixes_file = None):
    """Phase: ./mach configure."""
    output = ctx.actions.declare_output("configured", dir = True)
    cmd = cmd_args(ctx.attrs._mozbuild_tool[RunInfo])
    cmd.add("--phase", "configure")
    cmd.add("--source-dir", source)
    cmd.add("--output-dir", output.as_output())
    for opt in ctx.attrs.mozconfig_options:
        cmd.add(cmd_args("--mozconfig-option=", opt, delimiter = ""))

    # Dep base dirs via tset projection file
    add_flag_file(cmd, "--dep-base-dirs-file", dep_prefixes_file)

    # Hermetic PATH from toolchain
    for arg in toolchain_path_args(ctx):
        cmd.add(arg)

    # Add host_deps bin dirs to PATH
    for arg in host_tool_path_args(ctx):
        cmd.add(arg)

    ctx.actions.run(cmd, category = "mozbuild_configure", identifier = ctx.attrs.name, allow_cache_upload = True)
    return output


def _build(ctx, source, configured, dep_prefixes_file = None):
    """Phase: ./mach build (configure + compile in one action).

    Combines configure + rust + C++ into a single build phase for
    simplicity.  The key isolation wins (MOZBUILD_STATE_PATH, pkg-config
    --define-prefix) are handled by the Python helper.
    """
    output = ctx.actions.declare_output("built", dir = True)
    cmd = cmd_args(ctx.attrs._mozbuild_tool[RunInfo])
    cmd.add("--phase", "build")
    cmd.add("--source-dir", source)
    cmd.add("--configured-dir", configured)
    cmd.add("--output-dir", output.as_output())
    for opt in ctx.attrs.mozconfig_options:
        cmd.add(cmd_args("--mozconfig-option=", opt, delimiter = ""))

    # Dep base dirs via tset projection file
    add_flag_file(cmd, "--dep-base-dirs-file", dep_prefixes_file)

    # Hermetic PATH from toolchain
    for arg in toolchain_path_args(ctx):
        cmd.add(arg)

    # Add host_deps bin dirs to PATH
    for arg in host_tool_path_args(ctx):
        cmd.add(arg)

    ctx.actions.run(cmd, category = "mozbuild_build", identifier = ctx.attrs.name, allow_cache_upload = True)
    return output


def _install(ctx, source, built, dep_prefixes_file = None):
    """Phase: DESTDIR=$OUT ./mach install."""
    output = ctx.actions.declare_output("installed", dir = True)
    cmd = cmd_args(ctx.attrs._mozbuild_tool[RunInfo])
    cmd.add("--phase", "install")
    cmd.add("--source-dir", source)
    cmd.add("--built-dir", built)
    cmd.add("--output-dir", output.as_output())
    for opt in ctx.attrs.mozconfig_options:
        cmd.add(cmd_args("--mozconfig-option=", opt, delimiter = ""))

    # Dep base dirs via tset projection file
    add_flag_file(cmd, "--dep-base-dirs-file", dep_prefixes_file)

    # Hermetic PATH from toolchain
    for arg in toolchain_path_args(ctx):
        cmd.add(arg)

    # Add host_deps bin dirs to PATH
    for arg in host_tool_path_args(ctx):
        cmd.add(arg)

    ctx.actions.run(cmd, category = "mozbuild_install", identifier = ctx.attrs.name, allow_cache_upload = True)
    return output


# ── Rule implementation ───────────────────────────────────────────────

def _mozbuild_package_impl(ctx):
    # Phase 1: src_unpack
    source = ctx.attrs.source[DefaultInfo].default_outputs[0]

    # Phase 2: src_prepare
    prepared = src_prepare(ctx, source, "mozbuild_prepare")

    # Collect dep-only tsets and write flag files for build phases
    _dep_compile, _dep_link, dep_path = collect_dep_tsets(ctx)
    dep_prefixes_file = write_dep_prefixes(ctx, dep_path)

    # Phase 3: configure
    configured = _configure(ctx, prepared, dep_prefixes_file)

    # Phase 4: build
    built = _build(ctx, prepared, configured, dep_prefixes_file)

    # Phase 5: install
    installed = _install(ctx, prepared, built, dep_prefixes_file)

    # Build transitive sets
    compile_tset, link_tset, path_tset, runtime_tset = build_package_tsets(ctx, installed)

    pkg_info = PackageInfo(
        name = ctx.attrs.name,
        version = ctx.attrs.version,
        prefix = installed,
        libraries = [],
        cflags = [],
        ldflags = [],
        compile_info = compile_tset,
        link_info = link_tset,
        path_info = path_tset,
        runtime_deps = runtime_tset,
        license = ctx.attrs.license,
        src_uri = ctx.attrs.src_uri,
        src_sha256 = ctx.attrs.src_sha256,
        homepage = ctx.attrs.homepage,
        supplier = "Organization: BuckOS",
        description = ctx.attrs.description,
        cpe = ctx.attrs.cpe,
    )

    return [DefaultInfo(default_output = installed), pkg_info]


# ── Rule definition ───────────────────────────────────────────────────

mozbuild_package = rule(
    impl = _mozbuild_package_impl,
    attrs = COMMON_PACKAGE_ATTRS | {
        # Mozbuild-specific
        "mozconfig_options": attrs.list(attrs.string(), default = []),
        "_mozbuild_tool": attrs.default_only(
            attrs.exec_dep(default = "//tools:mozbuild_helper"),
        ),
    },
)
