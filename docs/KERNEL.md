# BuckOS Kernel Configuration System

This document describes the BuckOS kernel build system and how to configure and customize kernel builds using Buck2.

## Overview

BuckOS uses a modular kernel configuration system that allows:

- **Pre-built kernel packages** for common use cases
- **Configuration fragments** that can be combined to create custom configs
- **Easy customization** without managing entire kernel configs
- **Reproducible builds** through Buck2's hermetic build system

## Kernel Version

BuckOS uses the **Linux 6.12 LTS** kernel (released November 2024), which is supported until December 2026. This provides:

- Long-term stability and security updates
- Real-time `PREEMPT_RT` support
- New `sched_ext` scheduler
- Improved hardware support

## Available Kernel Packages

### Default Kernel

```bash
buck2 build //packages/linux/kernel/buckos-kernel
```

The default BuckOS kernel with comprehensive hardware support. Includes:
- All common filesystems (ext4, XFS, Btrfs, NTFS, etc.)
- Full networking stack with BBR congestion control
- Virtualization (KVM host and VirtIO guest)
- Container support (cgroups v2, namespaces)
- Security features (AppArmor, SELinux, TPM)

### Kernel Variants

| Package | Description | Use Case |
|---------|-------------|----------|
| `buckos-kernel` | Full featured default kernel | General purpose, most users |
| `buckos-kernel-minimal` | Essential drivers only | Small footprint, embedded |
| `buckos-kernel-server` | Server optimized | Servers, headless systems |
| `buckos-kernel-vm` | VM guest optimized | Virtual machines |
| `buckos-kernel-defconfig` | Kernel defconfig | Development/testing |

Build examples:
```bash
buck2 build //packages/linux/kernel/buckos-kernel:buckos-kernel-minimal
buck2 build //packages/linux/kernel/buckos-kernel:buckos-kernel-server
buck2 build //packages/linux/kernel/buckos-kernel:buckos-kernel-vm
```

## Configuration Fragments

BuckOS provides modular configuration fragments that can be combined to create custom kernel configurations.

### Available Fragments

| Fragment | Description |
|----------|-------------|
| `base.config` | Core settings (64-bit, SMP, modules, power management) |
| `filesystem.config` | Filesystem support (ext4, XFS, Btrfs, FUSE, NFS, etc.) |
| `network.config` | Networking (TCP/IP, IPv6, netfilter, drivers) |
| `hardware.config` | Hardware drivers (USB, SCSI, SATA, NVMe, input, audio) |
| `virtualization.config` | KVM, VirtIO, containers, VFIO |
| `security.config` | Crypto, LSM, TPM, integrity |

### Pre-built Configurations

```bash
# View available configs
buck2 build //packages/linux/kernel/configs:buckos-default
buck2 build //packages/linux/kernel/configs:buckos-minimal
buck2 build //packages/linux/kernel/configs:buckos-server
buck2 build //packages/linux/kernel/configs:buckos-vm-guest
```

## Creating Custom Kernels

### Method 1: Combine Fragments

Create a custom kernel by combining existing fragments with your own overrides.

1. Create a custom fragment file:

```bash
# my-custom.config
CONFIG_PREEMPT=y
CONFIG_HZ_1000=y
CONFIG_DRM_I915=y
```

2. Create a BUCK file with `kernel_config`:

```python
load("//defs:package_defs.bzl", "kernel_build", "kernel_config")

# Merge fragments into a final config
kernel_config(
    name = "my-kernel-config",
    fragments = [
        "//packages/linux/kernel/configs:base.config",
        "//packages/linux/kernel/configs:filesystem.config",
        "//packages/linux/kernel/configs:network.config",
        "//packages/linux/kernel/configs:hardware.config",
        "my-custom.config",  # Your custom fragment (last to override)
    ],
)

# Build kernel with merged config
kernel_build(
    name = "my-kernel",
    source = "//packages/linux/kernel/src:linux-src",
    version = "6.12.6",
    config_dep = ":my-kernel-config",
    visibility = ["PUBLIC"],
)
```

3. Build your kernel:

```bash
buck2 build //path/to/your:my-kernel
```

### Method 2: Complete Custom Config

Use when you have a complete kernel configuration from another source:

```python
kernel_build(
    name = "my-kernel",
    source = "//packages/linux/kernel/src:linux-src",
    version = "6.12.6",
    config = "my-complete.config",  # Your full config file
    visibility = ["PUBLIC"],
)
```

You can generate a config using:
```bash
# From kernel source
make menuconfig
make savedefconfig

# Or copy from another distribution
cp /boot/config-$(uname -r) my-complete.config
```

### Method 3: Using Defconfig

For development or minimal builds:

```python
kernel_build(
    name = "dev-kernel",
    source = "//packages/linux/kernel/src:linux-src",
    version = "6.12.6",
    # No config = uses make defconfig
    visibility = ["PUBLIC"],
)
```

## How Configuration Merging Works

The `kernel_config` rule merges fragments in order, with later fragments overriding earlier ones:

1. Each fragment is processed line by line
2. When a CONFIG option is set, any previous setting is removed
3. The final merged config is passed to `make olddefconfig` to fill in defaults

This allows you to:
- Start with base fragments for common settings
- Add specialized fragments (like `virtualization.config`)
- Override specific options with your custom fragment last

## Fragment Customization Examples

### Desktop/Workstation

```python
kernel_config(
    name = "desktop-config",
    fragments = [
        "//packages/linux/kernel/configs:base.config",
        "//packages/linux/kernel/configs:filesystem.config",
        "//packages/linux/kernel/configs:network.config",
        "//packages/linux/kernel/configs:hardware.config",
        "//packages/linux/kernel/configs:security.config",
        "desktop.config",  # Add graphics drivers, preemption
    ],
)
```

### Embedded/IoT

```python
kernel_config(
    name = "embedded-config",
    fragments = [
        "//packages/linux/kernel/configs:base.config",
        "//packages/linux/kernel/configs:filesystem.config",
        "embedded-hw.config",  # Specific hardware only
    ],
)
```

### Cloud/Container Host

```python
kernel_config(
    name = "cloud-config",
    fragments = [
        "//packages/linux/kernel/configs:base.config",
        "//packages/linux/kernel/configs:filesystem.config",
        "//packages/linux/kernel/configs:network.config",
        "//packages/linux/kernel/configs:virtualization.config",
        "//packages/linux/kernel/configs:security.config",
        "cloud-tweaks.config",  # Disable unnecessary drivers
    ],
)
```

## Build Rules Reference

### `kernel_config`

Merges multiple configuration fragments into a single .config file.

```python
kernel_config(
    name = "config-name",
    fragments = [
        "fragment1.config",
        "fragment2.config",
        # Later fragments override earlier ones
    ],
)
```

### `kernel_build`

Builds a Linux kernel with the specified configuration.

```python
kernel_build(
    name = "kernel-name",
    source = "//packages/linux/kernel/src:linux-src",
    version = "6.12.6",

    # Use ONE of these config options:
    config = "path/to/config.file",  # Direct config file
    config_dep = ":config-target",   # Output from kernel_config
    # Or neither for defconfig

    visibility = ["PUBLIC"],
)
```

## Directory Structure

```
packages/linux/kernel/
├── BUCK                    # Main kernel targets
├── src/                    # Kernel source download
│   └── BUCK
├── configs/                # Configuration fragments
│   ├── BUCK
│   ├── base.config
│   ├── filesystem.config
│   ├── network.config
│   ├── hardware.config
│   ├── virtualization.config
│   └── security.config
├── buckos-kernel/          # Official BuckOS kernels
│   └── BUCK
├── examples/               # Custom kernel examples
│   └── BUCK
├── linux/                  # Legacy (deprecated)
└── linux-defconfig/        # Legacy (deprecated)
```

## Migration from Legacy Targets

If you were using the old kernel targets, migrate as follows:

| Old Target | New Target |
|------------|------------|
| `//packages/linux/kernel/linux` | `//packages/linux/kernel/buckos-kernel` |
| `//packages/linux/kernel/linux-defconfig` | `//packages/linux/kernel/buckos-kernel:buckos-kernel-defconfig` |

The legacy targets still work but now use the 6.12 LTS kernel source.

## Tips

### Checking Configuration

To see what options are set in a merged config:
```bash
buck2 build //packages/linux/kernel/configs:buckos-default
cat buck-out/v2/gen/.../buckos-default.config | grep CONFIG_KVM
```

### Debugging Build Issues

If the kernel fails to build:
1. Check for conflicting options between fragments
2. Run `make olddefconfig` to resolve dependencies
3. Use the debug fragment for more verbose output

### Performance Tuning

For specific workloads, consider:
- `CONFIG_PREEMPT` levels for latency vs throughput
- `CONFIG_HZ` settings (100/250/300/1000)
- CPU frequency governors
- I/O schedulers

## See Also

- [USE_FLAGS.md](USE_FLAGS.md) - Package USE flags
- [PACKAGE_SETS.md](PACKAGE_SETS.md) - System profiles
- [packages/linux/kernel/examples/](../packages/linux/kernel/examples/) - Example custom kernels
