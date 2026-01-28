"""
Configuration protection system for BuckOs.

This module provides protection for user-modified configuration files during
package upgrades, similar to Gentoo's CONFIG_PROTECT system. It:
- Protects files in designated directories from overwriting
- Generates ._cfg0000_ numbered merge files
- Provides tools for reviewing and merging config changes
- Supports mask patterns for exceptions

Example usage:
    load("//defs:config_protect.bzl", "CONFIG_PROTECT", "is_protected", "generate_merge_file")

    # Check if path is protected
    if is_protected("/etc/ssh/sshd_config"):
        new_path = generate_merge_file("/etc/ssh/sshd_config")

    # List pending config updates
    pending = list_pending_configs()
"""

# =============================================================================
# CONFIG_PROTECT DEFINITIONS
# =============================================================================

# Default protected directories
CONFIG_PROTECT = [
    "/etc",
]

# Exceptions to protection (unprotected even within CONFIG_PROTECT)
CONFIG_PROTECT_MASK = [
    "/etc/env.d",
    "/etc/gconf",
    "/etc/sandbox.d",
    "/etc/terminfo",
    "/etc/texmf/ls-R",
    "/etc/texmf/language.dat.d",
    "/etc/texmf/language.def.d",
    "/etc/texmf/updmap.d",
    "/etc/texmf/web2c",
]

# =============================================================================
# PROTECTION CHECKING
# =============================================================================

def is_protected(path, config_protect = None, config_protect_mask = None):
    """
    Check if a file path is protected from overwriting.

    Args:
        path: Absolute file path to check
        config_protect: List of protected directories (defaults to CONFIG_PROTECT)
        config_protect_mask: List of exceptions (defaults to CONFIG_PROTECT_MASK)

    Returns:
        True if the path is protected, False otherwise
    """
    if config_protect == None:
        config_protect = CONFIG_PROTECT
    if config_protect_mask == None:
        config_protect_mask = CONFIG_PROTECT_MASK

    # Check if path is under any protected directory
    protected = False
    for protect_path in config_protect:
        if path.startswith(protect_path.rstrip("/") + "/") or path == protect_path:
            protected = True
            break

    if not protected:
        return False

    # Check if path is masked (exception)
    for mask_path in config_protect_mask:
        if path.startswith(mask_path.rstrip("/") + "/") or path == mask_path:
            return False

    return True

def add_config_protect(path):
    """
    Add a directory to CONFIG_PROTECT.

    Args:
        path: Directory path to protect
    """
    if path not in CONFIG_PROTECT:
        CONFIG_PROTECT.append(path)

def add_config_protect_mask(path):
    """
    Add a directory to CONFIG_PROTECT_MASK (exception).

    Args:
        path: Directory path to exclude from protection
    """
    if path not in CONFIG_PROTECT_MASK:
        CONFIG_PROTECT_MASK.append(path)

# =============================================================================
# MERGE FILE GENERATION
# =============================================================================

def generate_merge_filename(path, counter = 0):
    """
    Generate a merge filename for a protected file.

    Format: path._cfg####_filename where #### is zero-padded counter

    Args:
        path: Original file path
        counter: Counter value (0-9999)

    Returns:
        Merge filename string
    """
    import os
    dirname = "/".join(path.split("/")[:-1])
    basename = path.split("/")[-1]
    return "{}/._cfg{:04d}_{}".format(dirname, counter, basename)

def generate_merge_script(original_path, new_content):
    """
    Generate shell script to handle protected file merge.

    Args:
        original_path: Path to protected file
        new_content: New file content

    Returns:
        Shell script string
    """
    return '''#!/bin/sh
# Handle protected file: {path}

ORIG="{path}"
NEW_CONTENT=$(cat <<'CONFIG_CONTENT_EOF'
{content}
CONFIG_CONTENT_EOF
)

if [ -f "$ORIG" ]; then
    # File exists, create merge file
    COUNTER=0
    while [ $COUNTER -lt 10000 ]; do
        MERGE=$(printf "{dir}/._cfg%04d_{base}" $COUNTER)
        if [ ! -f "$MERGE" ]; then
            echo "$NEW_CONTENT" > "$MERGE"
            echo "Created merge file: $MERGE"
            exit 0
        fi
        COUNTER=$((COUNTER + 1))
    done
    echo "Error: Too many merge files for $ORIG"
    exit 1
else
    # File doesn't exist, install directly
    mkdir -p "$(dirname "$ORIG")"
    echo "$NEW_CONTENT" > "$ORIG"
    echo "Installed: $ORIG"
fi
'''.format(
        path = original_path,
        dir = "/".join(original_path.split("/")[:-1]),
        base = original_path.split("/")[-1],
        content = new_content
    )

# =============================================================================
# CONFIG UPDATE MANAGEMENT
# =============================================================================

def list_pending_configs_script():
    """
    Generate script to list all pending config updates.

    Returns:
        Shell script string
    """
    return '''#!/bin/sh
# List pending configuration updates

echo "Pending configuration updates:"
echo "=============================="

for protect_dir in /etc; do
    find "$protect_dir" -name "._cfg????_*" -type f 2>/dev/null | while read cfg_file; do
        orig_file=$(echo "$cfg_file" | sed 's/\\._cfg[0-9]*_//')
        echo ""
        echo "File: $orig_file"
        echo "  Update: $cfg_file"

        if [ -f "$orig_file" ]; then
            if diff -q "$orig_file" "$cfg_file" >/dev/null 2>&1; then
                echo "  Status: identical (can be auto-merged)"
            else
                echo "  Status: differs (needs review)"
            fi
        else
            echo "  Status: new file"
        fi
    done
done
'''

def generate_dispatch_conf_script():
    """
    Generate script similar to dispatch-conf for merging configs.

    Returns:
        Shell script string
    """
    return '''#!/bin/sh
# Dispatch configuration updates (similar to dispatch-conf)

find_configs() {
    for protect_dir in /etc; do
        find "$protect_dir" -name "._cfg????_*" -type f 2>/dev/null
    done
}

merge_config() {
    cfg_file="$1"
    orig_file=$(echo "$cfg_file" | sed 's/\\._cfg[0-9]*_//')

    echo ""
    echo "========================================"
    echo "File: $orig_file"
    echo "========================================"

    if [ ! -f "$orig_file" ]; then
        echo "New file, installing..."
        mv "$cfg_file" "$orig_file"
        return
    fi

    if diff -q "$orig_file" "$cfg_file" >/dev/null 2>&1; then
        echo "Files are identical, removing update..."
        rm "$cfg_file"
        return
    fi

    echo ""
    diff -u "$orig_file" "$cfg_file" | head -50
    echo ""
    echo "[u]se new, [k]eep current, [m]erge, [d]iff, [q]uit?"
    read -r choice

    case "$choice" in
        u)
            mv "$cfg_file" "$orig_file"
            echo "Updated to new version"
            ;;
        k)
            rm "$cfg_file"
            echo "Kept current version"
            ;;
        m)
            # Use vimdiff or similar
            if command -v vimdiff >/dev/null 2>&1; then
                vimdiff "$orig_file" "$cfg_file"
            else
                echo "No merge tool available"
                return
            fi
            echo "Remove update file? [y/n]"
            read -r remove
            [ "$remove" = "y" ] && rm "$cfg_file"
            ;;
        d)
            diff -u "$orig_file" "$cfg_file" | less
            merge_config "$cfg_file"
            ;;
        q)
            exit 0
            ;;
    esac
}

# Main
configs=$(find_configs)

if [ -z "$configs" ]; then
    echo "No configuration updates pending."
    exit 0
fi

echo "Found $(echo "$configs" | wc -l) configuration update(s)"

echo "$configs" | while read cfg_file; do
    merge_config "$cfg_file"
done

echo ""
echo "Configuration update complete."
'''

def generate_etc_update_script():
    """
    Generate script similar to etc-update for auto-merging.

    Returns:
        Shell script string
    """
    return '''#!/bin/sh
# Auto-merge identical configuration updates (similar to etc-update)

AUTO_MERGE=0
REVIEWED=0
SKIPPED=0

for protect_dir in /etc; do
    find "$protect_dir" -name "._cfg????_*" -type f 2>/dev/null | while read cfg_file; do
        orig_file=$(echo "$cfg_file" | sed 's/\\._cfg[0-9]*_//')

        if [ ! -f "$orig_file" ]; then
            # New file, install directly
            mv "$cfg_file" "$orig_file"
            AUTO_MERGE=$((AUTO_MERGE + 1))
            echo "Installed new: $orig_file"
        elif diff -q "$orig_file" "$cfg_file" >/dev/null 2>&1; then
            # Identical, remove update
            rm "$cfg_file"
            AUTO_MERGE=$((AUTO_MERGE + 1))
            echo "Auto-merged: $orig_file (identical)"
        else
            # Different, skip for manual review
            SKIPPED=$((SKIPPED + 1))
            echo "Needs review: $orig_file"
        fi
    done
done

echo ""
echo "Auto-merged: $AUTO_MERGE"
echo "Needs review: $SKIPPED"

if [ $SKIPPED -gt 0 ]; then
    echo ""
    echo "Run dispatch-conf to review remaining updates."
fi
'''

# =============================================================================
# INSTALL HELPERS
# =============================================================================

def config_install(src, dst, config_protect = None, config_protect_mask = None):
    """
    Generate script to install a config file with protection.

    Args:
        src: Source file path
        dst: Destination file path
        config_protect: Protected directories
        config_protect_mask: Protection exceptions

    Returns:
        Shell script string
    """
    if is_protected(dst, config_protect, config_protect_mask):
        return '''
# Protected config file: {dst}
if [ -f "{dst}" ]; then
    # Find next available merge filename
    COUNTER=0
    while [ $COUNTER -lt 10000 ]; do
        MERGE=$(printf "{dir}/._cfg%04d_{base}" $COUNTER)
        if [ ! -f "$MERGE" ]; then
            install -m 0644 "{src}" "$MERGE"
            echo "Protected config update: $MERGE"
            break
        fi
        COUNTER=$((COUNTER + 1))
    done
else
    install -m 0644 "{src}" "{dst}"
fi
'''.format(
            src = src,
            dst = dst,
            dir = "/".join(dst.split("/")[:-1]),
            base = dst.split("/")[-1]
        )
    else:
        return 'install -m 0644 "{}" "{}"'.format(src, dst)

def doconf(src, dst = None):
    """
    Install configuration file with protection.

    Similar to Gentoo's doconfd but with automatic protection handling.

    Args:
        src: Source file path
        dst: Destination path (defaults to /etc/<basename>)

    Returns:
        Shell script string
    """
    if dst == None:
        dst = "/etc/{}".format(src.split("/")[-1])

    return config_install(src, dst)

# =============================================================================
# CONFIGURATION
# =============================================================================

def generate_config_protect_env():
    """
    Generate environment script for CONFIG_PROTECT settings.

    Returns:
        Shell script string
    """
    return '''# BuckOs CONFIG_PROTECT settings
export CONFIG_PROTECT="{protect}"
export CONFIG_PROTECT_MASK="{mask}"
'''.format(
        protect = " ".join(CONFIG_PROTECT),
        mask = " ".join(CONFIG_PROTECT_MASK)
    )

def parse_config_protect_string(protect_string):
    """
    Parse CONFIG_PROTECT string into list.

    Args:
        protect_string: Space-separated paths

    Returns:
        List of paths
    """
    return [p.strip() for p in protect_string.split() if p.strip()]

# =============================================================================
# PACKAGE INTEGRATION
# =============================================================================

def protected_install_phase(files_mapping, config_protect = None, config_protect_mask = None):
    """
    Generate install phase script with config protection.

    Args:
        files_mapping: Dictionary of src -> dst path mappings
        config_protect: Protected directories
        config_protect_mask: Protection exceptions

    Returns:
        Shell script string
    """
    script_parts = []

    for src, dst in files_mapping.items():
        script_parts.append(config_install(src, dst, config_protect, config_protect_mask))

    return "\n".join(script_parts)

# =============================================================================
# DOCUMENTATION
# =============================================================================

"""
## Config Protection Usage

### Basic Usage

```python
from defs.config_protect import is_protected, config_install

# Check if a file is protected
if is_protected("/etc/ssh/sshd_config"):
    print("File is protected")

# Install config file with protection
script = config_install("sshd_config", "/etc/ssh/sshd_config")
```

### Custom Protection

```python
from defs.config_protect import add_config_protect, add_config_protect_mask

# Add custom protected directory
add_config_protect("/usr/local/etc")

# Exclude specific paths
add_config_protect_mask("/etc/machine-id")
```

### Managing Updates

```python
from defs.config_protect import (
    list_pending_configs_script,
    generate_dispatch_conf_script,
    generate_etc_update_script,
)

# List pending updates
script = list_pending_configs_script()

# Interactive merge tool
script = generate_dispatch_conf_script()

# Auto-merge identical files
script = generate_etc_update_script()
```

### Package Integration

```python
from defs.config_protect import protected_install_phase, doconf

# Install multiple config files
files = {
    "nginx.conf": "/etc/nginx/nginx.conf",
    "default.conf": "/etc/nginx/conf.d/default.conf",
}
script = protected_install_phase(files)

# Or use doconf helper
script = doconf("ssh_config", "/etc/ssh/ssh_config")
```

## Default Protection

Protected directories (CONFIG_PROTECT):
- /etc

Exceptions (CONFIG_PROTECT_MASK):
- /etc/env.d
- /etc/gconf
- /etc/sandbox.d
- /etc/terminfo
- /etc/texmf/*

## Merge File Format

When a protected file would be overwritten, a merge file is created:
```
/etc/ssh/._cfg0000_sshd_config
/etc/ssh/._cfg0001_sshd_config
...
```

Use `dispatch-conf` or `etc-update` to review and merge.
"""
