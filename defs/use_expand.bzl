"""
USE_EXPAND system for BuckOs.

This module provides expanded USE flag variables like PYTHON_TARGETS,
RUBY_TARGETS, CPU_FLAGS_X86, etc. These automatically expand into
prefixed USE flags for packages.

Example usage:
    load("//defs:use_expand.bzl", "expand_use", "USE_EXPAND_VARS", "CPU_FLAGS_X86")

    # Expand USE_EXPAND variables into USE flags
    use_flags = expand_use(
        python_targets = ["python3_11", "python3_12"],
        cpu_flags_x86 = ["avx2", "aes"],
    )
    # Returns: ["python_targets_python3_11", "python_targets_python3_12",
    #           "cpu_flags_x86_avx2", "cpu_flags_x86_aes"]
"""

# =============================================================================
# USE_EXPAND VARIABLE DEFINITIONS
# =============================================================================

# Python implementation targets
PYTHON_TARGETS = [
    "python3_10",
    "python3_11",
    "python3_12",
    "python3_13",
    "pypy3",
]

PYTHON_SINGLE_TARGET = PYTHON_TARGETS  # Same options, but only one selected

# Ruby implementation targets
RUBY_TARGETS = [
    "ruby31",
    "ruby32",
    "ruby33",
]

# Lua implementation targets
LUA_TARGETS = [
    "lua5_1",
    "lua5_3",
    "lua5_4",
    "luajit",
]

# PHP targets
PHP_TARGETS = [
    "php8_1",
    "php8_2",
    "php8_3",
]

# Go targets (versions)
GO_TARGETS = [
    "go1_21",
    "go1_22",
    "go1_23",
]

# Rust targets (target triples for cross-compilation)
RUST_TARGETS = [
    "x86_64_unknown_linux_gnu",
    "x86_64_unknown_linux_musl",
    "aarch64_unknown_linux_gnu",
    "aarch64_unknown_linux_musl",
    "armv7_unknown_linux_gnueabihf",
    "i686_unknown_linux_gnu",
    "riscv64gc_unknown_linux_gnu",
]

# Node.js targets
NODE_TARGETS = [
    "node18",
    "node20",
    "node21",
]

# CPU flags for x86/x86_64
CPU_FLAGS_X86 = [
    # Basic
    "mmx",
    "mmxext",
    "3dnow",
    "3dnowext",
    # SSE
    "sse",
    "sse2",
    "sse3",
    "ssse3",
    "sse4_1",
    "sse4_2",
    "sse4a",
    # AVX
    "avx",
    "avx2",
    "avx512f",
    "avx512bw",
    "avx512cd",
    "avx512dq",
    "avx512vl",
    # AES/encryption
    "aes",
    "pclmul",
    # Other
    "f16c",
    "fma",
    "fma4",
    "popcnt",
    "xop",
]

# CPU flags for ARM
CPU_FLAGS_ARM = [
    "neon",
    "thumb",
    "thumb2",
    "vfp",
    "vfpv3",
    "vfpv4",
    "edsp",
]

# CPU flags for ARM64
CPU_FLAGS_ARM64 = [
    "asimd",
    "crc32",
    "crypto",
    "fp",
    "sha2",
    "sha3",
    "sve",
    "sve2",
]

# Video cards (for OpenGL/Vulkan drivers)
VIDEO_CARDS = [
    "amdgpu",
    "i915",
    "i965",
    "intel",
    "nouveau",
    "nvidia",
    "radeon",
    "radeonsi",
    "virgl",
    "vmware",
]

# Input devices
INPUT_DEVICES = [
    "evdev",
    "joystick",
    "keyboard",
    "libinput",
    "mouse",
    "synaptics",
    "wacom",
]

# Kernel modules
KERNEL_MODULES = [
    "sign",
    "compress",
    "strip",
]

# Grub platforms
GRUB_PLATFORMS = [
    "efi-32",
    "efi-64",
    "pc",
    "coreboot",
    "emu",
]

# QMake
QMAKE_TARGETS = [
    "qt5",
    "qt6",
]

# Apache2 modules
APACHE2_MODULES = [
    "access_compat",
    "actions",
    "alias",
    "auth_basic",
    "authn_core",
    "authz_core",
    "autoindex",
    "cgi",
    "dir",
    "env",
    "expires",
    "filter",
    "headers",
    "log_config",
    "mime",
    "negotiation",
    "proxy",
    "proxy_http",
    "rewrite",
    "setenvif",
    "ssl",
    "status",
]

# Nginx modules
NGINX_MODULES_HTTP = [
    "access",
    "auth_basic",
    "autoindex",
    "charset",
    "empty_gif",
    "fastcgi",
    "geo",
    "gzip",
    "limit_conn",
    "limit_req",
    "log",
    "map",
    "memcached",
    "proxy",
    "referer",
    "rewrite",
    "scgi",
    "ssi",
    "upstream_hash",
    "upstream_ip_hash",
    "upstream_keepalive",
    "upstream_least_conn",
    "upstream_zone",
    "userid",
    "uwsgi",
]

# =============================================================================
# USE_EXPAND REGISTRY
# =============================================================================

USE_EXPAND_VARS = {
    "PYTHON_TARGETS": {
        "values": PYTHON_TARGETS,
        "description": "Python implementation targets",
        "multi": True,  # Multiple selections allowed
    },
    "PYTHON_SINGLE_TARGET": {
        "values": PYTHON_SINGLE_TARGET,
        "description": "Single Python implementation target",
        "multi": False,  # Only one selection
    },
    "RUBY_TARGETS": {
        "values": RUBY_TARGETS,
        "description": "Ruby implementation targets",
        "multi": True,
    },
    "LUA_TARGETS": {
        "values": LUA_TARGETS,
        "description": "Lua implementation targets",
        "multi": True,
    },
    "LUA_SINGLE_TARGET": {
        "values": LUA_TARGETS,
        "description": "Single Lua implementation target",
        "multi": False,
    },
    "PHP_TARGETS": {
        "values": PHP_TARGETS,
        "description": "PHP implementation targets",
        "multi": True,
    },
    "GO_TARGETS": {
        "values": GO_TARGETS,
        "description": "Go version targets",
        "multi": True,
    },
    "RUST_TARGETS": {
        "values": RUST_TARGETS,
        "description": "Rust target triples for cross-compilation",
        "multi": True,
    },
    "NODE_TARGETS": {
        "values": NODE_TARGETS,
        "description": "Node.js version targets",
        "multi": True,
    },
    "CPU_FLAGS_X86": {
        "values": CPU_FLAGS_X86,
        "description": "CPU instruction set flags for x86/amd64",
        "multi": True,
    },
    "CPU_FLAGS_ARM": {
        "values": CPU_FLAGS_ARM,
        "description": "CPU flags for ARM",
        "multi": True,
    },
    "CPU_FLAGS_ARM64": {
        "values": CPU_FLAGS_ARM64,
        "description": "CPU flags for ARM64",
        "multi": True,
    },
    "VIDEO_CARDS": {
        "values": VIDEO_CARDS,
        "description": "Video card drivers",
        "multi": True,
    },
    "INPUT_DEVICES": {
        "values": INPUT_DEVICES,
        "description": "Input device drivers",
        "multi": True,
    },
    "GRUB_PLATFORMS": {
        "values": GRUB_PLATFORMS,
        "description": "GRUB bootloader platforms",
        "multi": True,
    },
    "APACHE2_MODULES": {
        "values": APACHE2_MODULES,
        "description": "Apache2 modules",
        "multi": True,
    },
    "NGINX_MODULES_HTTP": {
        "values": NGINX_MODULES_HTTP,
        "description": "Nginx HTTP modules",
        "multi": True,
    },
}

# =============================================================================
# USE_EXPAND FUNCTIONS
# =============================================================================

def expand_use(**kwargs):
    """
    Expand USE_EXPAND variables into prefixed USE flags.

    Args:
        **kwargs: Variable name -> list of values
                  e.g., python_targets=["python3_11", "python3_12"]

    Returns:
        List of expanded USE flag strings

    Example:
        expand_use(
            python_targets = ["python3_11", "python3_12"],
            cpu_flags_x86 = ["avx2", "aes"],
        )
        # Returns: ["python_targets_python3_11", "python_targets_python3_12",
        #           "cpu_flags_x86_avx2", "cpu_flags_x86_aes"]
    """
    expanded = []

    for var_name, values in kwargs.items():
        var_upper = var_name.upper()

        if var_upper not in USE_EXPAND_VARS:
            fail("Unknown USE_EXPAND variable: {}".format(var_upper))

        var_info = USE_EXPAND_VARS[var_upper]

        # Validate values
        for value in values:
            if value not in var_info["values"]:
                fail("Invalid value '{}' for {}. Valid: {}".format(
                    value, var_upper, ", ".join(var_info["values"])))

        # Check multi constraint
        if not var_info["multi"] and len(values) > 1:
            fail("{} only allows single selection".format(var_upper))

        # Expand to prefixed USE flags
        prefix = var_name.lower()
        for value in values:
            expanded.append("{}_{}".format(prefix, value))

    return expanded

def collapse_use(use_flags):
    """
    Collapse prefixed USE flags back into USE_EXPAND variables.

    Args:
        use_flags: List of USE flag strings

    Returns:
        Dictionary of variable name -> list of values

    Example:
        collapse_use(["python_targets_python3_11", "cpu_flags_x86_avx2"])
        # Returns: {"python_targets": ["python3_11"], "cpu_flags_x86": ["avx2"]}
    """
    result = {}

    for flag in use_flags:
        matched = False

        for var_name, var_info in USE_EXPAND_VARS.items():
            prefix = var_name.lower() + "_"
            if flag.startswith(prefix):
                value = flag[len(prefix):]
                if value in var_info["values"]:
                    key = var_name.lower()
                    if key not in result:
                        result[key] = []
                    result[key].append(value)
                    matched = True
                    break

        # If not matched, it's a regular USE flag
        if not matched:
            if "use" not in result:
                result["use"] = []
            result["use"].append(flag)

    return result

def get_use_expand_values(var_name):
    """
    Get valid values for a USE_EXPAND variable.

    Args:
        var_name: Variable name (case-insensitive)

    Returns:
        List of valid values
    """
    var_upper = var_name.upper()
    if var_upper not in USE_EXPAND_VARS:
        fail("Unknown USE_EXPAND variable: {}".format(var_upper))
    return USE_EXPAND_VARS[var_upper]["values"]

def is_use_expand_flag(flag):
    """
    Check if a USE flag is an expanded USE_EXPAND flag.

    Args:
        flag: USE flag string

    Returns:
        Tuple of (is_expanded, var_name, value) or (False, None, None)
    """
    for var_name, var_info in USE_EXPAND_VARS.items():
        prefix = var_name.lower() + "_"
        if flag.startswith(prefix):
            value = flag[len(prefix):]
            if value in var_info["values"]:
                return (True, var_name, value)
    return (False, None, None)

# =============================================================================
# CPU FLAG DETECTION
# =============================================================================

def generate_cpu_flags_detect_script():
    """
    Generate script to detect CPU flags from /proc/cpuinfo.

    Returns:
        Shell script string
    """
    return '''#!/bin/sh
# Detect CPU flags for USE_EXPAND

detect_x86_flags() {
    if [ -f /proc/cpuinfo ]; then
        FLAGS=$(grep -m1 "^flags" /proc/cpuinfo | cut -d: -f2)
    else
        FLAGS=""
    fi

    DETECTED=""

    # Map cpuinfo flags to USE flags
    for flag in $FLAGS; do
        case "$flag" in
            mmx) DETECTED="$DETECTED mmx" ;;
            sse) DETECTED="$DETECTED sse" ;;
            sse2) DETECTED="$DETECTED sse2" ;;
            pni|sse3) DETECTED="$DETECTED sse3" ;;
            ssse3) DETECTED="$DETECTED ssse3" ;;
            sse4_1) DETECTED="$DETECTED sse4_1" ;;
            sse4_2) DETECTED="$DETECTED sse4_2" ;;
            avx) DETECTED="$DETECTED avx" ;;
            avx2) DETECTED="$DETECTED avx2" ;;
            avx512f) DETECTED="$DETECTED avx512f" ;;
            aes) DETECTED="$DETECTED aes" ;;
            pclmulqdq) DETECTED="$DETECTED pclmul" ;;
            fma) DETECTED="$DETECTED fma" ;;
            f16c) DETECTED="$DETECTED f16c" ;;
            popcnt) DETECTED="$DETECTED popcnt" ;;
        esac
    done

    echo $DETECTED
}

ARCH=$(uname -m)

case "$ARCH" in
    x86_64|i686|i386)
        echo "CPU_FLAGS_X86=$(detect_x86_flags)"
        ;;
    aarch64)
        # Detect ARM64 flags
        echo "CPU_FLAGS_ARM64=asimd crc32"
        ;;
    arm*)
        # Detect ARM flags
        echo "CPU_FLAGS_ARM=neon vfp"
        ;;
esac
'''

def generate_video_cards_detect_script():
    """
    Generate script to detect video cards.

    Returns:
        Shell script string
    """
    return '''#!/bin/sh
# Detect video cards for USE_EXPAND

DETECTED=""

# Check for various GPU drivers
if lspci 2>/dev/null | grep -qi nvidia; then
    DETECTED="$DETECTED nvidia"
fi

if lspci 2>/dev/null | grep -qi "amd.*radeon\\|ati.*radeon"; then
    DETECTED="$DETECTED radeonsi amdgpu"
fi

if lspci 2>/dev/null | grep -qi intel; then
    DETECTED="$DETECTED intel i965"
fi

if lspci 2>/dev/null | grep -qi vmware; then
    DETECTED="$DETECTED vmware"
fi

if lspci 2>/dev/null | grep -qi virtio; then
    DETECTED="$DETECTED virgl"
fi

echo "VIDEO_CARDS=$DETECTED"
'''

# =============================================================================
# MAKE.CONF GENERATION
# =============================================================================

def generate_use_expand_make_conf(**kwargs):
    """
    Generate make.conf snippet for USE_EXPAND variables.

    Args:
        **kwargs: Variable name -> list of values

    Returns:
        String in make.conf format
    """
    lines = []

    for var_name, values in kwargs.items():
        var_upper = var_name.upper()
        if var_upper in USE_EXPAND_VARS:
            lines.append('{}="{}"'.format(var_upper, " ".join(values)))

    return "\n".join(lines)

# =============================================================================
# PACKAGE IUSE GENERATION
# =============================================================================

def generate_iuse_expand(var_name, defaults = []):
    """
    Generate IUSE string for a USE_EXPAND variable.

    Args:
        var_name: USE_EXPAND variable name
        defaults: List of default enabled values

    Returns:
        List of IUSE flag strings with + prefix for defaults

    Example:
        generate_iuse_expand("PYTHON_TARGETS", ["python3_11"])
        # Returns: ["+python_targets_python3_11", "python_targets_python3_12", ...]
    """
    var_upper = var_name.upper()
    if var_upper not in USE_EXPAND_VARS:
        fail("Unknown USE_EXPAND variable: {}".format(var_upper))

    var_info = USE_EXPAND_VARS[var_upper]
    prefix = var_name.lower()
    iuse = []

    for value in var_info["values"]:
        flag = "{}_{}".format(prefix, value)
        if value in defaults:
            iuse.append("+{}".format(flag))
        else:
            iuse.append(flag)

    return iuse

def package_use_expand(var_name, enabled_values):
    """
    Generate USE flag list for a package with USE_EXPAND.

    Args:
        var_name: USE_EXPAND variable name
        enabled_values: List of enabled values

    Returns:
        Dictionary with:
        - iuse: IUSE list for the variable
        - use_deps: Dependencies based on enabled values
    """
    var_upper = var_name.upper()
    prefix = var_name.lower()

    iuse = generate_iuse_expand(var_name, enabled_values)
    use_deps = {}

    # Generate dependencies for each enabled value
    for value in enabled_values:
        flag = "{}_{}".format(prefix, value)

        # Add interpreter dependencies
        if var_upper == "PYTHON_TARGETS":
            version = value.replace("python", "").replace("_", ".")
            use_deps[flag] = ["//packages/dev-lang/python:{}".format(version)]
        elif var_upper == "RUBY_TARGETS":
            version = value.replace("ruby", "").replace("_", ".")
            use_deps[flag] = ["//packages/dev-lang/ruby:{}".format(version)]
        elif var_upper == "LUA_TARGETS":
            if "luajit" in value:
                use_deps[flag] = ["//packages/dev-lang/luajit"]
            else:
                version = value.replace("lua", "").replace("_", ".")
                use_deps[flag] = ["//packages/dev-lang/lua:{}".format(version)]

    return {
        "iuse": iuse,
        "use_deps": use_deps,
    }

# =============================================================================
# DOCUMENTATION
# =============================================================================

"""
## USE_EXPAND System Usage

### Expanding Variables

```python
from defs.use_expand import expand_use

# Expand USE_EXPAND variables to USE flags
use_flags = expand_use(
    python_targets = ["python3_11", "python3_12"],
    cpu_flags_x86 = ["avx2", "aes", "sse4_2"],
)
# Result: ["python_targets_python3_11", "python_targets_python3_12",
#          "cpu_flags_x86_avx2", "cpu_flags_x86_aes", "cpu_flags_x86_sse4_2"]
```

### Package Definition

```python
from defs.use_expand import generate_iuse_expand, package_use_expand

# Generate IUSE for Python package
result = package_use_expand("PYTHON_TARGETS", ["python3_11", "python3_12"])

autotools_package(
    name = "my-python-package",
    iuse = result["iuse"],
    use_deps = result["use_deps"],
    ...
)
```

### Detection Scripts

```python
from defs.use_expand import generate_cpu_flags_detect_script

# Generate CPU flag detection script
script = generate_cpu_flags_detect_script()
```

### make.conf Generation

```python
from defs.use_expand import generate_use_expand_make_conf

conf = generate_use_expand_make_conf(
    python_targets = ["python3_11", "python3_12"],
    cpu_flags_x86 = ["avx2", "aes"],
    video_cards = ["amdgpu", "radeonsi"],
)
# Result:
# PYTHON_TARGETS="python3_11 python3_12"
# CPU_FLAGS_X86="avx2 aes"
# VIDEO_CARDS="amdgpu radeonsi"
```

## Available USE_EXPAND Variables

- PYTHON_TARGETS - Python implementation targets
- PYTHON_SINGLE_TARGET - Single Python target
- RUBY_TARGETS - Ruby implementation targets
- LUA_TARGETS - Lua implementation targets
- PHP_TARGETS - PHP implementation targets
- CPU_FLAGS_X86 - x86/amd64 CPU instruction sets
- CPU_FLAGS_ARM - ARM CPU features
- CPU_FLAGS_ARM64 - ARM64 CPU features
- VIDEO_CARDS - Video card drivers
- INPUT_DEVICES - Input device drivers
- GRUB_PLATFORMS - GRUB bootloader platforms
- APACHE2_MODULES - Apache2 modules
- NGINX_MODULES_HTTP - Nginx HTTP modules
"""
