# Platform targeting helpers for BuckOs build system
#
# This module provides utilities for tagging targets by platform and
# querying targets for specific platforms.

# Platform constants
PLATFORM_LINUX = "linux"
PLATFORM_BSD = "bsd"
PLATFORM_MACOS = "macos"
PLATFORM_WINDOWS = "windows"

# List of all supported platforms
ALL_PLATFORMS = [
    PLATFORM_LINUX,
    PLATFORM_BSD,
    PLATFORM_MACOS,
    PLATFORM_WINDOWS,
]

# Platform constraint targets (using prelude OS constraints for host detection)
PLATFORM_CONSTRAINTS = {
    PLATFORM_LINUX: "prelude//os/constraints:linux",
    PLATFORM_BSD: "prelude//os/constraints:freebsd",
    PLATFORM_MACOS: "prelude//os/constraints:macos",
    PLATFORM_WINDOWS: "prelude//os/constraints:windows",
}

# Platform target configurations
PLATFORM_TARGETS = {
    PLATFORM_LINUX: "//platforms:linux-target",
    PLATFORM_BSD: "//platforms:bsd-target",
    PLATFORM_MACOS: "//platforms:macos-target",
    PLATFORM_WINDOWS: "//platforms:windows-target",
}

def get_platform_constraint(platform):
    """Get the constraint value target for a platform.

    Args:
        platform: One of PLATFORM_LINUX, PLATFORM_BSD, PLATFORM_MACOS, PLATFORM_WINDOWS

    Returns:
        The constraint value target string (e.g., "//platforms:linux")
    """
    if platform not in PLATFORM_CONSTRAINTS:
        fail("Unknown platform: {}. Must be one of: {}".format(platform, ALL_PLATFORMS))
    return PLATFORM_CONSTRAINTS[platform]

def get_platform_target(platform):
    """Get the platform target for a specific platform.

    Args:
        platform: One of PLATFORM_LINUX, PLATFORM_BSD, PLATFORM_MACOS, PLATFORM_WINDOWS

    Returns:
        The platform target string (e.g., "//platforms:linux-target")
    """
    if platform not in PLATFORM_TARGETS:
        fail("Unknown platform: {}. Must be one of: {}".format(platform, ALL_PLATFORMS))
    return PLATFORM_TARGETS[platform]

def platform_filegroup(
        name,
        srcs,
        platforms,
        visibility = None):
    """Create a filegroup that is tagged with supported platforms.

    This creates a filegroup with platform metadata in labels that can be
    queried using buck2 query.

    Args:
        name: The target name
        srcs: List of source targets to include
        platforms: List of platforms this target supports (e.g., [PLATFORM_LINUX, PLATFORM_BSD])
        visibility: Target visibility

    Example:
        platform_filegroup(
            name = "my-package",
            srcs = [":my-package-build"],
            platforms = [PLATFORM_LINUX, PLATFORM_BSD],
        )
    """
    # Validate platforms
    for platform in platforms:
        if platform not in ALL_PLATFORMS:
            fail("Unknown platform: {}. Must be one of: {}".format(platform, ALL_PLATFORMS))

    # Create labels for platform tagging
    labels = ["platform:{}".format(p) for p in platforms]

    native.filegroup(
        name = name,
        srcs = srcs,
        labels = labels,
        visibility = visibility,
    )

def linux_targets(targets):
    """Filter a list of targets to only those that support Linux.

    This is a helper for creating filegroups of Linux-compatible targets.

    Args:
        targets: List of target labels

    Returns:
        The same list (for use in filegroup srcs)

    Note:
        This function is primarily for documentation purposes. The actual
        filtering should be done using buck2 query with label filters:

        buck2 query 'attrfilter(labels, "platform:linux", //...)'
    """
    return targets

def bsd_targets(targets):
    """Filter a list of targets to only those that support BSD.

    Args:
        targets: List of target labels

    Returns:
        The same list (for use in filegroup srcs)
    """
    return targets

def macos_targets(targets):
    """Filter a list of targets to only those that support macOS.

    Args:
        targets: List of target labels

    Returns:
        The same list (for use in filegroup srcs)
    """
    return targets

def windows_targets(targets):
    """Filter a list of targets to only those that support Windows.

    Args:
        targets: List of target labels

    Returns:
        The same list (for use in filegroup srcs)
    """
    return targets

def get_targets_for_platform(platform):
    """Get the buck2 query command to find all targets for a platform.

    Args:
        platform: One of PLATFORM_LINUX, PLATFORM_BSD, PLATFORM_MACOS, PLATFORM_WINDOWS

    Returns:
        A string containing the buck2 query command

    Example:
        # In a script or documentation:
        cmd = get_targets_for_platform(PLATFORM_LINUX)
        # Returns: 'buck2 query "attrfilter(labels, \\"platform:linux\\", //...)"'
    """
    if platform not in ALL_PLATFORMS:
        fail("Unknown platform: {}. Must be one of: {}".format(platform, ALL_PLATFORMS))

    return 'buck2 query "attrfilter(labels, \\"platform:{}\\", //...)"'.format(platform)

def platform_select(platform_values, default = None):
    """Create a select() dict for platform-specific values.

    This is a convenience wrapper around select() for platform targeting.

    Args:
        platform_values: Dict mapping platform names to values
                        e.g., {PLATFORM_LINUX: ["--with-linux"], PLATFORM_BSD: ["--with-bsd"]}
        default: Default value if platform is not specified

    Returns:
        A dict suitable for use with select()

    Example:
        autotools_package(
            name = "mypackage",
            configure_args = select(platform_select({
                PLATFORM_LINUX: ["--enable-linux-specific"],
                PLATFORM_BSD: ["--enable-bsd-specific"],
            }, default = [])),
        )
    """
    result = {}

    for platform, value in platform_values.items():
        if platform not in PLATFORM_CONSTRAINTS:
            fail("Unknown platform: {}. Must be one of: {}".format(platform, ALL_PLATFORMS))
        result[PLATFORM_CONSTRAINTS[platform]] = value

    if default != None:
        result["DEFAULT"] = default

    return result

def is_platform_compatible(platforms, target_platform):
    """Check if a target platform is in the list of supported platforms.

    Args:
        platforms: List of supported platforms
        target_platform: The platform to check

    Returns:
        True if target_platform is in platforms, False otherwise
    """
    return target_platform in platforms

# Convenience constants for common platform combinations
UNIX_PLATFORMS = [PLATFORM_LINUX, PLATFORM_BSD, PLATFORM_MACOS]
POSIX_PLATFORMS = [PLATFORM_LINUX, PLATFORM_BSD, PLATFORM_MACOS]
ALL_UNIX = UNIX_PLATFORMS
