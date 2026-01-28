"""
Central version registry for all BuckOs packages.

This file serves as the authoritative source for:
- All available package versions
- Default/stable version selections
- Slot assignments
- Version deprecation status

The registry scales to thousands of packages by:
1. Using efficient dict lookups (O(1) access)
2. Lazy loading - versions only resolved when needed
3. Category-based organization for manageable chunks
4. Machine-readable format for tooling integration

Usage:
    load("//defs:registry.bzl", "PACKAGE_REGISTRY", "get_default_version", "get_versions_in_slot")
"""

# ============================================================================
# PACKAGE REGISTRY SCHEMA
# ============================================================================

# Registry entry format:
# "category/name": {
#     "default": "version",      # Default stable version
#     "versions": {
#         "version": {
#             "slot": "X.Y",     # Installation slot
#             "status": "stable|testing|deprecated|masked",
#             "eapi": "8",       # Build API version
#         },
#     },
# }

# ============================================================================
# CORE SYSTEM PACKAGES
# ============================================================================

CORE_PACKAGES = {
    "core/musl": {
        "default": "1.2.4",
        "versions": {
            "1.2.4": {"slot": "0", "status": "stable"},
            "1.2.3": {"slot": "0", "status": "stable"},
            "1.2.2": {"slot": "0", "status": "deprecated"},
        },
    },
    "core/glibc": {
        "default": "2.39",
        "versions": {
            "2.39": {"slot": "2.39", "status": "stable"},
            "2.38": {"slot": "2.38", "status": "stable"},
            "2.37": {"slot": "2.37", "status": "deprecated"},
        },
    },
    "core/zlib": {
        "default": "1.3.1",
        "versions": {
            "1.3.1": {"slot": "0", "status": "stable"},
            "1.3": {"slot": "0", "status": "stable"},
            "1.2.13": {"slot": "0", "status": "deprecated"},
            "1.2.11": {"slot": "0", "status": "deprecated"},
        },
    },
    "core/openssl": {
        "default": "3.2.0",
        "versions": {
            # OpenSSL 3.x series (current)
            "3.2.0": {"slot": "3", "status": "stable"},
            "3.1.4": {"slot": "3", "status": "stable"},
            "3.0.12": {"slot": "3", "status": "stable"},
            # OpenSSL 1.1.x series (LTS, widely needed)
            "1.1.1w": {"slot": "1.1", "status": "stable"},
            "1.1.1v": {"slot": "1.1", "status": "deprecated"},
            # OpenSSL 1.0.x (legacy)
            "1.0.2u": {"slot": "1.0", "status": "masked"},
        },
    },
    "core/ncurses": {
        "default": "6.4",
        "versions": {
            "6.4": {"slot": "0", "status": "stable"},
            "6.3": {"slot": "0", "status": "stable"},
            "5.9": {"slot": "5", "status": "deprecated"},
        },
    },
    "core/readline": {
        "default": "8.2",
        "versions": {
            "8.2": {"slot": "0", "status": "stable"},
            "8.1": {"slot": "0", "status": "stable"},
            "7.0": {"slot": "0", "status": "deprecated"},
        },
    },
    "core/bash": {
        "default": "5.2.21",
        "versions": {
            "5.2.21": {"slot": "0", "status": "stable"},
            "5.1.16": {"slot": "0", "status": "stable"},
            "4.4.23": {"slot": "0", "status": "deprecated"},
        },
    },
    "core/coreutils": {
        "default": "9.4",
        "versions": {
            "9.4": {"slot": "0", "status": "stable"},
            "9.3": {"slot": "0", "status": "stable"},
            "8.32": {"slot": "0", "status": "deprecated"},
        },
    },
}

# ============================================================================
# DEVELOPMENT LIBRARIES
# ============================================================================

DEV_LIBS_PACKAGES = {
    "dev-libs/boost": {
        "default": "1.84.0",
        "versions": {
            "1.84.0": {"slot": "1.84", "status": "stable"},
            "1.83.0": {"slot": "1.83", "status": "stable"},
            "1.82.0": {"slot": "1.82", "status": "stable"},
            "1.81.0": {"slot": "1.81", "status": "deprecated"},
            "1.75.0": {"slot": "1.75", "status": "deprecated"},
        },
    },
    "dev-libs/icu": {
        "default": "74.1",
        "versions": {
            "74.1": {"slot": "74", "status": "stable"},
            "73.2": {"slot": "73", "status": "stable"},
            "72.1": {"slot": "72", "status": "deprecated"},
            "71.1": {"slot": "71", "status": "deprecated"},
        },
    },
    "dev-libs/glib": {
        "default": "2.78.3",
        "versions": {
            "2.78.3": {"slot": "2", "status": "stable"},
            "2.76.6": {"slot": "2", "status": "stable"},
            "2.74.7": {"slot": "2", "status": "deprecated"},
        },
    },
    "dev-libs/libxml2": {
        "default": "2.12.3",
        "versions": {
            "2.12.3": {"slot": "2", "status": "stable"},
            "2.11.6": {"slot": "2", "status": "stable"},
            "2.10.4": {"slot": "2", "status": "deprecated"},
        },
    },
    "dev-libs/protobuf": {
        "default": "25.1",
        "versions": {
            "25.1": {"slot": "25", "status": "stable"},
            "24.4": {"slot": "24", "status": "stable"},
            "23.4": {"slot": "23", "status": "deprecated"},
            "21.12": {"slot": "21", "status": "deprecated"},
            "3.21.12": {"slot": "3", "status": "masked"},
        },
    },
    "dev-libs/libevent": {
        "default": "2.1.12",
        "versions": {
            "2.1.12": {"slot": "0", "status": "stable"},
            "2.1.11": {"slot": "0", "status": "deprecated"},
        },
    },
}

# ============================================================================
# PROGRAMMING LANGUAGES
# ============================================================================

LANG_PACKAGES = {
    "lang/python": {
        "default": "3.12.1",
        "versions": {
            # Python 3.12 (current)
            "3.12.1": {"slot": "3.12", "status": "stable"},
            "3.12.0": {"slot": "3.12", "status": "stable"},
            # Python 3.11 (previous stable)
            "3.11.7": {"slot": "3.11", "status": "stable"},
            "3.11.6": {"slot": "3.11", "status": "stable"},
            # Python 3.10 (maintenance)
            "3.10.13": {"slot": "3.10", "status": "stable"},
            # Python 3.9 (security fixes only)
            "3.9.18": {"slot": "3.9", "status": "stable"},
            # Python 3.8 (end of life soon)
            "3.8.18": {"slot": "3.8", "status": "deprecated"},
            # Python 2.7 (legacy, many still need it)
            "2.7.18": {"slot": "2.7", "status": "masked"},
        },
    },
    "lang/ruby": {
        "default": "3.3.0",
        "versions": {
            "3.3.0": {"slot": "3.3", "status": "stable"},
            "3.2.2": {"slot": "3.2", "status": "stable"},
            "3.1.4": {"slot": "3.1", "status": "stable"},
            "3.0.6": {"slot": "3.0", "status": "deprecated"},
            "2.7.8": {"slot": "2.7", "status": "masked"},
        },
    },
    "lang/nodejs": {
        "default": "20.10.0",
        "versions": {
            # Node.js 20 LTS (current)
            "20.10.0": {"slot": "20", "status": "stable"},
            "20.9.0": {"slot": "20", "status": "stable"},
            # Node.js 18 LTS (maintenance)
            "18.19.0": {"slot": "18", "status": "stable"},
            "18.18.2": {"slot": "18", "status": "stable"},
            # Node.js 16 (end of life)
            "16.20.2": {"slot": "16", "status": "deprecated"},
        },
    },
    "lang/go": {
        "default": "1.21.5",
        "versions": {
            "1.21.5": {"slot": "1.21", "status": "stable"},
            "1.21.4": {"slot": "1.21", "status": "stable"},
            "1.20.12": {"slot": "1.20", "status": "stable"},
            "1.19.13": {"slot": "1.19", "status": "deprecated"},
        },
    },
    "lang/rust": {
        "default": "1.74.1",
        "versions": {
            "1.74.1": {"slot": "stable", "status": "stable"},
            "1.74.0": {"slot": "stable", "status": "stable"},
            "1.73.0": {"slot": "stable", "status": "deprecated"},
            "1.72.1": {"slot": "stable", "status": "deprecated"},
        },
    },
    "lang/perl": {
        "default": "5.38.2",
        "versions": {
            "5.38.2": {"slot": "5.38", "status": "stable"},
            "5.36.3": {"slot": "5.36", "status": "stable"},
            "5.34.1": {"slot": "5.34", "status": "deprecated"},
            "5.32.1": {"slot": "5.32", "status": "deprecated"},
        },
    },
    "lang/lua": {
        "default": "5.4.6",
        "versions": {
            "5.4.6": {"slot": "5.4", "status": "stable"},
            "5.3.6": {"slot": "5.3", "status": "stable"},
            "5.2.4": {"slot": "5.2", "status": "deprecated"},
            "5.1.5": {"slot": "5.1", "status": "deprecated"},
        },
    },
    "lang/php": {
        "default": "8.3.1",
        "versions": {
            "8.3.1": {"slot": "8.3", "status": "stable"},
            "8.2.14": {"slot": "8.2", "status": "stable"},
            "8.1.27": {"slot": "8.1", "status": "stable"},
            "8.0.30": {"slot": "8.0", "status": "deprecated"},
            "7.4.33": {"slot": "7.4", "status": "masked"},
        },
    },
}

# ============================================================================
# DATABASE PACKAGES
# ============================================================================

DATABASE_PACKAGES = {
    "dev-libs/database/sqlite": {
        "default": "3.44.2",
        "versions": {
            "3.44.2": {"slot": "3", "status": "stable"},
            "3.43.2": {"slot": "3", "status": "stable"},
            "3.42.0": {"slot": "3", "status": "deprecated"},
        },
    },
    "dev-libs/database/postgresql-libs": {
        "default": "16.1",
        "versions": {
            "16.1": {"slot": "16", "status": "stable"},
            "15.5": {"slot": "15", "status": "stable"},
            "14.10": {"slot": "14", "status": "stable"},
            "13.13": {"slot": "13", "status": "deprecated"},
            "12.17": {"slot": "12", "status": "masked"},
        },
    },
}

# ============================================================================
# GRAPHICS PACKAGES
# ============================================================================

GRAPHICS_PACKAGES = {
    "graphics/mesa": {
        "default": "23.3.2",
        "versions": {
            "23.3.2": {"slot": "0", "status": "stable"},
            "23.2.1": {"slot": "0", "status": "stable"},
            "23.1.9": {"slot": "0", "status": "deprecated"},
        },
    },
    "fonts/freetype": {
        "default": "2.13.2",
        "versions": {
            "2.13.2": {"slot": "2", "status": "stable"},
            "2.13.1": {"slot": "2", "status": "stable"},
            "2.12.1": {"slot": "2", "status": "deprecated"},
        },
    },
}

# ============================================================================
# COMBINED REGISTRY
# ============================================================================

PACKAGE_REGISTRY = {}
PACKAGE_REGISTRY.update(CORE_PACKAGES)
PACKAGE_REGISTRY.update(DEV_LIBS_PACKAGES)
PACKAGE_REGISTRY.update(LANG_PACKAGES)
PACKAGE_REGISTRY.update(DATABASE_PACKAGES)
PACKAGE_REGISTRY.update(GRAPHICS_PACKAGES)

# ============================================================================
# REGISTRY ACCESS FUNCTIONS
# ============================================================================

def get_package_info(package_id):
    """Get full package information from registry.

    Args:
        package_id: Package identifier (e.g., "core/openssl")

    Returns:
        Package registry entry or None
    """
    return PACKAGE_REGISTRY.get(package_id)

def get_default_version(package_id):
    """Get the default version for a package.

    Args:
        package_id: Package identifier

    Returns:
        Default version string or None
    """
    info = get_package_info(package_id)
    return info["default"] if info else None

def get_all_versions(package_id):
    """Get all available versions for a package.

    Args:
        package_id: Package identifier

    Returns:
        List of version strings, sorted newest first
    """
    info = get_package_info(package_id)
    if not info:
        return []

    versions = list(info["versions"].keys())
    # Sort by version (simple string sort works for semver)
    return sorted(versions, reverse=True)

def get_versions_in_slot(package_id, slot):
    """Get all versions in a specific slot.

    Args:
        package_id: Package identifier
        slot: Slot identifier

    Returns:
        List of version strings in that slot
    """
    info = get_package_info(package_id)
    if not info:
        return []

    return [v for v, meta in info["versions"].items() if meta.get("slot") == slot]

def get_stable_versions(package_id):
    """Get all stable versions for a package.

    Args:
        package_id: Package identifier

    Returns:
        List of stable version strings
    """
    info = get_package_info(package_id)
    if not info:
        return []

    return [v for v, meta in info["versions"].items() if meta.get("status") == "stable"]

def get_version_status(package_id, version):
    """Get the status of a specific version.

    Args:
        package_id: Package identifier
        version: Version string

    Returns:
        Status string (stable, testing, deprecated, masked) or None
    """
    info = get_package_info(package_id)
    if not info or version not in info["versions"]:
        return None

    return info["versions"][version].get("status", "testing")

def get_version_slot(package_id, version):
    """Get the slot for a specific version.

    Args:
        package_id: Package identifier
        version: Version string

    Returns:
        Slot string or None
    """
    info = get_package_info(package_id)
    if not info or version not in info["versions"]:
        return None

    return info["versions"][version].get("slot", "0")

def list_all_packages():
    """Get list of all registered packages.

    Returns:
        List of package identifiers
    """
    return sorted(PACKAGE_REGISTRY.keys())

def list_packages_by_category(category):
    """Get list of packages in a category.

    Args:
        category: Category name (e.g., "core", "dev-libs")

    Returns:
        List of package identifiers in that category
    """
    return [p for p in PACKAGE_REGISTRY.keys() if p.startswith(category + "/")]

def find_packages_with_slot(slot):
    """Find all packages that have a specific slot.

    Useful for finding all packages that can be installed in parallel.

    Args:
        slot: Slot identifier

    Returns:
        Dict of package_id -> versions with that slot
    """
    results = {}
    for pkg_id, info in PACKAGE_REGISTRY.items():
        matching = [v for v, meta in info["versions"].items() if meta.get("slot") == slot]
        if matching:
            results[pkg_id] = matching
    return results

# ============================================================================
# REGISTRY STATISTICS
# ============================================================================

def registry_stats():
    """Get statistics about the registry.

    Returns:
        Dict with registry statistics
    """
    total_packages = len(PACKAGE_REGISTRY)
    total_versions = sum(len(info["versions"]) for info in PACKAGE_REGISTRY.values())

    status_counts = {"stable": 0, "testing": 0, "deprecated": 0, "masked": 0}
    for info in PACKAGE_REGISTRY.values():
        for meta in info["versions"].values():
            status = meta.get("status", "testing")
            status_counts[status] = status_counts.get(status, 0) + 1

    return {
        "total_packages": total_packages,
        "total_versions": total_versions,
        "by_status": status_counts,
    }
