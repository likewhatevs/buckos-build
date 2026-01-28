#!/usr/bin/env python3
"""
Download and install precompiled binary packages.

This script:
1. Downloads binary package from mirror
2. Verifies hashes match
3. Extracts to installation directory

Usage:
    # Install a package
    ./scripts/install-binary.py bash --version 5.3

    # Install with specific config
    ./scripts/install-binary.py bash --version 5.3 --config-hash abc12345

    # Install to custom location
    ./scripts/install-binary.py bash --prefix /opt/buckos

    # List available versions
    ./scripts/install-binary.py bash --list
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tarfile
import urllib.request
from pathlib import Path
from typing import List, Optional


def list_available_packages(package_name: str, mirror_url: str) -> List[str]:
    """List available binary packages for a given name.

    Args:
        package_name: Package name (e.g., "bash")
        mirror_url: Mirror base URL

    Returns:
        List of available package filenames
    """
    print(f"Listing available packages for {package_name}...")

    # Construct index URL
    # Assuming mirror has an index or we can list directory
    index_url = f"{mirror_url}/binaries/index.json"

    try:
        with urllib.request.urlopen(index_url) as response:
            index = json.loads(response.read())
            packages = [
                pkg for pkg in index.get("packages", [])
                if pkg.startswith(f"{package_name}-")
            ]
            return packages
    except:
        print(f"No index found at {index_url}")
        print("Try specifying version and hashes manually")
        return []


def download_package(
    package_name: str,
    version: str,
    config_hash: Optional[str],
    file_hash: Optional[str],
    mirror_url: str,
    output_dir: Path
) -> Path:
    """Download a binary package from mirror.

    Args:
        package_name: Package name
        version: Package version
        config_hash: Config hash (optional, will use latest if not specified)
        file_hash: File hash (optional)
        mirror_url: Mirror base URL
        output_dir: Local directory to save package

    Returns:
        Path to downloaded package
    """
    # Construct filename with new format: package-version-confighash-bin.tar.gz
    if config_hash:
        filename = f"{package_name}-{version}-{config_hash}-bin.tar.gz"
    else:
        # No config hash specified - would need to query index
        # For now, require config hash
        filename = f"{package_name}-{version}-*-bin.tar.gz"

    # Construct URL
    # Packages organized by first letter
    first_letter = package_name[0].lower()
    package_url = f"{mirror_url}/binaries/{first_letter}/{filename}"

    print(f"Downloading from {package_url}...")

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / filename.replace("*", "latest")

    try:
        # Download package
        urllib.request.urlretrieve(package_url, output_path)
        print(f"✓ Downloaded: {output_path}")

        # Also download .sha256 file
        hash_url = package_url + ".sha256"
        hash_path = output_dir / (filename.replace("*", "latest") + ".sha256")
        try:
            urllib.request.urlretrieve(hash_url, hash_path)
            print(f"✓ Downloaded: {hash_path}")
        except:
            print(f"Warning: Could not download .sha256 file from {hash_url}")

        return output_path
    except Exception as e:
        print(f"✗ Failed to download: {e}")
        sys.exit(1)


def verify_package(package_path: Path) -> bool:
    """Verify package integrity using .sha256 file.

    Args:
        package_path: Path to package file

    Returns:
        True if valid
    """
    print(f"Verifying {package_path.name}...")

    # Look for .sha256 file
    hash_file = package_path.parent / f"{package_path.name}.sha256"

    if not hash_file.exists():
        print("Warning: No .sha256 file found, skipping verification")
        return True

    # Read expected hash from .sha256 file
    expected_hash = None
    with open(hash_file, "r") as f:
        first_line = f.readline().strip()
        if first_line:
            # Format: "<hash>  <filename>"
            parts = first_line.split()
            if len(parts) >= 1:
                expected_hash = parts[0]

    if not expected_hash:
        print("Warning: Could not parse .sha256 file")
        return True

    # Calculate actual hash
    sha256 = hashlib.sha256()
    with open(package_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)

    actual_hash = sha256.hexdigest()

    if actual_hash != expected_hash:
        print(f"✗ Hash mismatch!")
        print(f"  Expected: {expected_hash}")
        print(f"  Got:      {actual_hash}")
        return False

    print(f"✓ Package verified (SHA256: {actual_hash[:16]}...)")
    return True


def install_package(package_path: Path, prefix: Path) -> bool:
    """Install a binary package.

    Args:
        package_path: Path to package file
        prefix: Installation prefix (e.g., /usr, /opt/buckos)

    Returns:
        True if successful
    """
    print(f"Installing to {prefix}...")

    prefix.mkdir(parents=True, exist_ok=True)

    try:
        with tarfile.open(package_path, "r:gz") as tar:
            # Extract all files
            tar.extractall(prefix)

        print(f"✓ Installed to {prefix}")
        return True
    except Exception as e:
        print(f"✗ Installation failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Download and install precompiled binary packages"
    )
    parser.add_argument(
        "package",
        help="Package name (e.g., bash, vim)"
    )
    parser.add_argument(
        "--version",
        "-v",
        help="Package version"
    )
    parser.add_argument(
        "--config-hash",
        "-c",
        help="Config hash (8 hex chars)"
    )
    parser.add_argument(
        "--file-hash",
        "-f",
        help="File hash (8 hex chars)"
    )
    parser.add_argument(
        "--mirror-url",
        "-m",
        default="https://mirror.buckos.org",
        help="Mirror base URL (default: https://mirror.buckos.org)"
    )
    parser.add_argument(
        "--prefix",
        "-p",
        type=Path,
        default=Path("/usr"),
        help="Installation prefix (default: /usr)"
    )
    parser.add_argument(
        "--download-only",
        "-d",
        action="store_true",
        help="Download but don't install"
    )
    parser.add_argument(
        "--list",
        "-l",
        action="store_true",
        help="List available versions"
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=Path.home() / ".cache" / "buckos-binaries",
        help="Download cache directory"
    )

    args = parser.parse_args()

    print("BuckOS Binary Installer")
    print("=" * 60)

    if args.list:
        packages = list_available_packages(args.package, args.mirror_url)
        if packages:
            print(f"Available packages for {args.package}:")
            for pkg in packages:
                print(f"  {pkg}")
        else:
            print(f"No packages found for {args.package}")
        return 0

    if not args.version:
        print("Error: --version required")
        return 1

    print(f"Package: {args.package}")
    print(f"Version: {args.version}")
    if args.config_hash:
        print(f"Config hash: {args.config_hash}")
    if args.file_hash:
        print(f"File hash: {args.file_hash}")
    print(f"Mirror: {args.mirror_url}")
    print(f"Prefix: {args.prefix}")
    print("=" * 60)
    print()

    # Download package
    package_path = download_package(
        args.package,
        args.version,
        args.config_hash,
        args.file_hash,
        args.mirror_url,
        args.cache_dir
    )

    # Verify package
    if not verify_package(package_path):
        print("✗ Verification failed")
        return 1

    if args.download_only:
        print(f"Package downloaded to: {package_path}")
        return 0

    # Install package
    if not install_package(package_path, args.prefix):
        return 1

    print()
    print("=" * 60)
    print(f"✓ Successfully installed {args.package} {args.version}")
    print("=" * 60)

    return 0


if __name__ == "__main__":
    sys.exit(main())
