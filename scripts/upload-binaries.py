#!/usr/bin/env python3
"""
Upload precompiled binary packages to mirror server.

This script:
1. Scans directory for binary packages
2. Organizes by package name (first letter)
3. Uploads to mirror via SCP/rsync
4. Generates index.json for easy discovery

Usage:
    # Upload all packages in directory
    ./scripts/upload-binaries.py --source ./binaries --mirror user@mirror.buckos.org:/var/www/buckos-mirror

    # Upload to local mirror
    ./scripts/upload-binaries.py --source ./binaries --mirror /var/www/buckos-mirror

    # Upload with rsync (faster for updates)
    ./scripts/upload-binaries.py --source ./binaries --mirror user@mirror.buckos.org:/var/www/buckos-mirror --use-rsync

    # Generate index only (no upload)
    ./scripts/upload-binaries.py --source ./binaries --generate-index-only
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List


def find_binary_packages(source_dir: Path) -> List[Path]:
    """Find all binary packages in directory.

    Args:
        source_dir: Directory to scan

    Returns:
        List of package file paths
    """
    packages = []

    for root, dirs, files in os.walk(source_dir):
        for file in files:
            # New format: package-version-bin.tar.gz
            if file.endswith("-bin.tar.gz"):
                packages.append(Path(root) / file)

    return sorted(packages)


def parse_package_info(package_path: Path) -> Dict:
    """Parse package information from filename and hash file.

    Args:
        package_path: Path to package file

    Returns:
        Dict with package metadata
    """
    # New format: package-version-confighash-bin.tar.gz
    filename = package_path.name
    if not filename.endswith("-bin.tar.gz"):
        return None

    # Remove -bin.tar.gz suffix
    name_version_hash = filename.replace("-bin.tar.gz", "")
    parts = name_version_hash.rsplit("-", 2)  # Split from right: name, version, config_hash

    if len(parts) < 3:
        return None

    package_name = parts[0]
    version = parts[1]
    config_hash = parts[2]

    # Read hash file for content hash
    hash_file = package_path.parent / f"{filename}.sha256"
    content_hash = "unknown"

    if hash_file.exists():
        with open(hash_file, "r") as f:
            for line in f:
                if line.startswith("# Content Hash:"):
                    content_hash = line.split(":", 1)[1].strip()
                    break

    return {
        "name": package_name,
        "version": version,
        "config_hash": config_hash,  # From filename
        "content_hash": content_hash,
        "filename": package_path.name,
        "size": package_path.stat().st_size,
    }


def organize_packages(packages: List[Path], staging_dir: Path) -> Dict[str, List[Path]]:
    """Organize packages by first letter into staging directory.

    Args:
        packages: List of package paths
        staging_dir: Staging directory for organization

    Returns:
        Dict mapping directory name to list of packages
    """
    print("Organizing packages...")

    organized = {}
    staging_dir.mkdir(parents=True, exist_ok=True)

    for pkg in packages:
        info = parse_package_info(pkg)
        if not info:
            print(f"Warning: Skipping {pkg.name} - invalid format")
            continue

        # Get first letter of package name
        first_letter = info["name"][0].lower()
        target_dir = staging_dir / first_letter

        target_dir.mkdir(parents=True, exist_ok=True)

        # Create symlink or copy to staging area for package
        target_path = target_dir / pkg.name

        if not target_path.exists():
            # Create relative symlink
            os.symlink(pkg.resolve(), target_path)

        # Also symlink the .sha256 file if it exists
        hash_file = pkg.parent / f"{pkg.name}.sha256"
        if hash_file.exists():
            target_hash_path = target_dir / f"{pkg.name}.sha256"
            if not target_hash_path.exists():
                os.symlink(hash_file.resolve(), target_hash_path)

        if first_letter not in organized:
            organized[first_letter] = []
        organized[first_letter].append(pkg)

    print(f"Organized {len(packages)} packages into {len(organized)} directories")
    return organized


def generate_index(packages: List[Path], output_path: Path):
    """Generate JSON index of all packages.

    Args:
        packages: List of package paths
        output_path: Where to write index.json
    """
    print("Generating index...")

    index = {
        "packages": [],
        "by_name": {},
        "total": len(packages),
    }

    for pkg in packages:
        info = parse_package_info(pkg)
        if not info:
            continue

        index["packages"].append(info)

        # Group by name
        name = info["name"]
        if name not in index["by_name"]:
            index["by_name"][name] = []
        index["by_name"][name].append({
            "version": info["version"],
            "config_hash": info["config_hash"],
            "content_hash": info["content_hash"],
            "filename": info["filename"],
            "size": info["size"],
        })

    # Sort packages by name, then version
    index["packages"].sort(key=lambda x: (x["name"], x["version"]))

    # Write index
    with open(output_path, "w") as f:
        json.dump(index, f, indent=2)

    print(f"✓ Generated index: {output_path}")
    print(f"  {len(index['packages'])} total packages")
    print(f"  {len(index['by_name'])} unique package names")


def upload_directory(source_dir: Path, mirror_url: str, use_rsync: bool = False):
    """Upload directory to mirror.

    Args:
        source_dir: Local directory to upload
        mirror_url: Mirror destination (user@host:/path or /local/path)
        use_rsync: Use rsync instead of scp
    """
    print(f"Uploading {source_dir} to {mirror_url}...")

    if mirror_url.startswith("/"):
        # Local copy
        import shutil
        dest = Path(mirror_url)
        dest.mkdir(parents=True, exist_ok=True)

        for item in source_dir.glob("*"):
            if item.is_dir():
                shutil.copytree(item, dest / item.name, dirs_exist_ok=True)
            else:
                shutil.copy2(item, dest / item.name)

        print(f"✓ Copied to {dest}")
    elif use_rsync:
        # Rsync upload (faster for updates)
        # -L flag follows symlinks and copies the actual files
        cmd = [
            "rsync",
            "-avzL",
            "--progress",
            str(source_dir) + "/",
            mirror_url + "/"
        ]
        subprocess.run(cmd, check=True)
        print(f"✓ Rsync complete")
    else:
        # SCP upload
        cmd = [
            "scp",
            "-r",
            str(source_dir) + "/",
            mirror_url
        ]
        subprocess.run(cmd, check=True)
        print(f"✓ SCP complete")


def main():
    parser = argparse.ArgumentParser(
        description="Upload binary packages to mirror server"
    )
    parser.add_argument(
        "--source",
        "-s",
        type=Path,
        required=True,
        help="Source directory containing binary packages"
    )
    parser.add_argument(
        "--mirror",
        "-m",
        type=str,
        help="Mirror destination (user@host:/path or /local/path)"
    )
    parser.add_argument(
        "--use-rsync",
        "-r",
        action="store_true",
        help="Use rsync instead of scp (faster for updates)"
    )
    parser.add_argument(
        "--staging-dir",
        type=Path,
        default=Path("/tmp/buckos-binaries-staging"),
        help="Staging directory for organization (default: /tmp/buckos-binaries-staging)"
    )
    parser.add_argument(
        "--generate-index-only",
        "-i",
        action="store_true",
        help="Only generate index.json, don't upload"
    )
    parser.add_argument(
        "--dry-run",
        "-n",
        action="store_true",
        help="Show what would be uploaded without uploading"
    )

    args = parser.parse_args()

    if not args.generate_index_only and not args.mirror:
        print("Error: --mirror required unless --generate-index-only is used")
        return 1

    if not args.source.exists():
        print(f"Error: Source directory not found: {args.source}")
        return 1

    print("BuckOS Binary Package Uploader")
    print("=" * 60)
    print(f"Source: {args.source}")
    if args.mirror:
        print(f"Mirror: {args.mirror}")
    print(f"Method: {'rsync' if args.use_rsync else 'scp' if args.mirror and not args.mirror.startswith('/') else 'local copy'}")
    if args.dry_run:
        print("Mode: DRY RUN")
    print("=" * 60)
    print()

    # Find packages
    packages = find_binary_packages(args.source)
    print(f"Found {len(packages)} binary packages")
    print()

    if not packages:
        print("No packages found!")
        return 1

    # Organize into staging directory
    organized = organize_packages(packages, args.staging_dir)

    # Generate index
    index_path = args.staging_dir / "index.json"
    generate_index(packages, index_path)
    print()

    if args.dry_run:
        print("Dry run - would upload:")
        for letter, pkgs in sorted(organized.items()):
            print(f"  /{letter}/ ({len(pkgs)} packages)")
        print(f"  /index.json")
        return 0

    if args.generate_index_only:
        print(f"Index generated at: {index_path}")
        print("Use --mirror to upload")
        return 0

    # Upload
    upload_directory(args.staging_dir, args.mirror, args.use_rsync)

    print()
    print("=" * 60)
    print(f"✓ Successfully uploaded {len(packages)} packages")
    print("=" * 60)
    print()
    print("Packages are now available at:")
    for letter in sorted(organized.keys()):
        if args.mirror.startswith("/"):
            print(f"  {args.mirror}/{letter}/")
        else:
            mirror_base = args.mirror.split(":")[0]
            print(f"  https://{mirror_base}/{letter}/")

    return 0


if __name__ == "__main__":
    sys.exit(main())
