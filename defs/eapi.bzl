"""
EAPI (Ebuild API) versioning system for BuckOs packages.

This module provides API versioning for the BuckOs build system, similar to
Gentoo's EAPI system. It allows:
- Versioning of the build macro API
- Feature flags for different EAPI versions
- Deprecation of old behaviors
- Safe introduction of breaking changes

Example usage:
    load("//defs:eapi.bzl", "require_eapi", "CURRENT_EAPI", "eapi_has_feature")

    # Require minimum EAPI version
    require_eapi(8)

    # Check for specific feature
    if eapi_has_feature("subslots"):
        # Use subslot-aware dependency
        pass
"""

# =============================================================================
# EAPI VERSION DEFINITIONS
# =============================================================================

# Current default EAPI version
CURRENT_EAPI = 8

# Minimum supported EAPI version
MIN_SUPPORTED_EAPI = 6

# Maximum supported EAPI version
MAX_SUPPORTED_EAPI = 8

# =============================================================================
# EAPI FEATURE DEFINITIONS
# =============================================================================

# Features available in each EAPI version
EAPI_FEATURES = {
    # EAPI 6 - Base functionality
    6: {
        "default_src_prepare": True,      # Default src_prepare phase
        "eapply": True,                   # eapply and eapply_user
        "econf_args": True,               # Standard econf arguments
        "failglob": True,                 # Fail on unmatched globs
        "nonfatal": True,                 # nonfatal function
        "die_single_arg": True,           # die with single argument
        "user_patches": True,             # eapply_user support
        "doheader": True,                 # doheader and newheader
        "in_iuse": True,                  # in_iuse function
        "einstalldocs": True,             # einstalldocs function
        "unpack_case_insensitive": True,  # Case-insensitive unpack
        "dohtml_deprecated": True,        # dohtml is deprecated
    },

    # EAPI 7 - Improvements
    7: {
        "all_eapi_6": True,               # All EAPI 6 features
        "bdepend": True,                  # BDEPEND dependency type
        "sysroot": True,                  # SYSROOT and ESYSROOT
        "econf_prefix_host": True,        # --prefix and --host handling
        "runtime_env": True,              # Runtime environment variables
        "ver_functions": True,            # ver_cut, ver_rs, ver_test
        "env_unset": True,                # ENV_UNSET variable
        "dostrip": True,                  # dostrip and nostrip
        "einfo_parallel": True,           # Parallel-safe einfo
        "posix_profiles": True,           # POSIX profile behavior
        "empty_groups": True,             # Empty USE_EXPAND groups
    },

    # EAPI 8 - Latest
    8: {
        "all_eapi_7": True,               # All EAPI 7 features
        "subslots": True,                 # Subslot support for ABI tracking
        "selective_fetch": True,          # SRC_URI selective fetch
        "use_expand_unprefixed": True,    # USE_EXPAND unprefixed
        "update_config_sub": True,        # Automatic config.sub update
        "econf_auto_datarootdir": True,   # --datarootdir in econf
        "dosym_relative": True,           # dosym -r for relative symlinks
        "insopts_override": True,         # insopts override behavior
        "usev_default": True,             # usev default value
        "install_path_prefix": True,      # Controllable install paths
        "strict_use": True,               # Stricter USE flag handling
        "pkg_config_sysroot": True,       # PKG_CONFIG_SYSROOT support
    },
}

# Deprecated features by EAPI
EAPI_DEPRECATED = {
    7: [
        "dohtml",              # Use dodoc/doins instead
        "hasv",                # Use has instead
        "hasq",                # Use has instead
        "useq",                # Use use instead
        "libopts",             # Removed
    ],
    8: [
        "PORTDIR",             # Use PORTAGE_REPOSITORIES
        "ECLASSDIR",           # Use repository eclasses
        "hasv",                # Removed completely
        "hasq",                # Removed completely
    ],
}

# Banned features by EAPI (will cause build failure)
EAPI_BANNED = {
    7: [],
    8: [
        "dohtml",              # Completely removed
        "useq",                # Completely removed
    ],
}

# =============================================================================
# EAPI VALIDATION FUNCTIONS
# =============================================================================

def require_eapi(min_version):
    """
    Require a minimum EAPI version for the package.

    Args:
        min_version: Minimum required EAPI version

    Raises:
        fail() if EAPI version is not supported

    Example:
        require_eapi(8)  # Require EAPI 8 features
    """
    if min_version > MAX_SUPPORTED_EAPI:
        fail("EAPI {} is not yet supported. Maximum supported: {}".format(
            min_version, MAX_SUPPORTED_EAPI))
    if min_version < MIN_SUPPORTED_EAPI:
        fail("EAPI {} is no longer supported. Minimum supported: {}".format(
            min_version, MIN_SUPPORTED_EAPI))

def validate_eapi(eapi):
    """
    Validate that an EAPI version is supported.

    Args:
        eapi: EAPI version number

    Returns:
        True if valid, False otherwise
    """
    return eapi >= MIN_SUPPORTED_EAPI and eapi <= MAX_SUPPORTED_EAPI

def get_eapi_features(eapi):
    """
    Get all features available for an EAPI version.

    Args:
        eapi: EAPI version number

    Returns:
        Dictionary of feature names to boolean values
    """
    if not validate_eapi(eapi):
        fail("Invalid EAPI: {}".format(eapi))

    # Collect features from all versions up to and including requested
    features = {}
    for version in range(MIN_SUPPORTED_EAPI, eapi + 1):
        if version in EAPI_FEATURES:
            for feature, enabled in EAPI_FEATURES[version].items():
                if not feature.startswith("all_eapi_"):
                    features[feature] = enabled

    return features

def eapi_has_feature(feature, eapi = None):
    """
    Check if an EAPI version has a specific feature.

    Args:
        feature: Feature name to check
        eapi: EAPI version (defaults to CURRENT_EAPI)

    Returns:
        True if feature is available, False otherwise

    Example:
        if eapi_has_feature("subslots"):
            # Use subslot syntax
            pass
    """
    if eapi == None:
        eapi = CURRENT_EAPI

    features = get_eapi_features(eapi)
    return features.get(feature, False)

def is_deprecated(function_name, eapi = None):
    """
    Check if a function is deprecated in the given EAPI.

    Args:
        function_name: Name of the function
        eapi: EAPI version (defaults to CURRENT_EAPI)

    Returns:
        True if deprecated, False otherwise
    """
    if eapi == None:
        eapi = CURRENT_EAPI

    for version in range(MIN_SUPPORTED_EAPI, eapi + 1):
        if version in EAPI_DEPRECATED:
            if function_name in EAPI_DEPRECATED[version]:
                return True
    return False

def is_banned(function_name, eapi = None):
    """
    Check if a function is banned in the given EAPI.

    Args:
        function_name: Name of the function
        eapi: EAPI version (defaults to CURRENT_EAPI)

    Returns:
        True if banned, False otherwise
    """
    if eapi == None:
        eapi = CURRENT_EAPI

    for version in range(MIN_SUPPORTED_EAPI, eapi + 1):
        if version in EAPI_BANNED:
            if function_name in EAPI_BANNED[version]:
                return True
    return False

# =============================================================================
# EAPI HELPER FUNCTIONS
# =============================================================================

def get_eapi_description(eapi):
    """
    Get a description of an EAPI version.

    Args:
        eapi: EAPI version number

    Returns:
        String description of the EAPI
    """
    descriptions = {
        6: "EAPI 6 - Base BuckOs functionality with eapply and user patches",
        7: "EAPI 7 - Added BDEPEND, version functions, and sysroot support",
        8: "EAPI 8 - Latest API with subslots, selective fetch, and strict USE",
    }
    return descriptions.get(eapi, "Unknown EAPI version")

def list_eapi_versions():
    """
    List all supported EAPI versions.

    Returns:
        List of supported EAPI version numbers
    """
    return list(range(MIN_SUPPORTED_EAPI, MAX_SUPPORTED_EAPI + 1))

def get_deprecated_functions(eapi = None):
    """
    Get list of deprecated functions for an EAPI version.

    Args:
        eapi: EAPI version (defaults to CURRENT_EAPI)

    Returns:
        List of deprecated function names
    """
    if eapi == None:
        eapi = CURRENT_EAPI

    deprecated = []
    for version in range(MIN_SUPPORTED_EAPI, eapi + 1):
        if version in EAPI_DEPRECATED:
            deprecated.extend(EAPI_DEPRECATED[version])
    return deprecated

def get_banned_functions(eapi = None):
    """
    Get list of banned functions for an EAPI version.

    Args:
        eapi: EAPI version (defaults to CURRENT_EAPI)

    Returns:
        List of banned function names
    """
    if eapi == None:
        eapi = CURRENT_EAPI

    banned = []
    for version in range(MIN_SUPPORTED_EAPI, eapi + 1):
        if version in EAPI_BANNED:
            banned.extend(EAPI_BANNED[version])
    return banned

# =============================================================================
# EAPI VERSION GUARDS
# =============================================================================

def eapi_guard(min_eapi, feature_name):
    """
    Create a guard that checks for minimum EAPI.

    Args:
        min_eapi: Minimum required EAPI
        feature_name: Name of the feature being guarded

    Returns:
        Shell script guard code

    Example:
        guard = eapi_guard(8, "subslots")
        # Returns code that fails if EAPI < 8
    """
    return '''
if [ "${{EAPI:-{current}}}" -lt {min_eapi} ]; then
    echo "Error: {feature} requires EAPI >= {min_eapi}" >&2
    exit 1
fi
'''.format(current = CURRENT_EAPI, min_eapi = min_eapi, feature = feature_name)

def deprecation_warning(function_name, replacement = None):
    """
    Generate a deprecation warning for a function.

    Args:
        function_name: Name of the deprecated function
        replacement: Optional replacement function name

    Returns:
        Shell script warning code
    """
    if replacement:
        return 'echo "Warning: {} is deprecated, use {} instead" >&2'.format(
            function_name, replacement)
    return 'echo "Warning: {} is deprecated" >&2'.format(function_name)

# =============================================================================
# EAPI MIGRATION HELPERS
# =============================================================================

def migration_guide(from_eapi, to_eapi):
    """
    Get migration guide between EAPI versions.

    Args:
        from_eapi: Source EAPI version
        to_eapi: Target EAPI version

    Returns:
        List of migration steps
    """
    steps = []

    if from_eapi < 7 and to_eapi >= 7:
        steps.extend([
            "Convert DEPEND to BDEPEND for build-time only dependencies",
            "Use ver_cut/ver_rs instead of get_version_component_range",
            "Update SYSROOT/ESYSROOT usage if cross-compiling",
        ])

    if from_eapi < 8 and to_eapi >= 8:
        steps.extend([
            "Replace dohtml with dodoc for HTML documentation",
            "Add subslots for packages with ABI-sensitive libraries",
            "Use dosym -r for relative symlinks",
            "Update selective SRC_URI fetch restrictions",
        ])

    return steps

def check_eapi_compatibility(package_eapi, system_eapi = None):
    """
    Check if a package is compatible with the system EAPI.

    Args:
        package_eapi: EAPI declared by the package
        system_eapi: System EAPI (defaults to CURRENT_EAPI)

    Returns:
        Dictionary with:
        - compatible: Boolean
        - warnings: List of compatibility warnings
        - errors: List of compatibility errors
    """
    if system_eapi == None:
        system_eapi = CURRENT_EAPI

    result = {
        "compatible": True,
        "warnings": [],
        "errors": [],
    }

    if package_eapi > system_eapi:
        result["compatible"] = False
        result["errors"].append(
            "Package requires EAPI {} but system only supports EAPI {}".format(
                package_eapi, system_eapi))

    if package_eapi < MIN_SUPPORTED_EAPI:
        result["compatible"] = False
        result["errors"].append(
            "Package EAPI {} is no longer supported (minimum: {})".format(
                package_eapi, MIN_SUPPORTED_EAPI))

    # Check for deprecated function usage
    deprecated = get_deprecated_functions(system_eapi)
    if deprecated:
        result["warnings"].append(
            "EAPI {} deprecates: {}".format(system_eapi, ", ".join(deprecated)))

    return result

# =============================================================================
# EAPI PHASE BEHAVIOR
# =============================================================================

# Default phase implementations by EAPI
EAPI_DEFAULT_PHASES = {
    6: {
        "src_prepare": '''
# Default src_prepare for EAPI 6+
eapply_user
''',
        "src_configure": '''
# Default src_configure
if [ -f configure ]; then
    econf
fi
''',
        "src_compile": '''
# Default src_compile
if [ -f Makefile ] || [ -f GNUmakefile ] || [ -f makefile ]; then
    emake
fi
''',
        "src_install": '''
# Default src_install
if [ -f Makefile ] || [ -f GNUmakefile ] || [ -f makefile ]; then
    emake DESTDIR="$D" install
fi
einstalldocs
''',
        "src_test": '''
# Default src_test
if [ -f Makefile ] || [ -f GNUmakefile ] || [ -f makefile ]; then
    if make -q check 2>/dev/null; then
        emake check
    elif make -q test 2>/dev/null; then
        emake test
    fi
fi
''',
    },
    7: {
        # Same as EAPI 6 with additional runtime handling
    },
    8: {
        # Same with subslot awareness
    },
}

def get_default_phase(phase, eapi = None):
    """
    Get the default implementation for a phase.

    Args:
        phase: Phase name (src_prepare, src_compile, etc.)
        eapi: EAPI version (defaults to CURRENT_EAPI)

    Returns:
        Shell script for default phase implementation
    """
    if eapi == None:
        eapi = CURRENT_EAPI

    # Find the highest EAPI <= requested that defines the phase
    for version in range(eapi, MIN_SUPPORTED_EAPI - 1, -1):
        if version in EAPI_DEFAULT_PHASES:
            phases = EAPI_DEFAULT_PHASES[version]
            if phase in phases:
                return phases[phase]

    return ""

# =============================================================================
# DOCUMENTATION
# =============================================================================

"""
## EAPI System Usage

### Specifying EAPI in Packages

```python
ebuild_package(
    name = "my-package",
    version = "1.0.0",
    eapi = 8,  # Require EAPI 8
    ...
)
```

### Checking for Features

```python
load("//defs:eapi.bzl", "eapi_has_feature", "require_eapi")

# Ensure minimum EAPI
require_eapi(8)

# Check for specific feature
if eapi_has_feature("subslots"):
    # Use subslot-aware code
    pass
```

### Migration

```python
load("//defs:eapi.bzl", "migration_guide")

# Get migration steps
steps = migration_guide(6, 8)
for step in steps:
    print(step)
```

## EAPI Version History

### EAPI 6
- Base functionality
- eapply and eapply_user
- User patches support
- doheader/newheader

### EAPI 7
- BDEPEND dependency type
- Version functions (ver_cut, ver_rs, ver_test)
- SYSROOT/ESYSROOT variables
- dostrip control

### EAPI 8 (Current)
- Subslot support for ABI tracking
- Selective fetch
- dosym -r for relative symlinks
- Strict USE flag handling
- PKG_CONFIG_SYSROOT support
"""
