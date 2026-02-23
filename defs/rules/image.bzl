"""
Image rules: iso_image, raw_disk_image, stage3_tarball.

Assembly rules that take rootfs/kernel/initramfs deps and produce images.
"""

load("//defs:providers.bzl", "IsoImageInfo", "KernelInfo", "Stage3Info")
load("//defs:toolchain_helpers.bzl", "TOOLCHAIN_ATTRS", "toolchain_path_args")

def _get_kernel_image(dep):
    """Extract boot image from KernelInfo provider."""
    if KernelInfo not in dep:
        fail("kernel dep must provide KernelInfo")
    return dep[KernelInfo].bzimage

# =============================================================================
# RAW DISK IMAGE
# =============================================================================

def _raw_disk_image_impl(ctx: AnalysisContext) -> list[Provider]:
    """Create a raw disk image from a rootfs (for Cloud Hypervisor)."""
    image_file = ctx.actions.declare_output(ctx.attrs.name + ".raw")

    # Get rootfs directory
    rootfs_dir = ctx.attrs.rootfs[DefaultInfo].default_outputs[0]

    # Configuration
    size = ctx.attrs.size
    filesystem = ctx.attrs.filesystem
    label = ctx.attrs.label if ctx.attrs.label else ctx.attrs.name
    partition_table = ctx.attrs.partition_table

    # Build the script to create the disk image
    if partition_table:
        # GPT partition table with EFI system partition
        script_content = """#!/bin/bash
set -e

ROOTFS="$1"
OUTPUT="$2"
SIZE="{size}"
FS="{filesystem}"
LABEL="{label}"

echo "Creating raw disk image with GPT partition table..."
echo "  Size: $SIZE"
echo "  Filesystem: $FS"
echo "  Label: $LABEL"

# Create sparse file
truncate -s "$SIZE" "$OUTPUT"

# Create GPT partition table
# Partition 1: EFI System Partition (100M)
# Partition 2: Root filesystem (rest)
sgdisk -Z "$OUTPUT"
sgdisk -n 1:2048:+100M -t 1:EF00 -c 1:"EFI" "$OUTPUT"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"$LABEL" "$OUTPUT"

# Get partition offsets
EFI_START=$((2048 * 512))
EFI_SIZE=$((100 * 1024 * 1024))
ROOT_START=$(($(sgdisk -p "$OUTPUT" | grep "^ *2" | awk '{{print $2}}') * 512))

# Create filesystems using loop device
LOOP=$(losetup --find --show --partscan "$OUTPUT")
trap "losetup -d $LOOP" EXIT

# Wait for partitions to appear
sleep 1

# Format EFI partition
mkfs.vfat -F 32 -n EFI "${{LOOP}}p1"

# Format root partition
case "$FS" in
    ext4)
        mkfs.ext4 -F -L "$LABEL" "${{LOOP}}p2"
        ;;
    xfs)
        mkfs.xfs -f -L "$LABEL" "${{LOOP}}p2"
        ;;
    btrfs)
        mkfs.btrfs -f -L "$LABEL" "${{LOOP}}p2"
        ;;
    *)
        echo "Unsupported filesystem: $FS"
        exit 1
        ;;
esac

# Mount and copy rootfs
MOUNT_DIR=$(mktemp -d)
trap "umount -R $MOUNT_DIR 2>/dev/null || true; rm -rf $MOUNT_DIR; losetup -d $LOOP" EXIT

mount "${{LOOP}}p2" "$MOUNT_DIR"
mkdir -p "$MOUNT_DIR/boot/efi"
mount "${{LOOP}}p1" "$MOUNT_DIR/boot/efi"

# Copy rootfs
cp -a "$ROOTFS"/* "$MOUNT_DIR"/ || true

# Apply IMA .sig sidecars as security.ima xattrs and clean up
if command -v evmctl >/dev/null 2>&1; then
    _ima_applied=0
    while IFS= read -r -d '' _sig; do
        _target="${{_sig%.sig}}"
        [ -f "$_target" ] || continue
        evmctl ima_setxattr --sigfile "$_sig" "$_target" >/dev/null 2>&1 && {{
            rm -f "$_sig"
            _ima_applied=$((_ima_applied + 1))
        }}
    done < <(find "$MOUNT_DIR" -name '*.sig' -print0 2>/dev/null)
    [ "$_ima_applied" -gt 0 ] && echo "Applied security.ima to $_ima_applied files"
fi

# Unmount
sync
umount "$MOUNT_DIR/boot/efi"
umount "$MOUNT_DIR"

echo "Disk image created: $OUTPUT"
""".format(
            size = size,
            filesystem = filesystem,
            label = label,
        )
    else:
        # Simple raw image without partition table
        script_content = """#!/bin/bash
set -e

ROOTFS="$1"
OUTPUT="$2"
SIZE="{size}"
FS="{filesystem}"
LABEL="{label}"

echo "Creating raw disk image..."
echo "  Size: $SIZE"
echo "  Filesystem: $FS"
echo "  Label: $LABEL"

# Create sparse file
truncate -s "$SIZE" "$OUTPUT"

# Create filesystem directly on the image
case "$FS" in
    ext4)
        mkfs.ext4 -F -L "$LABEL" "$OUTPUT"
        ;;
    xfs)
        mkfs.xfs -f -L "$LABEL" "$OUTPUT"
        ;;
    btrfs)
        mkfs.btrfs -f -L "$LABEL" "$OUTPUT"
        ;;
    *)
        echo "Unsupported filesystem: $FS"
        exit 1
        ;;
esac

# Mount and copy rootfs
MOUNT_DIR=$(mktemp -d)
trap "umount $MOUNT_DIR 2>/dev/null || true; rm -rf $MOUNT_DIR" EXIT

mount -o loop "$OUTPUT" "$MOUNT_DIR"

# Copy rootfs
cp -a "$ROOTFS"/* "$MOUNT_DIR"/ || true

# Apply IMA .sig sidecars as security.ima xattrs and clean up
if command -v evmctl >/dev/null 2>&1; then
    _ima_applied=0
    while IFS= read -r -d '' _sig; do
        _target="${{_sig%.sig}}"
        [ -f "$_target" ] || continue
        evmctl ima_setxattr --sigfile "$_sig" "$_target" >/dev/null 2>&1 && {{
            rm -f "$_sig"
            _ima_applied=$((_ima_applied + 1))
        }}
    done < <(find "$MOUNT_DIR" -name '*.sig' -print0 2>/dev/null)
    [ "$_ima_applied" -gt 0 ] && echo "Applied security.ima to $_ima_applied files"
fi

# Unmount
sync
umount "$MOUNT_DIR"

echo "Disk image created: $OUTPUT"
""".format(
            size = size,
            filesystem = filesystem,
            label = label,
        )

    script = ctx.actions.write("create_disk.sh", script_content, is_executable = True)

    # Note: This requires root/fakeroot to create the filesystem
    # In practice, this would be run with appropriate privileges
    # Build the command properly with cmd_args for Buck2
    cmd = cmd_args()
    cmd.add("bash")
    cmd.add(script)
    cmd.add(rootfs_dir)
    cmd.add(image_file.as_output())

    ctx.actions.run(
        cmd,
        category = "disk_image",
        identifier = ctx.attrs.name,
    )

    return [DefaultInfo(default_output = image_file)]

_raw_disk_image_rule = rule(
    impl = _raw_disk_image_impl,
    attrs = {
        "rootfs": attrs.dep(),
        "size": attrs.string(default = "2G"),
        "filesystem": attrs.string(default = "ext4"),  # ext4, xfs, btrfs
        "label": attrs.option(attrs.string(), default = None),
        "partition_table": attrs.bool(default = False),  # True for GPT with EFI
        "labels": attrs.list(attrs.string(), default = []),
    },
)

def raw_disk_image(labels = [], **kwargs):
    _raw_disk_image_rule(
        labels = labels,
        **kwargs
    )

# =============================================================================
# ISO IMAGE
# =============================================================================

def _iso_image_impl(ctx: AnalysisContext) -> list[Provider]:
    """Create a bootable ISO image from kernel, initramfs, and optional rootfs."""
    iso_file = ctx.actions.declare_output(ctx.attrs.name + ".iso")

    cmd = cmd_args(ctx.attrs._iso_tool[RunInfo])
    cmd.add("--kernel", _get_kernel_image(ctx.attrs.kernel))
    cmd.add("--initramfs", ctx.attrs.initramfs[DefaultInfo].default_outputs[0])
    cmd.add("--output", iso_file.as_output())

    if ctx.attrs.rootfs:
        cmd.add("--rootfs", ctx.attrs.rootfs[DefaultInfo].default_outputs[0])

    if ctx.attrs.modules:
        cmd.add("--modules", ctx.attrs.modules[DefaultInfo].default_outputs[0])
    elif KernelInfo in ctx.attrs.kernel:
        cmd.add("--modules", ctx.attrs.kernel[KernelInfo].modules_dir)

    cmd.add("--boot-mode", ctx.attrs.boot_mode)
    cmd.add("--volume-label", ctx.attrs.volume_label)
    cmd.add("--kernel-args", ctx.attrs.kernel_args)
    cmd.add("--arch", ctx.attrs.arch)

    # Hermetic PATH from toolchain
    for arg in toolchain_path_args(ctx):
        cmd.add(arg)

    ctx.actions.run(cmd, category = "iso", identifier = ctx.attrs.name)

    return [
        DefaultInfo(default_output = iso_file),
        IsoImageInfo(
            iso = iso_file,
            boot_mode = ctx.attrs.boot_mode,
            volume_label = ctx.attrs.volume_label,
            arch = ctx.attrs.arch,
        ),
    ]

_iso_image_rule = rule(
    impl = _iso_image_impl,
    attrs = {
        "kernel": attrs.dep(),
        "initramfs": attrs.dep(),
        "modules": attrs.option(attrs.dep(), default = None),
        "rootfs": attrs.option(attrs.dep(), default = None),
        "boot_mode": attrs.string(default = "hybrid"),  # bios, efi, or hybrid
        "volume_label": attrs.string(default = "BUCKOS"),
        "kernel_args": attrs.string(default = "quiet"),
        "arch": attrs.string(default = "x86_64"),  # x86_64 or aarch64
        "labels": attrs.list(attrs.string(), default = []),
        "_iso_tool": attrs.default_only(
            attrs.exec_dep(default = "//tools:iso_helper"),
        ),
    } | TOOLCHAIN_ATTRS,
)

def iso_image(labels = [], **kwargs):
    _iso_image_rule(
        labels = labels,
        **kwargs
    )

# =============================================================================
# STAGE3 TARBALL
# =============================================================================
# Creates a stage3 tarball from a rootfs for distribution.
# Stage3 tarballs are self-contained root filesystems with a complete
# toolchain that can be used to bootstrap new BuckOS installations.

def _stage3_tarball_impl(ctx: AnalysisContext) -> list[Provider]:
    """Create a stage3 tarball from a rootfs with metadata."""

    # Determine compression settings
    compression = ctx.attrs.compression
    compress_opts = {
        "xz": ("-J", ".tar.xz", "xz -9 -T0"),
        "gz": ("-z", ".tar.gz", "gzip -9"),
        "zstd": ("--zstd", ".tar.zst", "zstd -19 -T0"),
    }

    if compression not in compress_opts:
        fail("Unsupported compression: {}. Use xz, gz, or zstd".format(compression))

    compress_flag, suffix, compress_cmd = compress_opts[compression]

    # Build tarball filename: stage3-{arch}-{variant}-{libc}-{date}.tar.{ext}
    arch = ctx.attrs.arch
    variant = ctx.attrs.variant
    libc = ctx.attrs.libc
    version = ctx.attrs.version

    tarball_basename = "stage3-{}-{}-{}".format(arch, variant, libc)
    if version:
        tarball_basename += "-" + version

    # Declare outputs
    tarball_file = ctx.actions.declare_output(tarball_basename + suffix)
    sha256_file = ctx.actions.declare_output(tarball_basename + suffix + ".sha256")
    contents_file = ctx.actions.declare_output(tarball_basename + ".CONTENTS.gz")

    # Get rootfs directory
    rootfs_dir = ctx.attrs.rootfs[DefaultInfo].default_outputs[0]

    # Create the stage3 assembly script
    script_content = '''#!/bin/bash
set -e

ROOTFS="$1"
TARBALL="$2"
SHA256_FILE="$3"
CONTENTS_FILE="$4"
ARCH="{arch}"
VARIANT="{variant}"
LIBC="{libc}"
VERSION="{version}"
BUILD_DATE=$(date -u +%Y%m%dT%H%M%SZ)
DATE_STAMP=$(date -u +%Y%m%d)

echo "Creating stage3 tarball..."
echo "  Architecture: $ARCH"
echo "  Variant: $VARIANT"
echo "  Libc: $LIBC"
echo "  Version: $VERSION"

# Create a working copy of rootfs to add metadata
WORKDIR=$(mktemp -d)
trap "rm -rf $WORKDIR" EXIT

# Copy rootfs to working directory
cp -a "$ROOTFS"/. "$WORKDIR/"

# Apply IMA .sig sidecars as security.ima xattrs and clean up
if command -v evmctl >/dev/null 2>&1; then
    _ima_applied=0
    while IFS= read -r -d '' _sig; do
        _target="${{_sig%.sig}}"
        [ -f "$_target" ] || continue
        evmctl ima_setxattr --sigfile "$_sig" "$_target" >/dev/null 2>&1 && {{
            rm -f "$_sig"
            _ima_applied=$((_ima_applied + 1))
        }}
    done < <(find "$WORKDIR" -name '*.sig' -print0 2>/dev/null)
    [ "$_ima_applied" -gt 0 ] && echo "Applied security.ima to $_ima_applied files"
fi

# Create metadata directory
mkdir -p "$WORKDIR/etc/buckos"

# Generate STAGE3_INFO file
cat > "$WORKDIR/etc/buckos/stage3-info" << EOF
# BuckOS Stage3 Information
# Generated: $BUILD_DATE

[stage3]
variant=$VARIANT
arch=$ARCH
libc=$LIBC
date=$DATE_STAMP
version=$VERSION

[build]
build_date=$BUILD_DATE

[packages]
# Package count will be updated after build
EOF

# Generate CONTENTS file (list of all files with types)
echo "Generating CONTENTS file..."
(
    cd "$WORKDIR"
    find . -mindepth 1 | sort | while read -r path; do
        # Remove leading ./
        relpath="${{path#./}}"
        if [ -L "$path" ]; then
            target=$(readlink "$path")
            echo "sym /$relpath -> $target"
        elif [ -d "$path" ]; then
            echo "dir /$relpath"
        elif [ -f "$path" ]; then
            # Get file hash
            hash=$(sha256sum "$path" 2>/dev/null | cut -d' ' -f1 || echo "0")
            echo "obj /$relpath $hash"
        fi
    done
) | gzip -9 > "$CONTENTS_FILE"

# Create the tarball
echo "Creating tarball with {compression} compression..."
(
    cd "$WORKDIR"
    # Use numeric owner to ensure reproducibility
    tar --numeric-owner --owner=0 --group=0 \\
        --xattrs \\
        --sort=name \\
        {compress_flag} \\
        -cf "$TARBALL" .
)

# Generate SHA256 checksum
echo "Generating SHA256 checksum..."
(
    cd "$(dirname "$TARBALL")"
    sha256sum "$(basename "$TARBALL")" > "$SHA256_FILE"
)

echo "Stage3 tarball created successfully!"
echo "  Tarball: $TARBALL"
echo "  Checksum: $SHA256_FILE"
echo "  Contents: $CONTENTS_FILE"
'''.format(
        arch = arch,
        variant = variant,
        libc = libc,
        version = version if version else "0.1",
        compression = compression,
        compress_flag = compress_flag,
    )

    script = ctx.actions.write("create_stage3.sh", script_content, is_executable = True)

    cmd = cmd_args([
        "bash",
        script,
        rootfs_dir,
        tarball_file.as_output(),
        sha256_file.as_output(),
        contents_file.as_output(),
    ])

    ctx.actions.run(
        cmd,
        category = "stage3",
        identifier = ctx.attrs.name,
    )

    return [
        DefaultInfo(default_outputs = [tarball_file, sha256_file, contents_file]),
        Stage3Info(
            tarball = tarball_file,
            checksum = sha256_file,
            contents = contents_file,
            arch = arch,
            variant = variant,
            libc = libc,
            version = version if version else "0.1",
        ),
    ]

_stage3_tarball_rule = rule(
    impl = _stage3_tarball_impl,
    attrs = {
        "rootfs": attrs.dep(),
        "variant": attrs.string(default = "base"),      # minimal, base, developer, complete
        "arch": attrs.string(default = "amd64"),        # amd64, arm64
        "libc": attrs.string(default = "glibc"),        # glibc, musl
        "compression": attrs.string(default = "xz"),    # xz, gz, zstd
        "version": attrs.string(default = ""),          # Optional version string
        "labels": attrs.list(attrs.string(), default = []),
    },
)

def stage3_tarball(labels = [], **kwargs):
    _stage3_tarball_rule(
        labels = labels,
        **kwargs
    )
