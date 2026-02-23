"""
Bootstrap configuration transition rule.

Flips the toolchain to host PATH tools for building host tool targets
during bootstrap.  The transition sets the bootstrap-mode constraint so
TOOLCHAIN_ATTRS select() resolves to the host PATH toolchain instead of
the seed toolchain — breaking the circular dependency automatically.

Usage in rule attrs:
    attrs.transition_dep(cfg = "//tc/exec:bootstrap-transition")
"""

def _bootstrap_transition_impl(ctx):
    """Create a transition that switches to bootstrap mode."""
    setting = ctx.attrs._setting
    value = ctx.attrs._value

    def _impl(platform):
        constraints = dict(platform.configuration.constraints)
        constraints[setting[ConstraintSettingInfo].label] = value[ConstraintValueInfo]
        return PlatformInfo(
            label = "<bootstrap>",
            configuration = ConfigurationInfo(
                constraints = constraints,
                values = platform.configuration.values,
            ),
        )

    return [
        DefaultInfo(),
        TransitionInfo(impl = _impl),
    ]

bootstrap_transition = rule(
    impl = _bootstrap_transition_impl,
    attrs = {
        "_setting": attrs.dep(default = "//tc/exec:bootstrap-mode-setting"),
        "_value": attrs.dep(default = "//tc/exec:bootstrap-mode-true"),
    },
    is_configuration_rule = True,
)
