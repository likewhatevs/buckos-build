"""
Maintainer registry and helper functions for BuckOs Linux packages.

This module provides:
- A registry of maintainers with contact information
- Helper functions to query package maintainers
- Helper functions to find packages by maintainer
- Labels for buck2 queries
"""

# =============================================================================
# MAINTAINER REGISTRY
# =============================================================================

# Registry of known maintainers with their contact information
# Format: "username" -> {"name": "Full Name", "email": "email@example.com", "github": "github_username"}
MAINTAINERS = {
    "core-team": {
        "name": "BuckOs Core Team",
        "email": "core@buckos.org",
        "github": "buckos",
        "description": "Core system packages and infrastructure",
    },
    "security-team": {
        "name": "BuckOs Security Team",
        "email": "security@buckos.org",
        "github": "buckos-security",
        "description": "Security-related packages and updates",
    },
    # Add more maintainers as needed
}

# =============================================================================
# PACKAGE MAINTAINER MAPPING
# =============================================================================

# Registry mapping package names to their maintainers
# Format: "package_name" -> ["maintainer1", "maintainer2", ...]
PACKAGE_MAINTAINERS = {
    # Core system packages
    "glibc": ["core-team"],
    "linux": ["core-team"],
    "systemd": ["core-team"],
    "bash": ["core-team"],

    # Add more package mappings as packages are assigned maintainers
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def get_maintainer_info(maintainer_id: str) -> dict:
    """
    Get maintainer information by ID.

    Args:
        maintainer_id: The maintainer's unique identifier

    Returns:
        Dict with maintainer info (name, email, github, description) or empty dict if not found

    Example:
        info = get_maintainer_info("core-team")
        # Returns: {"name": "BuckOs Core Team", "email": "core@buckos.org", ...}
    """
    return MAINTAINERS.get(maintainer_id, {})

def get_maintainer_email(maintainer_id: str) -> str:
    """
    Get maintainer's email address.

    Args:
        maintainer_id: The maintainer's unique identifier

    Returns:
        Email address string or empty string if not found

    Example:
        email = get_maintainer_email("core-team")
        # Returns: "core@buckos.org"
    """
    info = MAINTAINERS.get(maintainer_id, {})
    return info.get("email", "")

def get_maintainer_name(maintainer_id: str) -> str:
    """
    Get maintainer's full name.

    Args:
        maintainer_id: The maintainer's unique identifier

    Returns:
        Full name string or the maintainer_id if not found

    Example:
        name = get_maintainer_name("core-team")
        # Returns: "BuckOs Core Team"
    """
    info = MAINTAINERS.get(maintainer_id, {})
    return info.get("name", maintainer_id)

def get_package_maintainers(package_name: str) -> list[str]:
    """
    Get the list of maintainers for a package.

    Args:
        package_name: The name of the package

    Returns:
        List of maintainer IDs or empty list if no maintainers assigned

    Example:
        maintainers = get_package_maintainers("bash")
        # Returns: ["core-team"]
    """
    return PACKAGE_MAINTAINERS.get(package_name, [])

def get_packages_by_maintainer(maintainer_id: str) -> list[str]:
    """
    Get all packages maintained by a specific maintainer.

    Args:
        maintainer_id: The maintainer's unique identifier

    Returns:
        List of package names maintained by this maintainer

    Example:
        packages = get_packages_by_maintainer("core-team")
        # Returns: ["glibc", "linux", "systemd", "bash"]
    """
    packages = []
    for pkg_name, maintainers in PACKAGE_MAINTAINERS.items():
        if maintainer_id in maintainers:
            packages.append(pkg_name)
    return sorted(packages)

def get_maintainer_contact_string(maintainer_id: str) -> str:
    """
    Get a formatted contact string for a maintainer.

    Args:
        maintainer_id: The maintainer's unique identifier

    Returns:
        Formatted string like "Full Name <email@example.com>"

    Example:
        contact = get_maintainer_contact_string("core-team")
        # Returns: "BuckOs Core Team <core@buckos.org>"
    """
    info = MAINTAINERS.get(maintainer_id, {})
    name = info.get("name", maintainer_id)
    email = info.get("email", "")
    if email:
        return "{} <{}>".format(name, email)
    return name

def format_maintainers_list(maintainer_ids: list[str]) -> str:
    """
    Format a list of maintainer IDs into a human-readable string.

    Args:
        maintainer_ids: List of maintainer IDs

    Returns:
        Comma-separated string of maintainer contacts

    Example:
        formatted = format_maintainers_list(["core-team", "security-team"])
        # Returns: "BuckOs Core Team <core@buckos.org>, BuckOs Security Team <security@buckos.org>"
    """
    contacts = [get_maintainer_contact_string(m) for m in maintainer_ids]
    return ", ".join(contacts)

def is_valid_maintainer(maintainer_id: str) -> bool:
    """
    Check if a maintainer ID is registered in the maintainers registry.

    Args:
        maintainer_id: The maintainer's unique identifier

    Returns:
        True if the maintainer is registered, False otherwise

    Example:
        is_valid_maintainer("core-team")  # Returns: True
        is_valid_maintainer("unknown")    # Returns: False
    """
    return maintainer_id in MAINTAINERS

def validate_maintainers(maintainer_ids: list[str]) -> list[str]:
    """
    Validate a list of maintainer IDs and return any invalid ones.

    Args:
        maintainer_ids: List of maintainer IDs to validate

    Returns:
        List of invalid maintainer IDs (empty if all are valid)

    Example:
        invalid = validate_maintainers(["core-team", "unknown"])
        # Returns: ["unknown"]
    """
    return [m for m in maintainer_ids if m not in MAINTAINERS]

def get_all_maintainers() -> list[str]:
    """
    Get a list of all registered maintainer IDs.

    Returns:
        Sorted list of all maintainer IDs

    Example:
        all_maintainers = get_all_maintainers()
        # Returns: ["core-team", "security-team", ...]
    """
    return sorted(MAINTAINERS.keys())

def get_maintainer_package_count(maintainer_id: str) -> int:
    """
    Get the number of packages maintained by a specific maintainer.

    Args:
        maintainer_id: The maintainer's unique identifier

    Returns:
        Number of packages maintained

    Example:
        count = get_maintainer_package_count("core-team")
        # Returns: 4
    """
    return len(get_packages_by_maintainer(maintainer_id))

def get_orphaned_packages() -> list[str]:
    """
    Get packages that have no assigned maintainers.

    Note: This only checks packages registered in PACKAGE_MAINTAINERS.
    Packages not in the registry are not included.

    Returns:
        List of package names with empty maintainer lists

    Example:
        orphaned = get_orphaned_packages()
        # Returns: ["some-unmaintained-pkg", ...]
    """
    return [pkg for pkg, maintainers in PACKAGE_MAINTAINERS.items() if not maintainers]

# =============================================================================
# LABEL HELPERS FOR BUCK2 QUERIES
# =============================================================================

def maintainer_labels(maintainer_ids: list[str]) -> list[str]:
    """
    Generate labels for maintainers to enable buck2 queries.

    Args:
        maintainer_ids: List of maintainer IDs

    Returns:
        List of labels in format "maintainer:id"

    Example:
        labels = maintainer_labels(["core-team", "security-team"])
        # Returns: ["maintainer:core-team", "maintainer:security-team"]

    Usage in buck2 queries:
        buck2 query 'attrfilter(labels, "maintainer:core-team", //packages/...)'
    """
    return ["maintainer:{}".format(m) for m in maintainer_ids]

def package_status_label(status: str) -> str:
    """
    Generate a status label for a package.

    Args:
        status: Package status (e.g., "active", "deprecated", "needs-maintainer")

    Returns:
        Label string in format "status:value"

    Example:
        label = package_status_label("active")
        # Returns: "status:active"
    """
    return "status:{}".format(status)

# =============================================================================
# REGISTRATION HELPERS
# =============================================================================

def register_maintainer(
        maintainer_id: str,
        name: str,
        email: str,
        github: str = "",
        description: str = "") -> None:
    """
    Register a new maintainer in the registry.

    Note: This modifies the global MAINTAINERS dict. In practice, maintainers
    should be added directly to the MAINTAINERS dict in this file.

    Args:
        maintainer_id: Unique identifier for the maintainer
        name: Full name
        email: Contact email
        github: GitHub username (optional)
        description: Description of maintainer's focus area (optional)

    Example:
        register_maintainer(
            maintainer_id = "network-team",
            name = "Network Team",
            email = "network@buckos.org",
            github = "buckos-network",
            description = "Network stack and related packages",
        )
    """
    MAINTAINERS[maintainer_id] = {
        "name": name,
        "email": email,
        "github": github,
        "description": description,
    }

def assign_package_maintainer(package_name: str, maintainer_ids: list[str]) -> None:
    """
    Assign maintainers to a package.

    Note: This modifies the global PACKAGE_MAINTAINERS dict. In practice,
    package maintainers should be specified in the package's BUCK file.

    Args:
        package_name: Name of the package
        maintainer_ids: List of maintainer IDs to assign

    Example:
        assign_package_maintainer("openssl", ["security-team", "core-team"])
    """
    PACKAGE_MAINTAINERS[package_name] = maintainer_ids

# =============================================================================
# REPORTING HELPERS
# =============================================================================

def generate_maintainer_report() -> str:
    """
    Generate a summary report of all maintainers and their packages.

    Returns:
        Formatted string report

    Example:
        report = generate_maintainer_report()
        print(report)
    """
    lines = ["# Maintainer Report", ""]

    for maintainer_id in get_all_maintainers():
        info = get_maintainer_info(maintainer_id)
        packages = get_packages_by_maintainer(maintainer_id)

        lines.append("## {}".format(info.get("name", maintainer_id)))
        lines.append("- ID: {}".format(maintainer_id))
        lines.append("- Email: {}".format(info.get("email", "N/A")))
        if info.get("github"):
            lines.append("- GitHub: @{}".format(info.get("github")))
        if info.get("description"):
            lines.append("- Focus: {}".format(info.get("description")))
        lines.append("- Packages ({})".format(len(packages)))
        for pkg in packages:
            lines.append("  - {}".format(pkg))
        lines.append("")

    return "\n".join(lines)

def generate_package_maintainer_matrix() -> dict[str, list[str]]:
    """
    Generate a matrix of packages and their maintainers.

    Returns:
        Dict mapping package names to list of maintainer contact strings

    Example:
        matrix = generate_package_maintainer_matrix()
        # Returns: {"bash": ["BuckOs Core Team <core@buckos.org>"], ...}
    """
    matrix = {}
    for pkg_name, maintainer_ids in PACKAGE_MAINTAINERS.items():
        matrix[pkg_name] = [get_maintainer_contact_string(m) for m in maintainer_ids]
    return matrix
