"""
Filesystem Hierarchy Standard (FHS) mapping utilities.

Provides tools for mapping between BuckOS native filesystem layout
and Fedora's FHS-compliant layout. This is essential for:
- Installing RPM packages in the correct locations
- Making BuckOS packages Fedora-compatible
- Hybrid systems with both native and foreign packages

FHS Reference: https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html

Note: BuckOS uses /usr/lib64 natively on x86_64 (matching Fedora), so
most path translations are no-ops for that architecture. The mapping
functions are retained for documentation and potential 32-bit/multilib use.
"""

# =============================================================================
# FHS DIRECTORY STRUCTURE
# =============================================================================

# Standard FHS directories for Fedora
FHS_DIRECTORIES = {
    "bin": "/usr/bin",
    "sbin": "/usr/sbin",
    "lib": "/usr/lib64",      # 64-bit primary
    "lib32": "/usr/lib",      # 32-bit compat
    "libexec": "/usr/libexec",
    "include": "/usr/include",
    "share": "/usr/share",
    "etc": "/etc",
    "var": "/var",
    "opt": "/opt",
    "srv": "/srv",
    "tmp": "/tmp",
    "run": "/run",
}

# BuckOS native directory structure (customizable)
BUCKOS_DIRECTORIES = {
    "bin": "/usr/bin",
    "sbin": "/usr/sbin",
    "lib": "/usr/lib64",      # 64-bit primary (matches Fedora on x86_64)
    "lib32": "/usr/lib32",
    "libexec": "/usr/libexec",
    "include": "/usr/include",
    "share": "/usr/share",
    "etc": "/etc",
    "var": "/var",
    "opt": "/opt",
    "srv": "/srv",
    "tmp": "/tmp",
    "run": "/run",
}

# Common subdirectories under /usr/share
FHS_SHARE_SUBDIRS = [
    "man",
    "doc",
    "info",
    "locale",
    "icons",
    "applications",
    "mime",
    "fonts",
    "pixmaps",
    "sounds",
    "themes",
]

# =============================================================================
# PATH MAPPING FUNCTIONS
# =============================================================================

def fhs_to_buckos(fhs_path):
    """Convert FHS path to BuckOS native path.

    Args:
        fhs_path: Path in FHS layout (e.g., "/usr/lib64/libfoo.so")

    Returns:
        Path in BuckOS layout. On x86_64 this is a no-op since
        BuckOS uses /usr/lib64 natively.
    """
    # BuckOS uses lib64 on x86_64, matching FHS — no translation needed
    return fhs_path

def buckos_to_fhs(buckos_path, arch = "x86_64"):
    """Convert BuckOS native path to FHS path.

    Args:
        buckos_path: Path in BuckOS layout
        arch: Target architecture (x86_64, i686, etc.)

    Returns:
        Path in FHS layout. On x86_64 this is a no-op since
        BuckOS uses /usr/lib64 natively.
    """
    # BuckOS uses lib64 on x86_64, matching FHS — no translation needed
    return buckos_path

def normalize_path(path, target_layout = "buckos"):
    """Normalize a path to the target filesystem layout.

    Args:
        path: Input path
        target_layout: Target layout ("buckos" or "fhs")

    Returns:
        Normalized path
    """
    if target_layout == "fhs":
        return buckos_to_fhs(path)
    elif target_layout == "buckos":
        return fhs_to_buckos(path)
    else:
        fail("Unknown target layout: {}. Use 'buckos' or 'fhs'".format(target_layout))

# =============================================================================
# BULK PATH MAPPING
# =============================================================================

def map_file_list(files, source_layout, target_layout, arch = "x86_64"):
    """Map a list of file paths between layouts.

    Args:
        files: List of file paths
        source_layout: Source layout ("buckos" or "fhs")
        target_layout: Target layout ("buckos" or "fhs")
        arch: Architecture for lib64 decisions

    Returns:
        Dict mapping source path to target path
    """
    mapping = {}

    for src_file in files:
        if source_layout == "fhs" and target_layout == "buckos":
            mapping[src_file] = fhs_to_buckos(src_file)
        elif source_layout == "buckos" and target_layout == "fhs":
            mapping[src_file] = buckos_to_fhs(src_file, arch)
        else:
            # Same layout, no mapping needed
            mapping[src_file] = src_file

    return mapping

def create_compat_symlinks(installed_files, source_layout, target_layout):
    """Generate symlinks for filesystem layout compatibility.

    When installing packages from one layout in another, create symlinks
    so both paths work (e.g., /usr/lib/libfoo.so -> /usr/lib64/libfoo.so).

    Args:
        installed_files: List of installed file paths in source layout
        source_layout: Layout files were installed in
        target_layout: Layout to create symlinks for

    Returns:
        List of (symlink_path, target_path) tuples
    """
    symlinks = []

    if source_layout == target_layout:
        return symlinks

    for src_file in installed_files:
        if source_layout == "fhs" and target_layout == "buckos":
            # Installed in FHS (/usr/lib64), create BuckOS symlink (/usr/lib)
            buckos_path = fhs_to_buckos(src_file)
            if buckos_path != src_file:
                symlinks.append((buckos_path, src_file))

        elif source_layout == "buckos" and target_layout == "fhs":
            # Installed in BuckOS (/usr/lib), create FHS symlink (/usr/lib64)
            fhs_path = buckos_to_fhs(src_file)
            if fhs_path != src_file:
                symlinks.append((fhs_path, src_file))

    return symlinks

# =============================================================================
# LIBRARY PATH HELPERS
# =============================================================================

def get_lib_dirs(layout = "buckos", arch = "x86_64"):
    """Get library search directories for a layout.

    Args:
        layout: Filesystem layout ("buckos" or "fhs")
        arch: Architecture

    Returns:
        List of library directories in search order
    """
    if layout == "fhs":
        if arch == "x86_64":
            return [
                "/usr/lib64",
                "/lib64",
                "/usr/lib",     # 32-bit compat
                "/lib",
            ]
        else:
            return [
                "/usr/lib",
                "/lib",
            ]
    else:  # buckos
        if arch == "x86_64":
            return [
                "/usr/lib64",
                "/lib64",
                "/usr/lib",
                "/lib",
            ]
        else:
            return [
                "/usr/lib",
                "/lib",
            ]

def get_pkgconfig_dirs(layout = "buckos", arch = "x86_64"):
    """Get pkg-config search directories for a layout.

    Args:
        layout: Filesystem layout
        arch: Architecture

    Returns:
        List of pkg-config directories
    """
    if layout == "fhs" and arch == "x86_64":
        return [
            "/usr/lib64/pkgconfig",
            "/usr/share/pkgconfig",
            "/usr/lib/pkgconfig",
        ]
    elif arch == "x86_64":
        # BuckOS on x86_64 uses lib64, same as Fedora FHS
        return [
            "/usr/lib64/pkgconfig",
            "/usr/share/pkgconfig",
            "/usr/lib/pkgconfig",
        ]
    else:
        return [
            "/usr/lib/pkgconfig",
            "/usr/share/pkgconfig",
        ]

# =============================================================================
# INSTALL PREFIX HELPERS
# =============================================================================

def get_install_prefix(layout = "buckos", package_type = "system"):
    """Get the installation prefix for packages.

    Args:
        layout: Filesystem layout
        package_type: Package type (system, opt, local)

    Returns:
        Installation prefix path
    """
    if package_type == "opt":
        return "/opt"
    elif package_type == "local":
        return "/usr/local"
    else:
        # System packages
        return "/usr"

def get_configure_args_for_layout(layout = "buckos", arch = "x86_64"):
    """Get autotools configure arguments for a filesystem layout.

    Args:
        layout: Filesystem layout
        arch: Architecture

    Returns:
        List of configure arguments
    """
    prefix = get_install_prefix(layout)
    args = [
        "--prefix={}".format(prefix),
        "--sysconfdir=/etc",
        "--localstatedir=/var",
    ]

    if layout == "fhs" and arch == "x86_64":
        args.extend([
            "--libdir=/usr/lib64",
            "--libexecdir=/usr/libexec",
        ])
    else:
        args.extend([
            "--libdir=/usr/lib",
            "--libexecdir=/usr/libexec",
        ])

    return args

def get_cmake_args_for_layout(layout = "buckos", arch = "x86_64"):
    """Get CMake arguments for a filesystem layout.

    Args:
        layout: Filesystem layout
        arch: Architecture

    Returns:
        List of CMake arguments
    """
    prefix = get_install_prefix(layout)
    args = [
        "-DCMAKE_INSTALL_PREFIX={}".format(prefix),
    ]

    if layout == "fhs" and arch == "x86_64":
        args.extend([
            "-DCMAKE_INSTALL_LIBDIR=lib64",
            "-DCMAKE_INSTALL_LIBEXECDIR=libexec",
        ])
    else:
        args.extend([
            "-DCMAKE_INSTALL_LIBDIR=lib",
            "-DCMAKE_INSTALL_LIBEXECDIR=libexec",
        ])

    return args

# =============================================================================
# RPM EXTRACTION HELPERS
# =============================================================================

def extract_rpm_to_layout(rpm_files, target_layout = "buckos", arch = "x86_64"):
    """Process RPM file list for installation in target layout.

    Args:
        rpm_files: List of files from RPM (in FHS layout)
        target_layout: Target filesystem layout
        arch: Architecture

    Returns:
        Dict with:
          - files: Mapped file paths
          - symlinks: Required compatibility symlinks
    """
    # RPMs are always in FHS layout
    mapped_files = map_file_list(rpm_files, "fhs", target_layout, arch)

    # Create symlinks if layouts differ
    symlinks = []
    if target_layout == "buckos":
        symlinks = create_compat_symlinks(rpm_files, "fhs", "buckos")

    return {
        "files": mapped_files,
        "symlinks": symlinks,
    }
