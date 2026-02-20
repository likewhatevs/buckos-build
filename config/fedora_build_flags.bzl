"""
Fedora 42 build flags and compiler options.

This module provides Fedora 42-compatible build flags to ensure packages
built in BuckOS can run on Fedora systems and vice versa.

Based on Fedora's RPM macro definitions:
- https://src.fedoraproject.org/rpms/redhat-rpm-config
- /usr/lib/rpm/redhat/macros

Fedora 42 build flags focus on:
- Security hardening (PIE, RELRO, stack protector, _FORTIFY_SOURCE=3)
- Frame pointers (-fno-omit-frame-pointer for profiling/debugging)
- Optimization for x86_64-v2 microarchitecture level
- Reproducible builds
- LTO (Link Time Optimization)
"""

# =============================================================================
# FEDORA COMPILER FLAGS
# =============================================================================

# Fedora 42 standard optimization flags
FEDORA_CFLAGS_BASE = [
    "-O2",
    "-flto=auto",           # Link-time optimization
    "-ffat-lto-objects",    # Support non-LTO linking
    "-fexceptions",
    "-g",                   # Debug info
    "-grecord-gcc-switches",  # Embed compiler flags
    "-pipe",
    "-Wall",
    "-Werror=format-security",
    "-Wp,-D_FORTIFY_SOURCE=3",  # Buffer overflow protection (level 3 since F42)
    "-Wp,-D_GLIBCXX_ASSERTIONS",
    "-fno-omit-frame-pointer",  # Frame pointers (F42+ requirement for profiling)
]

# x86_64 specific flags (x86-64-v2 baseline)
FEDORA_CFLAGS_X86_64 = [
    "-m64",
    "-mtune=generic",
    "-fasynchronous-unwind-tables",
    "-fstack-clash-protection",
    "-fcf-protection",      # Control flow integrity
]

# Full C flags for x86_64
FEDORA_CFLAGS = FEDORA_CFLAGS_BASE + FEDORA_CFLAGS_X86_64

# C++ uses same flags as C
FEDORA_CXXFLAGS = FEDORA_CFLAGS

# Fortran flags
FEDORA_FFLAGS = FEDORA_CFLAGS_BASE + FEDORA_CFLAGS_X86_64

# =============================================================================
# FEDORA LINKER FLAGS
# =============================================================================

FEDORA_LDFLAGS = [
    "-Wl,-z,relro",         # RELRO (relocation read-only)
    "-Wl,--as-needed",      # Only link needed libraries
    "-Wl,-z,now",           # Full RELRO (immediate binding)
    "-flto=auto",           # LTO at link time
]

# Additional flags for executables (not shared libraries)
FEDORA_LDFLAGS_EXECUTABLE = FEDORA_LDFLAGS + [
    "-pie",                 # Position independent executable
]

# =============================================================================
# ARCHITECTURE-SPECIFIC FLAGS
# =============================================================================

# Architecture flags by target
FEDORA_ARCH_FLAGS = {
    "x86_64": {
        "cflags": FEDORA_CFLAGS_X86_64,
        "march": "x86-64-v2",  # Fedora 42 baseline
    },
    "i686": {
        "cflags": [
            "-m32",
            "-march=i686",
            "-mtune=generic",
            "-fasynchronous-unwind-tables",
            "-fstack-clash-protection",
        ],
        "march": "i686",
    },
    "aarch64": {
        "cflags": [
            "-mbranch-protection=standard",
            "-fasynchronous-unwind-tables",
            "-fstack-clash-protection",
        ],
        "march": "armv8-a",
    },
}

# =============================================================================
# BUILD TYPE VARIATIONS
# =============================================================================

def get_fedora_flags(
    arch = "x86_64",
    build_type = "release",
    fortify_level = 3,
    lto = True,
    hardened = True):
    """Get Fedora build flags for specified configuration.

    Args:
        arch: Target architecture (x86_64, i686, aarch64)
        build_type: Build type (release, debug)
        fortify_level: _FORTIFY_SOURCE level (0, 1, 2, 3)
        lto: Enable Link-Time Optimization
        hardened: Enable hardening flags

    Returns:
        Dict with cflags, cxxflags, ldflags, fflags
    """
    cflags = list(FEDORA_CFLAGS_BASE)
    cxxflags = list(FEDORA_CFLAGS_BASE)
    fflags = list(FEDORA_CFLAGS_BASE)
    ldflags = list(FEDORA_LDFLAGS)

    # Add architecture-specific flags
    if arch in FEDORA_ARCH_FLAGS:
        arch_cflags = FEDORA_ARCH_FLAGS[arch]["cflags"]
        cflags.extend(arch_cflags)
        cxxflags.extend(arch_cflags)
        fflags.extend(arch_cflags)

    # LTO handling
    if not lto:
        cflags = [f for f in cflags if not f.startswith("-flto")]
        cxxflags = [f for f in cxxflags if not f.startswith("-flto")]
        fflags = [f for f in fflags if not f.startswith("-flto")]
        ldflags = [f for f in ldflags if not f.startswith("-flto")]

    # Fortify source level
    if fortify_level > 0:
        fortify_flag = "-Wp,-D_FORTIFY_SOURCE={}".format(fortify_level)
        # Replace existing fortify flags
        cflags = [f for f in cflags if not f.startswith("-Wp,-D_FORTIFY_SOURCE")]
        cxxflags = [f for f in cxxflags if not f.startswith("-Wp,-D_FORTIFY_SOURCE")]
        fflags = [f for f in fflags if not f.startswith("-Wp,-D_FORTIFY_SOURCE")]
        cflags.append(fortify_flag)
        cxxflags.append(fortify_flag)
        fflags.append(fortify_flag)

    # Hardening
    if not hardened:
        # Remove hardening flags
        hardening_flags = ["-fstack-clash-protection", "-fcf-protection",
                          "-Wp,-D_GLIBCXX_ASSERTIONS", "-mbranch-protection=standard"]
        cflags = [f for f in cflags if f not in hardening_flags]
        cxxflags = [f for f in cxxflags if f not in hardening_flags]
        fflags = [f for f in fflags if f not in hardening_flags]
        ldflags = [f for f in ldflags if not f.startswith("-Wl,-z,")]

    # Debug vs Release
    if build_type == "debug":
        # Remove optimization, keep debug symbols
        cflags = [f for f in cflags if not f.startswith("-O")]
        cxxflags = [f for f in cxxflags if not f.startswith("-O")]
        fflags = [f for f in fflags if not f.startswith("-O")]
        cflags.append("-O0")
        cxxflags.append("-O0")
        fflags.append("-O0")

    return {
        "cflags": cflags,
        "cxxflags": cxxflags,
        "ldflags": ldflags,
        "fflags": fflags,
    }

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================

def get_fedora_build_env(arch = "x86_64", build_type = "release"):
    """Get environment variables for Fedora-compatible builds.

    Args:
        arch: Target architecture
        build_type: Build type

    Returns:
        Dict of environment variables
    """
    flags = get_fedora_flags(arch, build_type)

    return {
        "CFLAGS": " ".join(flags["cflags"]),
        "CXXFLAGS": " ".join(flags["cxxflags"]),
        "FFLAGS": " ".join(flags["fflags"]),
        "LDFLAGS": " ".join(flags["ldflags"]),
        "CC": "gcc",
        "CXX": "g++",
        "FC": "gfortran",
        # Fedora-specific environment
        "RPM_OPT_FLAGS": " ".join(flags["cflags"]),
        "RPM_LD_FLAGS": " ".join(flags["ldflags"]),
    }

# =============================================================================
# CONFIGURE ARGUMENT HELPERS
# =============================================================================

def fedora_autotools_env():
    """Get environment variables for autotools builds with Fedora flags."""
    return get_fedora_build_env()

def fedora_cmake_args():
    """Get CMake arguments for Fedora builds."""
    flags = get_fedora_flags()
    return [
        "-DCMAKE_C_FLAGS={}".format(" ".join(flags["cflags"])),
        "-DCMAKE_CXX_FLAGS={}".format(" ".join(flags["cxxflags"])),
        "-DCMAKE_EXE_LINKER_FLAGS={}".format(" ".join(flags["ldflags"])),
        "-DCMAKE_SHARED_LINKER_FLAGS={}".format(" ".join(flags["ldflags"])),
        "-DCMAKE_BUILD_TYPE=Release",
    ]

def fedora_meson_args():
    """Get Meson arguments for Fedora builds."""
    flags = get_fedora_flags()
    # Note: -Dbuildtype is NOT included here because the meson eclass already
    # passes --buildtype via the setup command. Meson errors when buildtype is
    # specified as both -Dbuildtype and --buildtype.
    return [
        "-Dc_args={}".format(" ".join(flags["cflags"])),
        "-Dcpp_args={}".format(" ".join(flags["cxxflags"])),
        "-Dc_link_args={}".format(" ".join(flags["ldflags"])),
        "-Dcpp_link_args={}".format(" ".join(flags["ldflags"])),
    ]

# =============================================================================
# COMPATIBILITY CHECKS
# =============================================================================

def is_fedora_compatible_flags(cflags):
    """Check if compiler flags are compatible with Fedora requirements.

    Args:
        cflags: List of compiler flags

    Returns:
        Dict with compatibility status and missing flags
    """
    required_flags = [
        "-fstack-clash-protection",
        "-fcf-protection",
        "-fno-omit-frame-pointer",
    ]

    recommended_flags = [
        "-D_FORTIFY_SOURCE",
        "-flto",
    ]

    missing_required = []
    missing_recommended = []

    flag_str = " ".join(cflags)

    for flag in required_flags:
        if flag not in flag_str:
            missing_required.append(flag)

    for flag in recommended_flags:
        if flag not in flag_str:
            missing_recommended.append(flag)

    return {
        "compatible": len(missing_required) == 0,
        "missing_required": missing_required,
        "missing_recommended": missing_recommended,
    }
