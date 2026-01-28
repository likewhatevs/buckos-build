#!/usr/bin/env python3
"""
Verify that a mirror directory contains all required source files.

Useful for checking mirror completeness before using it for builds.

Usage:
    ./scripts/verify-mirror.py /path/to/mirror
    ./scripts/verify-mirror.py /path/to/mirror --check-checksums
"""

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple


def extract_downloads_from_buck_files() -> List[Tuple[str, str, str]]:
    """Parse BUCK files to extract download information."""
    downloads = []
    buck_files = []

    for root, dirs, files in os.walk("packages"):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for file in files:
            if file == "BUCK":
                buck_files.append(os.path.join(root, file))

    print(f"Scanning {len(buck_files)} BUCK files...")

    for buck_file in buck_files:
        try:
            with open(buck_file, "r") as f:
                content = f.read()

            package_name = buck_file.replace("packages/", "").replace("/BUCK", "")
            pattern = r'src_uri\s*=\s*"([^"]+)"[^}]*?sha256\s*=\s*"([^"]+)"'
            matches = re.findall(pattern, content, re.DOTALL)

            for url, sha256 in matches:
                if url and not url.startswith("...") and sha256 and sha256 != "0" * 64:
                    downloads.append((package_name, url, sha256))

        except Exception as e:
            print(f"Warning: Failed to parse {buck_file}: {e}", file=sys.stderr)

    # Deduplicate
    seen = set()
    unique = []
    for pkg, url, sha256 in downloads:
        if url not in seen:
            seen.add(url)
            unique.append((pkg, url, sha256))

    return unique


def get_filename_from_url(url: str) -> str:
    """Extract filename from URL."""
    from urllib.parse import urlparse
    return os.path.basename(urlparse(url).path)


def verify_checksum(file_path: Path, expected_sha256: str) -> bool:
    """Verify file SHA256 checksum."""
    if not expected_sha256:
        return True

    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)

    return sha256.hexdigest() == expected_sha256


def find_file_in_mirror(mirror_dir: Path, filename: str) -> Path | None:
    """Find a file in mirror directory structure."""
    # Try first-letter subdirectory
    if filename:
        first_letter = filename[0].lower()
        path = mirror_dir / first_letter / filename
        if path.exists():
            return path

    # Try other subdirectory
    path = mirror_dir / "other" / filename
    if path.exists():
        return path

    # Try root
    path = mirror_dir / filename
    if path.exists():
        return path

    # Search recursively as last resort
    for root, dirs, files in os.walk(mirror_dir):
        if filename in files:
            return Path(root) / filename

    return None


def verify_mirror(
    mirror_dir: Path,
    check_checksums: bool = False,
    verbose: bool = False
) -> Tuple[int, int, int]:
    """
    Verify mirror completeness.

    Returns:
        (found, missing, checksum_failures)
    """
    downloads = extract_downloads_from_buck_files()
    print(f"Checking {len(downloads)} source files in {mirror_dir}")
    print()

    found = 0
    missing = 0
    checksum_failures = 0
    missing_files = []
    failed_checksums = []

    for i, (package, url, sha256) in enumerate(downloads, 1):
        filename = get_filename_from_url(url)

        if verbose and i % 100 == 0:
            print(f"Progress: {i}/{len(downloads)}")

        # Find file in mirror
        file_path = find_file_in_mirror(mirror_dir, filename)

        if not file_path:
            missing += 1
            missing_files.append((package, url, filename))
            if verbose:
                print(f"✗ Missing: {filename} ({package})")
            continue

        # File exists
        found += 1

        # Verify checksum if requested
        if check_checksums:
            if not verify_checksum(file_path, sha256):
                checksum_failures += 1
                failed_checksums.append((package, filename, sha256))
                if verbose:
                    print(f"✗ Checksum failed: {filename}")
            elif verbose:
                print(f"✓ OK: {filename}")
        elif verbose:
            print(f"✓ Found: {filename}")

    return found, missing, checksum_failures, missing_files, failed_checksums


def main():
    parser = argparse.ArgumentParser(
        description="Verify mirror completeness"
    )
    parser.add_argument(
        "mirror_dir",
        type=Path,
        help="Mirror directory to verify",
    )
    parser.add_argument(
        "--check-checksums",
        "-c",
        action="store_true",
        help="Verify SHA256 checksums (slower)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Verbose output",
    )
    parser.add_argument(
        "--report",
        "-r",
        type=Path,
        help="Write detailed report to file",
    )

    args = parser.parse_args()

    if not args.mirror_dir.exists():
        print(f"Error: Mirror directory does not exist: {args.mirror_dir}", file=sys.stderr)
        return 1

    if not args.mirror_dir.is_dir():
        print(f"Error: Not a directory: {args.mirror_dir}", file=sys.stderr)
        return 1

    print("BuckOS Mirror Verification")
    print("=" * 60)
    print(f"Mirror: {args.mirror_dir}")
    print(f"Check checksums: {args.check_checksums}")
    print("=" * 60)
    print()

    found, missing, checksum_failures, missing_files, failed_checksums = verify_mirror(
        args.mirror_dir,
        check_checksums=args.check_checksums,
        verbose=args.verbose,
    )

    # Print summary
    print()
    print("=" * 60)
    print("Verification Summary")
    print("=" * 60)
    print(f"Found:     {found}")
    print(f"Missing:   {missing}")

    if args.check_checksums:
        print(f"Checksum failures: {checksum_failures}")

    total = found + missing
    completeness = (found / total * 100) if total > 0 else 0
    print(f"Completeness: {completeness:.1f}%")
    print("=" * 60)

    # Show missing files
    if missing_files and not args.verbose:
        print()
        print("Missing files (first 10):")
        for package, url, filename in missing_files[:10]:
            print(f"  - {filename}")
            print(f"    Package: {package}")
            print(f"    URL: {url}")
        if len(missing_files) > 10:
            print(f"  ... and {len(missing_files) - 10} more")

    # Show checksum failures
    if failed_checksums and not args.verbose:
        print()
        print("Checksum failures (first 10):")
        for package, filename, sha256 in failed_checksums[:10]:
            print(f"  - {filename}")
            print(f"    Package: {package}")
            print(f"    Expected: {sha256[:16]}...")
        if len(failed_checksums) > 10:
            print(f"  ... and {len(failed_checksums) - 10} more")

    # Write detailed report
    if args.report:
        report = {
            "mirror_dir": str(args.mirror_dir),
            "check_checksums": args.check_checksums,
            "summary": {
                "found": found,
                "missing": missing,
                "checksum_failures": checksum_failures,
                "total": found + missing,
                "completeness_percent": completeness,
            },
            "missing_files": [
                {
                    "package": pkg,
                    "url": url,
                    "filename": filename,
                }
                for pkg, url, filename in missing_files
            ],
            "checksum_failures": [
                {
                    "package": pkg,
                    "filename": filename,
                    "expected_sha256": sha256,
                }
                for pkg, filename, sha256 in failed_checksums
            ],
        }

        with open(args.report, "w") as f:
            json.dump(report, f, indent=2)

        print(f"\nDetailed report written to: {args.report}")

    # Exit code
    if missing > 0 or checksum_failures > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
