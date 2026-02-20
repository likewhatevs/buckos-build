# Fedora Compatibility Layer

BuckOS can produce images compatible with upstream Fedora 42. When the
`fedora` USE flag is enabled, users can add a Fedora repo, `dnf install`
packages, and have everything work — correct ABI, library paths, and
hardening flags.

## Quick Start

```bash
# Build the Fedora-compatible rootfs
buck2 build //:fedora -c use.fedora=true

# Boot it in QEMU
buck2 build //:fedora-boot -c use.fedora=true
bash buck-out/v2/gen/root/.../qemu-boot-fedora.sh

# Or persistently enable in .buckconfig.local:
# [use]
# fedora = true
```

## What the `fedora` USE Flag Does

1. **Applies Fedora 42 hardening compiler/linker flags** to all build macros
   (autotools, cmake, meson, make, cargo, go)
2. **Ensures `/lib64` → `/usr/lib64` merged-usr symlink** exists in the rootfs
3. **Includes RPM + DNF5** packages in the image
4. **Configures Fedora 42 repos** so `dnf5 install` works out of the box

## Filesystem Layout

BuckOS already uses `/usr/lib64` for 64-bit libraries on x86\_64 — the same
layout Fedora uses. No path translation is needed:

| Path | Purpose |
|------|---------|
| `/usr/lib64` | 64-bit libraries |
| `/lib64` → `/usr/lib64` | Merged-usr symlink |
| `/usr/bin` | All binaries |
| `/bin` → `/usr/bin` | Merged-usr symlink |
| `/usr/sbin` → `bin` | Merged-sbin symlink |

## Build Flags

When `fedora` mode is active, packages receive Fedora 42 hardening flags:

```
CFLAGS:  -O2 -flto=auto -fexceptions -g -pipe -Wall
         -Werror=format-security -Wp,-D_FORTIFY_SOURCE=3
         -Wp,-D_GLIBCXX_ASSERTIONS -fno-omit-frame-pointer
         -fstack-clash-protection -fcf-protection
LDFLAGS: -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -flto=auto
```

Build-system-specific integration:
- **cmake**: `fedora_cmake_args()` sets `CMAKE_C_FLAGS`, `CMAKE_CXX_FLAGS`,
  linker flags
- **meson**: `fedora_meson_args()` sets `c_args`, `cpp_args`, link args
- **autotools/make/cargo/go**: `get_fedora_build_env()` merges `CFLAGS`,
  `CXXFLAGS`, `LDFLAGS`, `FFLAGS` into the environment

## Packages

The Fedora compat layer builds these from source:

| Package | Version | Purpose |
|---------|---------|---------|
| rpm | 4.20.1 | RPM package manager |
| dnf5/libdnf5 | 5.2.8.1 | DNF5 package manager |
| libsolv | 0.7.31 | Dependency solver |
| librepo | 1.19.0 | Repository downloading |
| fedora-repos | — | Fedora 42 repo configs + RPM macros |

These depend on libraries already in BuckOS (zlib, openssl, curl, sqlite,
libxml2, gpgme, popt, libarchive, lua, json-c, etc.).

## Build Targets

```
//:fedora                                  # Fedora-compatible rootfs
//:fedora-boot                             # QEMU boot script
//packages/linux/system:buckos-fedora-rootfs
//packages/linux/system:buckos-fedora-initramfs
//packages/linux/system:qemu-boot-fedora
//packages/linux/system/pkg-mgmt/rpm:rpm
//packages/linux/system/pkg-mgmt/dnf5:dnf5
//packages/linux/system/pkg-mgmt/libsolv:libsolv
//packages/linux/system/pkg-mgmt/librepo:librepo
//packages/linux/system/pkg-mgmt/fedora-repos:fedora-repos
```

## QEMU Targets

Composable QEMU targets integrate with `buck2 run` and `buck2 test`:

```bash
# Interactive shell
buck2 run //:fedora-vm -c use.fedora=true

# Individual VM tests
buck2 test //packages/linux/system:fedora-vm-rpm-works -c use.fedora=true
buck2 test //packages/linux/system:fedora-vm-dnf-works -c use.fedora=true
buck2 test //packages/linux/system:fedora-vm-lib64-layout -c use.fedora=true
buck2 test //packages/linux/system:fedora-vm-install-tree -c use.fedora=true

# All VM tests in the package
buck2 test //packages/linux/system: -c use.fedora=true
```

The `qemu_machine` macro in `defs/qemu.bzl` creates a family of targets from
shared machine config.  Command injection uses concatenated initrd — a tiny
overlay cpio containing `/init` is appended to the main initramfs.  The overlay
runs the test command, writes the exit code to serial as `===QEMU_RC=N===`,
and powers off.  The host-side wrapper extracts the exit code.

The legacy `qemu_boot_script` targets (`//:fedora-boot`) still work and now
also support `buck2 run` directly.

## Testing

```bash
# Existing tests still pass
make test-fast

# QEMU integration tests (boots VM, installs Fedora packages)
make test-qemu
```

The QEMU tests verify:
- `rpm -qa` and `dnf5 --version` work
- `/usr/lib64` layout and `/lib64` symlink are correct
- Fedora 42 repos are configured
- Built binaries have RELRO/BIND\_NOW hardening
- A data-only Fedora package (`words`) installs cleanly
- A binary Fedora package (`tree`) installs and its shared libs resolve
  against BuckOS-provided libraries
- The installed binary actually executes

## Infrastructure Files

| File | Role |
|------|------|
| `config/fedora_build_flags.bzl` | Fedora 42 compiler/linker flags, per-build-system helpers |
| `defs/package_defs.bzl` | `_FEDORA_MODE` detection, flag injection in all build macros, `/lib64` symlink in rootfs |
| `defs/fhs_mapping.bzl` | Filesystem layout mapping (no-op on x86\_64) |
| `defs/rpm_package.bzl` | RPM download/extract rules, `FEDORA_MIRRORS`, dependency map |
| `defs/distro_constraints.bzl` | Distribution constraint helpers |
| `platforms/BUCK` | `distro_compat` constraint with `fedora` value |
| `.buckconfig` | `[use] fedora = false` (default off) |

## See Also

- `defs/use_flags.bzl` — USE flag system
- `defs/package_defs.bzl` — Package definition macros
- Fedora Packaging Guidelines: https://docs.fedoraproject.org/en-US/packaging-guidelines/
- FHS Specification: https://refspecs.linuxfoundation.org/FHS_3.0/
