"""
License tracking and validation system for BuckOs packages.

This module provides Gentoo-compatible license management including:
- License definitions with metadata
- License groups (GPL-COMPATIBLE, FREE, OSI-APPROVED, etc.)
- ACCEPT_LICENSE configuration
- License file installation helpers
- License validation and compliance checking

Example usage:
    load("//defs:licenses.bzl", "check_license", "LICENSE_GROUPS", "dolicense")

    # Check if license is acceptable
    if not check_license("GPL-2", ["@FREE"]):
        fail("License GPL-2 not accepted")

    # Install license files
    post_install = dolicense(["COPYING", "LICENSE"])
"""

# =============================================================================
# LICENSE DEFINITIONS
# =============================================================================

# Common open source licenses with metadata
LICENSES = {
    # GPL Family
    "GPL-1": {"name": "GNU General Public License v1", "url": "https://www.gnu.org/licenses/old-licenses/gpl-1.0.html", "free": True, "osi": False},
    "GPL-2": {"name": "GNU General Public License v2", "url": "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html", "free": True, "osi": True},
    "GPL-2+": {"name": "GNU General Public License v2 or later", "url": "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html", "free": True, "osi": True},
    "GPL-3": {"name": "GNU General Public License v3", "url": "https://www.gnu.org/licenses/gpl-3.0.html", "free": True, "osi": True},
    "GPL-3+": {"name": "GNU General Public License v3 or later", "url": "https://www.gnu.org/licenses/gpl-3.0.html", "free": True, "osi": True},

    # LGPL Family
    "LGPL-2": {"name": "GNU Lesser General Public License v2", "url": "https://www.gnu.org/licenses/old-licenses/lgpl-2.0.html", "free": True, "osi": True},
    "LGPL-2+": {"name": "GNU Lesser General Public License v2 or later", "url": "https://www.gnu.org/licenses/old-licenses/lgpl-2.0.html", "free": True, "osi": True},
    "LGPL-2.1": {"name": "GNU Lesser General Public License v2.1", "url": "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html", "free": True, "osi": True},
    "LGPL-2.1+": {"name": "GNU Lesser General Public License v2.1 or later", "url": "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html", "free": True, "osi": True},
    "LGPL-3": {"name": "GNU Lesser General Public License v3", "url": "https://www.gnu.org/licenses/lgpl-3.0.html", "free": True, "osi": True},
    "LGPL-3+": {"name": "GNU Lesser General Public License v3 or later", "url": "https://www.gnu.org/licenses/lgpl-3.0.html", "free": True, "osi": True},

    # AGPL Family
    "AGPL-3": {"name": "GNU Affero General Public License v3", "url": "https://www.gnu.org/licenses/agpl-3.0.html", "free": True, "osi": True},
    "AGPL-3+": {"name": "GNU Affero General Public License v3 or later", "url": "https://www.gnu.org/licenses/agpl-3.0.html", "free": True, "osi": True},

    # BSD Family
    "BSD": {"name": "BSD License (generic)", "url": "https://opensource.org/licenses/BSD-3-Clause", "free": True, "osi": True},
    "BSD-2": {"name": "BSD 2-Clause License", "url": "https://opensource.org/licenses/BSD-2-Clause", "free": True, "osi": True},
    "BSD-3": {"name": "BSD 3-Clause License", "url": "https://opensource.org/licenses/BSD-3-Clause", "free": True, "osi": True},
    "BSD-4": {"name": "BSD 4-Clause License", "url": "https://spdx.org/licenses/BSD-4-Clause.html", "free": True, "osi": False},

    # MIT/X11
    "MIT": {"name": "MIT License", "url": "https://opensource.org/licenses/MIT", "free": True, "osi": True},
    "X11": {"name": "X11 License", "url": "https://spdx.org/licenses/X11.html", "free": True, "osi": False},
    "ISC": {"name": "ISC License", "url": "https://opensource.org/licenses/ISC", "free": True, "osi": True},

    # Apache
    "Apache-1.0": {"name": "Apache License 1.0", "url": "https://www.apache.org/licenses/LICENSE-1.0", "free": True, "osi": False},
    "Apache-1.1": {"name": "Apache License 1.1", "url": "https://www.apache.org/licenses/LICENSE-1.1", "free": True, "osi": True},
    "Apache-2.0": {"name": "Apache License 2.0", "url": "https://www.apache.org/licenses/LICENSE-2.0", "free": True, "osi": True},

    # Mozilla
    "MPL-1.0": {"name": "Mozilla Public License 1.0", "url": "https://www.mozilla.org/en-US/MPL/1.0/", "free": True, "osi": True},
    "MPL-1.1": {"name": "Mozilla Public License 1.1", "url": "https://www.mozilla.org/en-US/MPL/1.1/", "free": True, "osi": True},
    "MPL-2.0": {"name": "Mozilla Public License 2.0", "url": "https://www.mozilla.org/en-US/MPL/2.0/", "free": True, "osi": True},

    # Creative Commons
    "CC0-1.0": {"name": "Creative Commons Zero v1.0 Universal", "url": "https://creativecommons.org/publicdomain/zero/1.0/", "free": True, "osi": False},
    "CC-BY-3.0": {"name": "Creative Commons Attribution 3.0", "url": "https://creativecommons.org/licenses/by/3.0/", "free": True, "osi": False},
    "CC-BY-4.0": {"name": "Creative Commons Attribution 4.0", "url": "https://creativecommons.org/licenses/by/4.0/", "free": True, "osi": False},
    "CC-BY-SA-3.0": {"name": "Creative Commons Attribution-ShareAlike 3.0", "url": "https://creativecommons.org/licenses/by-sa/3.0/", "free": True, "osi": False},
    "CC-BY-SA-4.0": {"name": "Creative Commons Attribution-ShareAlike 4.0", "url": "https://creativecommons.org/licenses/by-sa/4.0/", "free": True, "osi": False},

    # Public Domain
    "public-domain": {"name": "Public Domain", "url": "", "free": True, "osi": False},
    "Unlicense": {"name": "The Unlicense", "url": "https://unlicense.org/", "free": True, "osi": True},

    # Other OSI Approved
    "Artistic": {"name": "Artistic License 1.0", "url": "https://opensource.org/licenses/Artistic-1.0", "free": True, "osi": True},
    "Artistic-2": {"name": "Artistic License 2.0", "url": "https://opensource.org/licenses/Artistic-2.0", "free": True, "osi": True},
    "CDDL": {"name": "Common Development and Distribution License", "url": "https://opensource.org/licenses/CDDL-1.0", "free": True, "osi": True},
    "CPL-1.0": {"name": "Common Public License 1.0", "url": "https://opensource.org/licenses/CPL-1.0", "free": True, "osi": True},
    "EPL-1.0": {"name": "Eclipse Public License 1.0", "url": "https://www.eclipse.org/legal/epl-v10.html", "free": True, "osi": True},
    "EPL-2.0": {"name": "Eclipse Public License 2.0", "url": "https://www.eclipse.org/legal/epl-2.0/", "free": True, "osi": True},
    "EUPL-1.1": {"name": "European Union Public License 1.1", "url": "https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12", "free": True, "osi": True},
    "EUPL-1.2": {"name": "European Union Public License 1.2", "url": "https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12", "free": True, "osi": True},
    "OFL-1.1": {"name": "SIL Open Font License 1.1", "url": "https://scripts.sil.org/OFL", "free": True, "osi": True},
    "WTFPL": {"name": "Do What The F*ck You Want To Public License", "url": "http://www.wtfpl.net/", "free": True, "osi": False},
    "Zlib": {"name": "zlib License", "url": "https://opensource.org/licenses/Zlib", "free": True, "osi": True},
    "libpng": {"name": "libpng License", "url": "http://www.libpng.org/pub/png/src/libpng-LICENSE.txt", "free": True, "osi": False},
    "HPND": {"name": "Historical Permission Notice and Disclaimer", "url": "https://opensource.org/licenses/HPND", "free": True, "osi": True},

    # Copyleft
    "FDL-1.1": {"name": "GNU Free Documentation License 1.1", "url": "https://www.gnu.org/licenses/old-licenses/fdl-1.1.html", "free": True, "osi": False},
    "FDL-1.2": {"name": "GNU Free Documentation License 1.2", "url": "https://www.gnu.org/licenses/old-licenses/fdl-1.2.html", "free": True, "osi": False},
    "FDL-1.3": {"name": "GNU Free Documentation License 1.3", "url": "https://www.gnu.org/licenses/fdl-1.3.html", "free": True, "osi": False},

    # Proprietary/Restrictive
    "EULA": {"name": "End User License Agreement", "url": "", "free": False, "osi": False},
    "all-rights-reserved": {"name": "All Rights Reserved", "url": "", "free": False, "osi": False},
    "as-is": {"name": "As-Is License", "url": "", "free": True, "osi": False},
    "Boost-1.0": {"name": "Boost Software License 1.0", "url": "https://www.boost.org/LICENSE_1_0.txt", "free": True, "osi": True},

    # Special
    "metapackage": {"name": "Metapackage (no license)", "url": "", "free": True, "osi": False},
    "unknown": {"name": "Unknown License", "url": "", "free": False, "osi": False},
}

# =============================================================================
# LICENSE GROUPS
# =============================================================================

LICENSE_GROUPS = {
    # FSF-approved free software licenses
    "@FSF-APPROVED": [
        "GPL-1", "GPL-2", "GPL-2+", "GPL-3", "GPL-3+",
        "LGPL-2", "LGPL-2+", "LGPL-2.1", "LGPL-2.1+", "LGPL-3", "LGPL-3+",
        "AGPL-3", "AGPL-3+",
        "Apache-2.0", "Artistic-2", "BSD", "BSD-2", "BSD-3",
        "CC0-1.0", "ISC", "MIT", "MPL-2.0", "public-domain", "Unlicense", "Zlib",
    ],

    # OSI-approved licenses
    "@OSI-APPROVED": [
        license for license, meta in LICENSES.items() if meta.get("osi", False)
    ],

    # Free software licenses (non-copyleft)
    "@FREE": [
        license for license, meta in LICENSES.items() if meta.get("free", False)
    ],

    # GPL-compatible licenses
    "@GPL-COMPATIBLE": [
        "GPL-1", "GPL-2", "GPL-2+", "GPL-3", "GPL-3+",
        "LGPL-2", "LGPL-2+", "LGPL-2.1", "LGPL-2.1+", "LGPL-3", "LGPL-3+",
        "BSD", "BSD-2", "BSD-3", "MIT", "X11", "ISC",
        "public-domain", "Unlicense", "CC0-1.0", "Zlib", "libpng",
    ],

    # Copyleft licenses
    "@COPYLEFT": [
        "GPL-1", "GPL-2", "GPL-2+", "GPL-3", "GPL-3+",
        "LGPL-2", "LGPL-2+", "LGPL-2.1", "LGPL-2.1+", "LGPL-3", "LGPL-3+",
        "AGPL-3", "AGPL-3+", "MPL-1.0", "MPL-1.1", "MPL-2.0",
        "EPL-1.0", "EPL-2.0", "CDDL", "EUPL-1.1", "EUPL-1.2",
    ],

    # Permissive licenses
    "@PERMISSIVE": [
        "MIT", "BSD", "BSD-2", "BSD-3", "ISC", "X11",
        "Apache-1.0", "Apache-1.1", "Apache-2.0",
        "Zlib", "libpng", "Boost-1.0", "Unlicense", "WTFPL",
    ],

    # Binary redistribution allowed
    "@BINARY-REDISTRIBUTABLE": [
        license for license, meta in LICENSES.items()
        if meta.get("free", False) or license in ["EULA"]
    ],

    # Documentation licenses
    "@DOCS": [
        "FDL-1.1", "FDL-1.2", "FDL-1.3",
        "CC-BY-3.0", "CC-BY-4.0", "CC-BY-SA-3.0", "CC-BY-SA-4.0",
        "public-domain", "CC0-1.0",
    ],

    # Font licenses
    "@FONTS": [
        "OFL-1.1", "Apache-2.0", "GPL-2", "GPL-3",
        "MIT", "public-domain", "CC0-1.0",
    ],

    # Firmware licenses
    "@FIRMWARE": [
        "linux-firmware", "all-rights-reserved", "unknown",
        "BSD", "GPL-2", "MIT",
    ],

    # Everything (for testing/development)
    "@ALL": list(LICENSES.keys()),
}

# =============================================================================
# LICENSE VALIDATION FUNCTIONS
# =============================================================================

def expand_license_group(group_or_license):
    """
    Expand a license group into individual licenses.

    Args:
        group_or_license: Either a group name (@FREE) or individual license

    Returns:
        List of individual license names
    """
    if group_or_license.startswith("@"):
        if group_or_license not in LICENSE_GROUPS:
            fail("Unknown license group: {}".format(group_or_license))
        return LICENSE_GROUPS[group_or_license]
    return [group_or_license]

def check_license(license, accept_license):
    """
    Check if a license is accepted by the ACCEPT_LICENSE configuration.

    Args:
        license: The license to check (e.g., "GPL-2", "MIT")
        accept_license: List of accepted licenses/groups (e.g., ["@FREE", "linux-firmware"])

    Returns:
        True if license is accepted, False otherwise

    Example:
        if not check_license("GPL-2", ["@FREE"]):
            fail("License not accepted")
    """
    # Handle dual/multiple licensing (license can be "GPL-2 MIT")
    if " " in license:
        # For dual licensing, any one license being accepted is sufficient
        for lic in license.split(" "):
            if check_license(lic, accept_license):
                return True
        return False

    # Expand all accepted licenses
    accepted = []
    for item in accept_license:
        if item.startswith("-"):
            # Negative match - explicitly exclude
            excluded = expand_license_group(item[1:])
            accepted = [l for l in accepted if l not in excluded]
        elif item == "*":
            # Accept all
            return True
        else:
            accepted.extend(expand_license_group(item))

    return license in accepted

def validate_license(license):
    """
    Validate that a license string is known.

    Args:
        license: License string to validate

    Returns:
        True if all licenses in the string are known

    Raises:
        fail() if any license is unknown
    """
    for lic in license.split(" "):
        if lic not in LICENSES and not lic.startswith("||"):
            print("Warning: Unknown license: {}".format(lic))
            return False
    return True

def get_license_info(license):
    """
    Get metadata for a license.

    Args:
        license: License identifier

    Returns:
        Dictionary with license metadata or None if unknown
    """
    return LICENSES.get(license, None)

def is_free_license(license):
    """
    Check if a license is considered free software.

    Args:
        license: License identifier

    Returns:
        True if the license is free, False otherwise
    """
    info = get_license_info(license)
    if info:
        return info.get("free", False)
    return False

def is_osi_approved(license):
    """
    Check if a license is OSI approved.

    Args:
        license: License identifier

    Returns:
        True if OSI approved, False otherwise
    """
    info = get_license_info(license)
    if info:
        return info.get("osi", False)
    return False

# =============================================================================
# LICENSE INSTALLATION HELPERS
# =============================================================================

def dolicense(files):
    """
    Install license files to /usr/share/licenses/<package>/.

    Args:
        files: List of license files to install

    Returns:
        Shell script string for installation

    Example:
        post_install = dolicense(["COPYING", "LICENSE", "AUTHORS"])
    """
    cmds = ['mkdir -p "$DESTDIR/usr/share/licenses/${PN:-$PACKAGE_NAME}"']
    for f in files:
        cmds.append('install -m 0644 "{}" "$DESTDIR/usr/share/licenses/${{PN:-$PACKAGE_NAME}}/"'.format(f))
    return "\n".join(cmds)

def newlicense(src, dst):
    """
    Install license file with a new name.

    Args:
        src: Source file path
        dst: Destination filename

    Returns:
        Shell script string for installation
    """
    return '''mkdir -p "$DESTDIR/usr/share/licenses/${{PN:-$PACKAGE_NAME}}"
install -m 0644 "{}" "$DESTDIR/usr/share/licenses/${{PN:-$PACKAGE_NAME}}/{}"'''.format(src, dst)

# =============================================================================
# ACCEPT_LICENSE CONFIGURATION
# =============================================================================

# Default ACCEPT_LICENSE - only free software
DEFAULT_ACCEPT_LICENSE = ["@FREE"]

# Typical server configuration - free plus common firmware
SERVER_ACCEPT_LICENSE = ["@FREE", "@FIRMWARE"]

# Desktop configuration - more permissive
DESKTOP_ACCEPT_LICENSE = ["@FREE", "@FIRMWARE", "@BINARY-REDISTRIBUTABLE"]

# Development configuration - everything except unknown
DEVELOPER_ACCEPT_LICENSE = ["*", "-unknown"]

def create_accept_license_config(profile = "default"):
    """
    Get ACCEPT_LICENSE configuration for a profile.

    Args:
        profile: Profile name (default, server, desktop, developer)

    Returns:
        List of accepted licenses/groups
    """
    configs = {
        "default": DEFAULT_ACCEPT_LICENSE,
        "server": SERVER_ACCEPT_LICENSE,
        "desktop": DESKTOP_ACCEPT_LICENSE,
        "developer": DEVELOPER_ACCEPT_LICENSE,
    }
    return configs.get(profile, DEFAULT_ACCEPT_LICENSE)

# =============================================================================
# LICENSE EXPRESSION PARSING
# =============================================================================

def parse_license_expression(expr):
    """
    Parse a license expression like "GPL-2 || MIT || Apache-2.0".

    Args:
        expr: License expression string

    Returns:
        Dictionary with:
        - type: "single", "or", "and"
        - licenses: List of license identifiers

    Example:
        parse_license_expression("GPL-2 || MIT")
        # Returns: {"type": "or", "licenses": ["GPL-2", "MIT"]}
    """
    if " || " in expr:
        licenses = [l.strip() for l in expr.split(" || ")]
        return {"type": "or", "licenses": licenses}
    elif " " in expr:
        # Multiple licenses all apply (AND)
        licenses = [l.strip() for l in expr.split(" ")]
        return {"type": "and", "licenses": licenses}
    else:
        return {"type": "single", "licenses": [expr]}

def check_license_expression(expr, accept_license):
    """
    Check if a license expression is satisfied.

    Args:
        expr: License expression (e.g., "GPL-2 || MIT")
        accept_license: List of accepted licenses/groups

    Returns:
        True if expression is satisfied

    For OR expressions: any license accepted = satisfied
    For AND expressions: all licenses must be accepted
    """
    parsed = parse_license_expression(expr)

    if parsed["type"] == "or":
        # Any one license being accepted is sufficient
        for lic in parsed["licenses"]:
            if check_license(lic, accept_license):
                return True
        return False
    else:
        # All licenses must be accepted
        for lic in parsed["licenses"]:
            if not check_license(lic, accept_license):
                return False
        return True

# =============================================================================
# LICENSE REPORTING
# =============================================================================

def generate_license_report(packages):
    """
    Generate a license report for a list of packages.

    Args:
        packages: List of dictionaries with 'name' and 'license' keys

    Returns:
        Dictionary with:
        - by_license: Packages grouped by license
        - free_count: Number of free packages
        - non_free_count: Number of non-free packages
        - unknown_count: Number of packages with unknown licenses
    """
    by_license = {}
    free_count = 0
    non_free_count = 0
    unknown_count = 0

    for pkg in packages:
        license = pkg.get("license", "unknown")
        name = pkg.get("name", "unknown")

        if license not in by_license:
            by_license[license] = []
        by_license[license].append(name)

        if license in LICENSES:
            if LICENSES[license].get("free", False):
                free_count += 1
            else:
                non_free_count += 1
        else:
            unknown_count += 1

    return {
        "by_license": by_license,
        "free_count": free_count,
        "non_free_count": non_free_count,
        "unknown_count": unknown_count,
    }

# =============================================================================
# DOCUMENTATION
# =============================================================================

"""
## License System Usage

### Package Definitions

Specify licenses in package definitions:

```python
ebuild_package(
    name = "my-package",
    version = "1.0.0",
    license = "GPL-2",  # Single license
    # or
    license = "GPL-2 MIT",  # Dual licensed (AND)
    # or
    license = "GPL-2 || MIT",  # Choice of licenses (OR)
)
```

### License Validation

Check if a license is acceptable:

```python
load("//defs:licenses.bzl", "check_license", "check_license_expression")

# Simple check
if not check_license("GPL-2", ["@FREE"]):
    fail("License not accepted")

# Expression check
if not check_license_expression("GPL-2 || MIT", ["@PERMISSIVE"]):
    fail("No acceptable license option")
```

### Installing License Files

```python
load("//defs:licenses.bzl", "dolicense")

ebuild_package(
    name = "my-package",
    post_install = dolicense(["COPYING", "LICENSE"]),
)
```

### License Groups

- @FREE: All free software licenses
- @OSI-APPROVED: OSI-approved licenses
- @GPL-COMPATIBLE: GPL-compatible licenses
- @COPYLEFT: Copyleft licenses
- @PERMISSIVE: Permissive licenses
- @BINARY-REDISTRIBUTABLE: Binary redistribution allowed
- @DOCS: Documentation licenses
- @FONTS: Font licenses
- @ALL: All known licenses

### Configuration

Set ACCEPT_LICENSE in your build configuration:

```python
load("//defs:licenses.bzl", "create_accept_license_config")

ACCEPT_LICENSE = create_accept_license_config("server")
# Returns: ["@FREE", "@FIRMWARE"]
```
"""
