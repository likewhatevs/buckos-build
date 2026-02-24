#!/usr/bin/env python3
"""Create a raw disk image from a rootfs.

Replaces the inline bash in image.bzl _raw_disk_image_impl.  Still requires
root/fakeroot for mount/mkfs operations.
"""

import argparse
import os
import subprocess
import sys
import tempfile

from _env import clean_env


def _run(cmd, env, **kwargs):
    """Run a subprocess with clean env, exiting on failure."""
    result = subprocess.run(cmd, env=env, **kwargs)
    if result.returncode != 0:
        print(f"error: {cmd[0]} failed with exit code {result.returncode}", file=sys.stderr)
        sys.exit(1)


def _apply_ima(mount_dir, env):
    """Apply IMA .sig sidecars as security.ima xattrs."""
    import shutil
    if not shutil.which("evmctl"):
        return
    applied = 0
    for dirpath, _, filenames in os.walk(mount_dir):
        for fname in filenames:
            if not fname.endswith(".sig"):
                continue
            sig_path = os.path.join(dirpath, fname)
            target = sig_path[:-4]  # strip .sig
            if not os.path.isfile(target):
                continue
            result = subprocess.run(
                ["evmctl", "ima_setxattr", "--sigfile", sig_path, target],
                env=env, capture_output=True,
            )
            if result.returncode == 0:
                os.remove(sig_path)
                applied += 1
    if applied:
        print(f"Applied security.ima to {applied} files")


def _make_fs(device, filesystem, label, env):
    """Create a filesystem on a device."""
    if filesystem == "ext4":
        _run(["mkfs.ext4", "-F", "-L", label, device], env)
    elif filesystem == "xfs":
        _run(["mkfs.xfs", "-f", "-L", label, device], env)
    elif filesystem == "btrfs":
        _run(["mkfs.btrfs", "-f", "-L", label, device], env)
    else:
        print(f"Unsupported filesystem: {filesystem}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Create raw disk image")
    parser.add_argument("--rootfs", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--size", default="2G")
    parser.add_argument("--filesystem", default="ext4")
    parser.add_argument("--label", default=None)
    parser.add_argument("--partition-table", action="store_true")
    args = parser.parse_args()

    env = clean_env()
    rootfs = os.path.abspath(args.rootfs)
    output = os.path.abspath(args.output)
    label = args.label or "buckos"

    print(f"Creating raw disk image...")
    print(f"  Size: {args.size}")
    print(f"  Filesystem: {args.filesystem}")
    print(f"  Label: {label}")

    _run(["truncate", "-s", args.size, output], env)

    if args.partition_table:
        # GPT partition table with EFI system partition
        _run(["sgdisk", "-Z", output], env)
        _run(["sgdisk", "-n", "1:2048:+100M", "-t", "1:EF00", "-c", "1:EFI", output], env)
        _run(["sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:" + label, output], env)

        # Set up loop device
        result = subprocess.run(
            ["losetup", "--find", "--show", "--partscan", output],
            env=env, capture_output=True, text=True,
        )
        if result.returncode != 0:
            print("error: losetup failed", file=sys.stderr)
            sys.exit(1)
        loop = result.stdout.strip()

        try:
            import time
            time.sleep(1)  # Wait for partitions

            _run(["mkfs.vfat", "-F", "32", "-n", "EFI", loop + "p1"], env)
            _make_fs(loop + "p2", args.filesystem, label, env)

            mount_dir = tempfile.mkdtemp()
            try:
                _run(["mount", loop + "p2", mount_dir], env)
                os.makedirs(os.path.join(mount_dir, "boot", "efi"), exist_ok=True)
                _run(["mount", loop + "p1", os.path.join(mount_dir, "boot", "efi")], env)

                subprocess.run(["cp", "-a", rootfs + "/.", mount_dir + "/"],
                               env=env, capture_output=True)
                _apply_ima(mount_dir, env)

                _run(["sync"], env)
                subprocess.run(["umount", os.path.join(mount_dir, "boot", "efi")],
                               env=env, capture_output=True)
                subprocess.run(["umount", mount_dir], env=env, capture_output=True)
            finally:
                subprocess.run(["umount", "-R", mount_dir], env=env,
                               capture_output=True)
                os.rmdir(mount_dir)
        finally:
            subprocess.run(["losetup", "-d", loop], env=env, capture_output=True)
    else:
        # Simple raw image without partition table
        _make_fs(output, args.filesystem, label, env)

        mount_dir = tempfile.mkdtemp()
        try:
            _run(["mount", "-o", "loop", output, mount_dir], env)
            subprocess.run(["cp", "-a", rootfs + "/.", mount_dir + "/"],
                           env=env, capture_output=True)
            _apply_ima(mount_dir, env)
            _run(["sync"], env)
            subprocess.run(["umount", mount_dir], env=env, capture_output=True)
        finally:
            subprocess.run(["umount", mount_dir], env=env, capture_output=True)
            os.rmdir(mount_dir)

    print(f"Disk image created: {output}")


if __name__ == "__main__":
    main()
