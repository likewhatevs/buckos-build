# Composable QEMU rules for Buck2
#
# Provides qemu_run, qemu_test, and qemu_machine for VM-based targets
# that integrate with buck2 run / buck2 test.
#
# Command injection uses concatenated initrd: a tiny overlay cpio containing
# a custom /init is appended to the main initramfs.  The kernel extracts
# them in order — the overlay's /init takes precedence.
#
# Script generation is delegated to external shell scripts in defs/scripts/,
# following the same pattern as the CH boot script rules.

# =============================================================================
# Shared helpers
# =============================================================================

def _run_overlay_generator(ctx, cmd, net):
    """Create an overlay cpio containing /init that runs cmd."""
    overlay = ctx.actions.declare_output(ctx.attrs.name + "-overlay.cpio")
    generator = ctx.attrs._overlay_generator[DefaultInfo].default_outputs[0]

    ctx.actions.run(
        cmd_args(["bash", generator, overlay.as_output()]),
        env = {
            "QEMU_CMD": cmd,
            "QEMU_NET": "true" if net else "false",
        },
        category = "qemu_overlay",
        identifier = ctx.attrs.name,
    )
    return overlay

def _run_concat(ctx, main_initramfs, overlay):
    """Concatenate main initramfs + overlay cpio into a combined artifact."""
    combined = ctx.actions.declare_output(ctx.attrs.name + "-combined-initramfs")
    ctx.actions.run(
        cmd_args(["bash", "-c", "cat \"$1\" \"$2\" > \"$3\"", "--",
                  main_initramfs, overlay, combined.as_output()]),
        category = "qemu_concat_initramfs",
        identifier = ctx.attrs.name,
    )
    return combined

def _run_script_generator(ctx, mode, kernel_dir, initramfs):
    """Run the external QEMU script generator."""
    boot_script = ctx.actions.declare_output(ctx.attrs.name + ".sh")
    generator = ctx.attrs._script_generator[DefaultInfo].default_outputs[0]

    ctx.actions.run(
        cmd_args(["bash", generator, boot_script.as_output(), mode,
                  kernel_dir, initramfs]),
        env = {
            "QEMU_ARCH": ctx.attrs.arch,
            "QEMU_MEMORY": ctx.attrs.memory,
            "QEMU_CPUS": ctx.attrs.cpus,
            "QEMU_KERNEL_ARGS": ctx.attrs.kernel_args,
            "QEMU_EXTRA_ARGS": " ".join(ctx.attrs.extra_args) if ctx.attrs.extra_args else "",
            "QEMU_TIMEOUT": ctx.attrs.timeout,
        },
        category = "qemu_script",
        identifier = ctx.attrs.name,
    )
    return boot_script

# Common attrs shared by qemu_run and qemu_test
_QEMU_COMMON_ATTRS = {
    "kernel": attrs.dep(),
    "initramfs": attrs.dep(),
    "arch": attrs.string(default = "x86_64"),
    "memory": attrs.string(default = "512M"),
    "cpus": attrs.string(default = "2"),
    "kernel_args": attrs.string(default = "console=ttyS0 quiet"),
    "extra_args": attrs.list(attrs.string(), default = []),
    "net": attrs.bool(default = False),
    "timeout": attrs.string(default = "120"),
    "labels": attrs.list(attrs.string(), default = []),
    "_script_generator": attrs.dep(default = "//defs/scripts:generate-qemu-script"),
    "_overlay_generator": attrs.dep(default = "//defs/scripts:generate-qemu-overlay"),
}

# =============================================================================
# qemu_run rule
# =============================================================================

def _qemu_run_impl(ctx: AnalysisContext) -> list[Provider]:
    """QEMU run target — interactive shell or single command."""
    kernel_dir = ctx.attrs.kernel[DefaultInfo].default_outputs[0]
    initramfs = ctx.attrs.initramfs[DefaultInfo].default_outputs[0]

    if ctx.attrs.cmd:
        overlay = _run_overlay_generator(ctx, ctx.attrs.cmd, ctx.attrs.net)
        combined = _run_concat(ctx, initramfs, overlay)
        script = _run_script_generator(ctx, "cmd", kernel_dir, combined)
    else:
        script = _run_script_generator(ctx, "interactive", kernel_dir, initramfs)

    return [
        DefaultInfo(default_output = script),
        RunInfo(args = cmd_args(["bash", script])),
    ]

_qemu_run_attrs = dict(_QEMU_COMMON_ATTRS)
_qemu_run_attrs["cmd"] = attrs.option(attrs.string(), default = None)

_qemu_run_rule = rule(
    impl = _qemu_run_impl,
    attrs = _qemu_run_attrs,
)

def qemu_run(labels = [], **kwargs):
    _qemu_run_rule(
        labels = ["buckos:qemu"] + labels,
        **kwargs
    )

# =============================================================================
# qemu_test rule
# =============================================================================

def _qemu_test_impl(ctx: AnalysisContext) -> list[Provider]:
    """QEMU test target — runs command, reports pass/fail via exit code."""
    kernel_dir = ctx.attrs.kernel[DefaultInfo].default_outputs[0]
    initramfs = ctx.attrs.initramfs[DefaultInfo].default_outputs[0]

    overlay = _run_overlay_generator(ctx, ctx.attrs.cmd, ctx.attrs.net)
    combined = _run_concat(ctx, initramfs, overlay)
    script = _run_script_generator(ctx, "cmd", kernel_dir, combined)

    return [
        DefaultInfo(default_output = script),
        ExternalRunnerTestInfo(
            type = "custom",
            command = [cmd_args(["bash", script])],
            labels = ctx.attrs.labels,
            run_from_project_root = True,
        ),
        RunInfo(args = cmd_args(["bash", script])),
    ]

_qemu_test_attrs = dict(_QEMU_COMMON_ATTRS)
_qemu_test_attrs["cmd"] = attrs.string()

_qemu_test_rule = rule(
    impl = _qemu_test_impl,
    attrs = _qemu_test_attrs,
)

def qemu_test(labels = [], **kwargs):
    _qemu_test_rule(
        labels = ["buckos:qemu", "buckos:qemu-test"] + labels,
        **kwargs
    )

# =============================================================================
# qemu_machine convenience macro
# =============================================================================

def qemu_machine(name, kernel, initramfs, tests = {}, net = False, **kwargs):
    """Create QEMU targets from shared machine config.

    Generates:
      {name}          - interactive shell (buck2 run)
      {name}-{test}   - for each entry in tests dict (buck2 test)
    """
    qemu_run(
        name = name,
        kernel = kernel,
        initramfs = initramfs,
        net = net,
        **kwargs
    )
    for test_name, test_cmd in tests.items():
        qemu_test(
            name = name + "-" + test_name,
            kernel = kernel,
            initramfs = initramfs,
            cmd = test_cmd,
            net = net,
            **kwargs
        )
