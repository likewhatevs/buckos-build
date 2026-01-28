"""
Distribution compatibility constraints and helpers.

This module provides utilities for managing cross-distribution compatibility,
particularly for Fedora RPM integration and hybrid package systems.

Key concepts:
- compat_tags: List of distribution identifiers a package supports
- Automatic variant selection based on USE=fedora flag
- Distribution-specific build configuration

Example usage:
    autotools_package(
        name = "bash",
        compat_tags = ["buckos-native", "fedora"],
        # Works in both BuckOS and Fedora modes
    )

    rpm_package(
        name = "firefox",
        compat_tags = ["fedora"],
        # Only available with USE=fedora
    )
"""

# =============================================================================
# DISTRIBUTION COMPATIBILITY CONSTANTS
# =============================================================================

# Distribution identifiers
DISTRO_BUCKOS = "buckos-native"
DISTRO_FEDORA = "fedora"

# All supported distributions
SUPPORTED_DISTROS = [
    DISTRO_BUCKOS,
    DISTRO_FEDORA,
]

# Constraint target paths for each distribution
DISTRO_CONSTRAINTS = {
    DISTRO_BUCKOS: "//platforms:buckos-native",
    DISTRO_FEDORA: "//platforms:fedora",
}

# =============================================================================
# DISTRIBUTION DETECTION
# =============================================================================

def get_active_distro(use_flags):
    """Determine the active distribution mode from USE flags.

    Args:
        use_flags: List of enabled USE flags

    Returns:
        Distribution identifier (buckos-native or fedora)
    """
    if "fedora" in use_flags:
        return DISTRO_FEDORA
    return DISTRO_BUCKOS

def is_fedora_mode(use_flags):
    """Check if Fedora compatibility mode is enabled.

    Args:
        use_flags: List of enabled USE flags

    Returns:
        True if USE=fedora is set
    """
    return "fedora" in use_flags

# =============================================================================
# COMPATIBILITY TAG VALIDATION
# =============================================================================

def validate_compat_tags(compat_tags):
    """Validate that compatibility tags are recognized.

    Args:
        compat_tags: List of distribution identifiers

    Returns:
        List of warnings for unknown tags
    """
    if not compat_tags:
        return []

    warnings = []
    for tag in compat_tags:
        if tag not in SUPPORTED_DISTROS:
            warnings.append("Unknown distribution tag: {}. Supported: {}".format(
                tag,
                ", ".join(SUPPORTED_DISTROS)
            ))

    return warnings

def package_supports_distro(compat_tags, distro):
    """Check if package supports a specific distribution.

    Args:
        compat_tags: List of distribution identifiers from package
        distro: Distribution identifier to check

    Returns:
        True if package supports the distribution
    """
    if not compat_tags:
        # No tags means BuckOS-native only
        return distro == DISTRO_BUCKOS

    return distro in compat_tags

# =============================================================================
# PLATFORM CONSTRAINT GENERATION
# =============================================================================

def get_distro_constraints(compat_tags):
    """Get Buck constraint_values for compatibility tags.

    Args:
        compat_tags: List of distribution identifiers

    Returns:
        List of constraint_value target paths
    """
    if not compat_tags:
        # Default to BuckOS native
        return [DISTRO_CONSTRAINTS[DISTRO_BUCKOS]]

    constraints = []
    for tag in compat_tags:
        if tag in DISTRO_CONSTRAINTS:
            constraints.append(DISTRO_CONSTRAINTS[tag])

    return constraints

# =============================================================================
# DISTRIBUTION-SPECIFIC CONFIGURATION
# =============================================================================

def select_by_distro(distro_configs, default = None):
    """Create a select() configuration for distribution variants.

    Args:
        distro_configs: Dict mapping distro identifier to value
                       Example: {"fedora": "value1", "buckos-native": "value2"}
        default: Default value if no match

    Returns:
        Dict suitable for Buck's select()
    """
    result = {}

    for distro, value in distro_configs.items():
        if distro in DISTRO_CONSTRAINTS:
            constraint = DISTRO_CONSTRAINTS[distro]
            result[constraint] = value

    if default != None:
        result["DEFAULT"] = default

    return result

def distro_conditional(distro, value, default = None):
    """Return value only if specified distribution is active.

    Args:
        distro: Distribution identifier
        value: Value to return if distro is active
        default: Value to return otherwise

    Returns:
        Dict for distribution-conditional resolution
    """
    return {
        "type": "distro_conditional",
        "distro": distro,
        "value": value,
        "default": default,
    }

def resolve_distro_conditionals(items, active_distro):
    """Resolve distribution conditionals to actual values.

    Args:
        items: List of items, some may be distro_conditional dicts
        active_distro: Currently active distribution identifier

    Returns:
        Resolved list of items
    """
    result = []

    for item in items:
        if isinstance(item, dict) and item.get("type") == "distro_conditional":
            if item["distro"] == active_distro:
                if isinstance(item["value"], list):
                    result.extend(item["value"])
                else:
                    result.append(item["value"])
            elif item.get("default") != None:
                if isinstance(item["default"], list):
                    result.extend(item["default"])
                else:
                    result.append(item["default"])
        else:
            result.append(item)

    return result
