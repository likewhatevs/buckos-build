"""
Overlay system for BuckOs packages.

This module provides a layered repository system similar to Gentoo's overlays,
allowing users to:
- Override upstream packages with local versions
- Add custom packages not in main repository
- Apply distribution-specific patches
- Maintain separate testing/experimental packages

Example usage:
    load("//defs:overlays.bzl", "register_overlay", "resolve_package", "OVERLAYS")

    # Register a local overlay
    register_overlay(
        name = "local",
        path = "/var/db/repos/local",
        priority = 50,
    )

    # Resolve package from overlays
    target = resolve_package("core/bash", overlays = ["local", "buckos"])
"""

# =============================================================================
# OVERLAY DEFINITIONS
# =============================================================================

# Overlay entry structure
def overlay_entry(
        name,
        path,
        priority = 0,
        masters = [],
        sync_type = None,
        sync_uri = None,
        auto_sync = True,
        description = ""):
    """
    Create an overlay entry.

    Args:
        name: Overlay name (must be unique)
        path: Local filesystem path to overlay
        priority: Resolution priority (higher = preferred)
        masters: List of master overlay names for eclass inheritance
        sync_type: Sync method (git, rsync, svn, mercurial, None for local)
        sync_uri: URI to sync from
        auto_sync: Whether to sync automatically on update
        description: Human-readable description

    Returns:
        Dictionary with overlay configuration
    """
    return {
        "name": name,
        "path": path,
        "priority": priority,
        "masters": masters,
        "sync_type": sync_type,
        "sync_uri": sync_uri,
        "auto_sync": auto_sync,
        "description": description,
        "packages": {},  # Populated during scanning
    }

# =============================================================================
# BUILT-IN OVERLAYS
# =============================================================================

# Main BuckOs repository
_BUCKOS_OVERLAY = overlay_entry(
    name = "buckos",
    path = "//packages/linux",
    priority = 0,
    description = "Main BuckOs package repository",
)

# Local customizations
_LOCAL_OVERLAY = overlay_entry(
    name = "local",
    path = "/var/db/repos/local",
    priority = 50,
    masters = ["buckos"],
    description = "Local package customizations",
)

# Testing/unstable packages
_TESTING_OVERLAY = overlay_entry(
    name = "testing",
    path = "/var/db/repos/testing",
    priority = 30,
    masters = ["buckos"],
    description = "Testing and unstable packages",
)

# =============================================================================
# OVERLAY REGISTRY
# =============================================================================

# Global overlay registry
OVERLAYS = {
    "buckos": _BUCKOS_OVERLAY,
    "local": _LOCAL_OVERLAY,
    "testing": _TESTING_OVERLAY,
}

def register_overlay(
        name,
        path,
        priority = 0,
        masters = ["buckos"],
        sync_type = None,
        sync_uri = None,
        auto_sync = True,
        description = ""):
    """
    Register a new overlay in the global registry.

    Args:
        name: Overlay name (must be unique)
        path: Local filesystem path
        priority: Resolution priority (higher = preferred)
        masters: Master overlays for eclass inheritance
        sync_type: Sync method
        sync_uri: Sync URI
        auto_sync: Auto-sync on update
        description: Description

    Returns:
        The overlay entry
    """
    if name in OVERLAYS:
        fail("Overlay '{}' already registered".format(name))

    entry = overlay_entry(
        name = name,
        path = path,
        priority = priority,
        masters = masters,
        sync_type = sync_type,
        sync_uri = sync_uri,
        auto_sync = auto_sync,
        description = description,
    )

    OVERLAYS[name] = entry
    return entry

def unregister_overlay(name):
    """
    Remove an overlay from the registry.

    Args:
        name: Overlay name to remove
    """
    if name == "buckos":
        fail("Cannot unregister main buckos overlay")
    if name not in OVERLAYS:
        fail("Overlay '{}' not found".format(name))
    OVERLAYS.pop(name)

def get_overlay(name):
    """
    Get overlay configuration by name.

    Args:
        name: Overlay name

    Returns:
        Overlay entry dictionary
    """
    if name not in OVERLAYS:
        fail("Overlay '{}' not found".format(name))
    return OVERLAYS[name]

def list_overlays():
    """
    List all registered overlays.

    Returns:
        List of overlay names sorted by priority (highest first)
    """
    return sorted(OVERLAYS.keys(), key = lambda n: OVERLAYS[n]["priority"], reverse = True)

# =============================================================================
# PACKAGE RESOLUTION
# =============================================================================

def resolve_package(package_id, overlays = None, allow_masked = False):
    """
    Resolve a package from overlays.

    Searches overlays in priority order and returns the first match.

    Args:
        package_id: Package identifier (category/name)
        overlays: List of overlay names to search (None = all)
        allow_masked: Include masked packages

    Returns:
        Dictionary with:
        - overlay: Name of overlay containing package
        - path: Full path to package
        - target: Buck2 target string

    Raises:
        fail() if package not found
    """
    if overlays == None:
        overlays = list_overlays()

    for overlay_name in overlays:
        overlay = OVERLAYS[overlay_name]

        # Check if package exists in overlay
        if package_id in overlay.get("packages", {}):
            pkg_info = overlay["packages"][package_id]
            if not allow_masked and pkg_info.get("masked", False):
                continue

            return {
                "overlay": overlay_name,
                "path": "{}/{}".format(overlay["path"], package_id),
                "target": "{}:{}".format(
                    "{}/{}".format(overlay["path"], package_id),
                    package_id.split("/")[-1]
                ),
            }

    fail("Package '{}' not found in any overlay".format(package_id))

def get_package_overlay(package_id):
    """
    Get the overlay that provides a package.

    Args:
        package_id: Package identifier

    Returns:
        Overlay name or None
    """
    for overlay_name in list_overlays():
        overlay = OVERLAYS[overlay_name]
        if package_id in overlay.get("packages", {}):
            return overlay_name
    return None

def list_overlay_packages(overlay_name):
    """
    List all packages in an overlay.

    Args:
        overlay_name: Overlay to list

    Returns:
        List of package identifiers
    """
    if overlay_name not in OVERLAYS:
        fail("Overlay '{}' not found".format(overlay_name))

    return list(OVERLAYS[overlay_name].get("packages", {}).keys())

# =============================================================================
# OVERLAY SCANNING
# =============================================================================

def scan_overlay(overlay_name, scan_func = None):
    """
    Scan an overlay to discover packages.

    Args:
        overlay_name: Overlay to scan
        scan_func: Function to scan directory (for testing)

    Returns:
        Dictionary mapping package_id to package info
    """
    overlay = OVERLAYS[overlay_name]
    packages = {}

    # This would scan the overlay directory structure
    # In a real implementation, this would use filesystem operations
    # For now, we return the current packages dict
    return overlay.get("packages", {})

def register_overlay_package(overlay_name, package_id, version, **kwargs):
    """
    Register a package within an overlay.

    Args:
        overlay_name: Overlay name
        package_id: Package identifier (category/name)
        version: Package version
        **kwargs: Additional package metadata
    """
    if overlay_name not in OVERLAYS:
        fail("Overlay '{}' not found".format(overlay_name))

    if "packages" not in OVERLAYS[overlay_name]:
        OVERLAYS[overlay_name]["packages"] = {}

    OVERLAYS[overlay_name]["packages"][package_id] = {
        "version": version,
        "masked": kwargs.get("masked", False),
        "keywords": kwargs.get("keywords", []),
        "slot": kwargs.get("slot", "0"),
        "eapi": kwargs.get("eapi", 8),
    }

# =============================================================================
# OVERLAY SYNCHRONIZATION
# =============================================================================

def generate_sync_script(overlay_name):
    """
    Generate script to sync an overlay.

    Args:
        overlay_name: Overlay to sync

    Returns:
        Shell script string
    """
    overlay = OVERLAYS[overlay_name]

    if not overlay.get("sync_uri"):
        return "# No sync URI configured for overlay '{}'".format(overlay_name)

    sync_type = overlay.get("sync_type", "git")
    sync_uri = overlay["sync_uri"]
    path = overlay["path"]

    if sync_type == "git":
        return '''#!/bin/sh
# Sync overlay '{name}' from git

if [ -d "{path}/.git" ]; then
    cd "{path}" && git pull --ff-only
else
    git clone "{uri}" "{path}"
fi
'''.format(name = overlay_name, path = path, uri = sync_uri)

    elif sync_type == "rsync":
        return '''#!/bin/sh
# Sync overlay '{name}' via rsync

rsync -av --delete "{uri}" "{path}/"
'''.format(name = overlay_name, path = path, uri = sync_uri)

    elif sync_type == "svn":
        return '''#!/bin/sh
# Sync overlay '{name}' from svn

if [ -d "{path}/.svn" ]; then
    svn update "{path}"
else
    svn checkout "{uri}" "{path}"
fi
'''.format(name = overlay_name, path = path, uri = sync_uri)

    else:
        return "# Unknown sync type '{}' for overlay '{}'".format(sync_type, overlay_name)

def generate_sync_all_script():
    """
    Generate script to sync all overlays.

    Returns:
        Shell script string
    """
    script = '''#!/bin/sh
# Sync all BuckOs overlays

set -e

'''
    for overlay_name in list_overlays():
        overlay = OVERLAYS[overlay_name]
        if overlay.get("sync_uri") and overlay.get("auto_sync", True):
            script += '''
echo "Syncing overlay: {name}"
{sync_script}
'''.format(
                name = overlay_name,
                sync_script = generate_sync_script(overlay_name)
            )

    return script

# =============================================================================
# OVERLAY CONFIGURATION
# =============================================================================

def generate_repos_conf(overlay_name):
    """
    Generate repos.conf entry for an overlay.

    Args:
        overlay_name: Overlay name

    Returns:
        String in repos.conf format
    """
    overlay = OVERLAYS[overlay_name]

    conf = '''[{name}]
location = {path}
priority = {priority}
'''.format(
        name = overlay_name,
        path = overlay["path"],
        priority = overlay["priority"]
    )

    if overlay.get("sync_uri"):
        conf += "sync-uri = {}\n".format(overlay["sync_uri"])
        conf += "sync-type = {}\n".format(overlay.get("sync_type", "git"))

    if overlay.get("masters"):
        conf += "masters = {}\n".format(" ".join(overlay["masters"]))

    if overlay.get("auto_sync", True):
        conf += "auto-sync = yes\n"
    else:
        conf += "auto-sync = no\n"

    return conf

def generate_all_repos_conf():
    """
    Generate complete repos.conf file.

    Returns:
        String with all overlay configurations
    """
    conf = "# BuckOs overlay configuration\n\n"

    for overlay_name in list_overlays():
        conf += generate_repos_conf(overlay_name)
        conf += "\n"

    return conf

# =============================================================================
# ECLASS INHERITANCE FROM OVERLAYS
# =============================================================================

def get_eclass_search_path(overlay_name):
    """
    Get eclass search path for an overlay.

    Includes master overlays in inheritance order.

    Args:
        overlay_name: Overlay name

    Returns:
        List of eclass directory paths
    """
    overlay = OVERLAYS[overlay_name]
    search_path = []

    # Add master overlays first
    for master in overlay.get("masters", []):
        if master in OVERLAYS:
            master_path = OVERLAYS[master]["path"]
            search_path.append("{}/eclass".format(master_path))

    # Add this overlay's eclass directory
    search_path.append("{}/eclass".format(overlay["path"]))

    return search_path

def find_eclass(eclass_name, overlay_name):
    """
    Find an eclass in overlay search path.

    Args:
        eclass_name: Eclass name (without .eclass extension)
        overlay_name: Starting overlay

    Returns:
        Path to eclass file or None
    """
    search_path = get_eclass_search_path(overlay_name)

    for eclass_dir in reversed(search_path):  # Search in reverse (child first)
        eclass_path = "{}/{}.eclass".format(eclass_dir, eclass_name)
        # In real implementation, would check if file exists
        return eclass_path

    return None

# =============================================================================
# OVERLAY MASKING
# =============================================================================

def mask_overlay_package(overlay_name, package_id, reason = ""):
    """
    Mask a package in an overlay.

    Args:
        overlay_name: Overlay name
        package_id: Package identifier
        reason: Reason for masking
    """
    if overlay_name not in OVERLAYS:
        fail("Overlay '{}' not found".format(overlay_name))

    if package_id in OVERLAYS[overlay_name].get("packages", {}):
        OVERLAYS[overlay_name]["packages"][package_id]["masked"] = True
        OVERLAYS[overlay_name]["packages"][package_id]["mask_reason"] = reason

def unmask_overlay_package(overlay_name, package_id):
    """
    Unmask a package in an overlay.

    Args:
        overlay_name: Overlay name
        package_id: Package identifier
    """
    if overlay_name not in OVERLAYS:
        fail("Overlay '{}' not found".format(overlay_name))

    if package_id in OVERLAYS[overlay_name].get("packages", {}):
        OVERLAYS[overlay_name]["packages"][package_id]["masked"] = False

# =============================================================================
# OVERLAY CREATION
# =============================================================================

def generate_overlay_structure_script(overlay_name):
    """
    Generate script to create overlay directory structure.

    Args:
        overlay_name: Overlay name

    Returns:
        Shell script string
    """
    overlay = OVERLAYS[overlay_name]

    return '''#!/bin/sh
# Create overlay structure for '{name}'

mkdir -p "{path}"
mkdir -p "{path}/eclass"
mkdir -p "{path}/metadata"
mkdir -p "{path}/profiles"

# Create layout.conf
cat > "{path}/metadata/layout.conf" << 'EOF'
masters = {masters}
repo-name = {name}
EOF

# Create profiles directory
mkdir -p "{path}/profiles"
echo "{name}" > "{path}/profiles/repo_name"

echo "Overlay '{name}' created at {path}"
'''.format(
        name = overlay_name,
        path = overlay["path"],
        masters = " ".join(overlay.get("masters", ["buckos"])),
    )

# =============================================================================
# DOCUMENTATION
# =============================================================================

"""
## Overlay System Usage

### Registering Overlays

```python
# Register a custom overlay
register_overlay(
    name = "myoverlay",
    path = "/var/db/repos/myoverlay",
    priority = 40,
    masters = ["buckos"],
    sync_type = "git",
    sync_uri = "https://github.com/user/myoverlay.git",
    description = "My custom packages",
)

# Register local-only overlay
register_overlay(
    name = "local",
    path = "/usr/local/portage",
    priority = 100,  # Highest priority
    masters = ["buckos"],
    description = "Local customizations",
)
```

### Resolving Packages

```python
# Resolve package from all overlays
result = resolve_package("core/bash")
# Returns: {
#   "overlay": "local",
#   "path": "/usr/local/portage/core/bash",
#   "target": "/usr/local/portage/core/bash:bash"
# }

# Resolve from specific overlays
result = resolve_package("core/bash", overlays = ["buckos"])
```

### Overlay Configuration

```python
# Generate repos.conf
conf = generate_all_repos_conf()

# Generate sync script
script = generate_sync_script("myoverlay")

# Sync all overlays
script = generate_sync_all_script()
```

### Creating New Overlays

```python
# Register the overlay
register_overlay(
    name = "myoverlay",
    path = "/var/db/repos/myoverlay",
    priority = 40,
)

# Generate directory structure
script = generate_overlay_structure_script("myoverlay")
```

## Overlay Priority

Higher priority overlays override lower priority ones:
- local: 50 (highest, for user customizations)
- testing: 30 (unstable packages)
- buckos: 0 (main repository)

## Overlay Structure

```
/var/db/repos/myoverlay/
├── eclass/           # Eclasses
├── metadata/
│   └── layout.conf   # Overlay configuration
├── profiles/
│   └── repo_name     # Overlay name
└── category/
    └── package/
        └── BUCK      # Package definition
```
"""
