# BuckOs Linux Distribution - Root Build File
# A Buck2-based Linux distribution similar to Gentoo's ebuild system

load("//defs:package_defs.bzl", "rootfs")

# =============================================================================
# Main build targets
# =============================================================================

# Minimal bootable system
alias(
    name = "minimal",
    actual = "//packages/linux/system:buckos-rootfs",
    visibility = ["PUBLIC"],
)

# Complete system with kernel - points to the minimal profile with kernel
alias(
    name = "complete",
    actual = "//:core-packages",
    visibility = ["PUBLIC"],
)

# Individual component aliases
alias(
    name = "kernel",
    actual = "//packages/linux/kernel:default",
    visibility = ["PUBLIC"],
)

alias(
    name = "bootloader",
    actual = "boot//grub:grub",
    visibility = ["PUBLIC"],
)

# Default shell
alias(
    name = "shell",
    actual = "core//bash:bash",
    visibility = ["PUBLIC"],
)

# Default terminal
alias(
    name = "terminal",
    actual = "terminals//foot:foot",
    visibility = ["PUBLIC"],
)

# Default cron
alias(
    name = "cron",
    actual = "system//apps/cronie:cronie",
    visibility = ["PUBLIC"],
)

# Essential utilities from sys-apps
alias(
    name = "tar",
    actual = "system//apps/tar:tar",
    visibility = ["PUBLIC"],
)

alias(
    name = "gzip",
    actual = "system//libs/compression/gzip:gzip",
    visibility = ["PUBLIC"],
)

alias(
    name = "shadow",
    actual = "system//apps/shadow:shadow",
    visibility = ["PUBLIC"],
)

alias(
    name = "man-db",
    actual = "system//docs:man-db",
    visibility = ["PUBLIC"],
)

alias(
    name = "texinfo",
    actual = "system//docs:texinfo",
    visibility = ["PUBLIC"],
)

alias(
    name = "gettext",
    actual = "dev-libs//misc/gettext:gettext",
    visibility = ["PUBLIC"],
)

# Default privilege escalation
alias(
    name = "sudo",
    actual = "system//apps/sudo:sudo",
    visibility = ["PUBLIC"],
)

# Default terminal multiplexer
alias(
    name = "multiplexer",
    actual = "system//apps/tmux:tmux",
    visibility = ["PUBLIC"],
)

# VPN solutions
alias(
    name = "wireguard",
    actual = "network//vpn/wireguard-tools:wireguard-tools",
    visibility = ["PUBLIC"],
)

alias(
    name = "openvpn",
    actual = "network//vpn/openvpn:openvpn",
    visibility = ["PUBLIC"],
)

alias(
    name = "strongswan",
    actual = "network//vpn/strongswan:strongswan",
    visibility = ["PUBLIC"],
)

# Benchmarking tools
alias(
    name = "benchmarks",
    actual = "benchmarks//:all-benchmarks",
    visibility = ["PUBLIC"],
)

# Default init system
alias(
    name = "init",
    actual = "system//init:systemd",
    visibility = ["PUBLIC"],
)

alias(
    name = "init-s6",
    actual = "system//init:s6",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Package groups for convenience
# =============================================================================

filegroup(
    name = "core-packages",
    srcs = [
        "core//musl:musl",
        "core//cpio:cpio",
        "core//util-linux:util-linux",
        "core//zlib:zlib",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "filesystem-packages",
    srcs = [
        "core//e2fsprogs:e2fsprogs",
    ],
    visibility = ["PUBLIC"],
)

# Networking packages
filegroup(
    name = "net-packages",
    srcs = [
        "system//libs/crypto/openssl:openssl",
        "network//curl:curl",
        "network//openssh:openssh",
        "network//iproute2:iproute2",
        "network//dhcpcd:dhcpcd",
    ],
    visibility = ["PUBLIC"],
)

# VPN packages
filegroup(
    name = "vpn-packages",
    srcs = [
        "network//vpn/wireguard-tools:wireguard-tools",
        "network//vpn/openvpn:openvpn",
        "network//vpn/strongswan:strongswan",
        "network//vpn/libreswan:libreswan",
        "network//vpn/openconnect:openconnect",
        "network//vpn/tinc:tinc",
        "network//vpn/zerotier:zerotier",
        "network//vpn/nebula:nebula",
    ],
    visibility = ["PUBLIC"],
)

# Modern VPN solutions
filegroup(
    name = "vpn-modern",
    srcs = [
        "network//vpn/wireguard-tools:wireguard-tools",
        "network//vpn/openvpn:openvpn",
        "network//vpn/strongswan:strongswan",
    ],
    visibility = ["PUBLIC"],
)

# Mesh VPN solutions
filegroup(
    name = "vpn-mesh",
    srcs = [
        "network//vpn/tinc:tinc",
        "network//vpn/zerotier:zerotier",
        "network//vpn/nebula:nebula",
        "network//vpn/tailscale:tailscale",
    ],
    visibility = ["PUBLIC"],
)

# Editor packages
filegroup(
    name = "editor-packages",
    srcs = [
        "editors//vim",
        "editors//neovim",
        "editors//emacs",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "shell-packages",
    srcs = [
        "core//bash:bash",
        "shells//zsh:zsh",
    ],
    visibility = ["PUBLIC"],
)

# Terminal packages
filegroup(
    name = "terminal-packages",
    srcs = [
        "terminals//alacritty:alacritty",
        "terminals//foot:foot",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "sys-apps-packages",
    srcs = [
        "system//apps/coreutils:coreutils",
        "system//apps/findutils:findutils",
        "system//apps/cronie:cronie",
        "system//apps/sudo:sudo",
        "system//apps/tmux:tmux",
        "system//apps/htop:htop",
        "system//apps/rsync:rsync",
        "system//apps/logrotate:logrotate",
        "system//apps/tar:tar",
        "system//apps/shadow:shadow",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "benchmark-packages",
    srcs = [
        "benchmarks//stress-ng:stress-ng",
        "benchmarks//fio:fio",
        "benchmarks//iperf3:iperf3",
        "benchmarks//hackbench:hackbench",
        "benchmarks//memtester:memtester",
    ],
    visibility = ["PUBLIC"],
)

# Terminal/shell libraries
filegroup(
    name = "shell-libs",
    srcs = [
        "core//readline:readline",
        "core//ncurses:ncurses",
        "core//less:less",
    ],
    visibility = ["PUBLIC"],
)

# Compression utilities
filegroup(
    name = "compression-packages",
    srcs = [
        "core//zlib:zlib",
        "core//bzip2:bzip2",
        "core//xz:xz",
        "system//libs/compression/gzip:gzip",
        "system//apps/tar:tar",
    ],
    visibility = ["PUBLIC"],
)

# Documentation packages
filegroup(
    name = "docs-packages",
    srcs = [
        "system//docs:man-db",
        "system//docs:texinfo",
        "system//docs:man-pages",
        "system//docs:groff",
    ],
    visibility = ["PUBLIC"],
)

# Internationalization packages
filegroup(
    name = "i18n-packages",
    srcs = [
        "dev-libs//misc/gettext:gettext",
    ],
    visibility = ["PUBLIC"],
)

# System monitoring utilities
filegroup(
    name = "system-packages",
    srcs = [
        "core//procps-ng:procps-ng",
        "core//file:file",
    ],
    visibility = ["PUBLIC"],
)

# Development libraries
filegroup(
    name = "dev-libraries",
    srcs = [
        "core//libffi:libffi",
        "core//expat:expat",
        "core//libnl:libnl",
    ],
    visibility = ["PUBLIC"],
)

# Init system packages
filegroup(
    name = "init-packages",
    srcs = [
        "system//init:systemd",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "init-lightweight",
    srcs = [
    ],
    visibility = ["PUBLIC"],
)

# =============================================================================
# Desktop environment aliases
# =============================================================================

# Full desktop environments
alias(
    name = "kde-plasma",
    actual = "desktop//kde:kde-plasma",
    visibility = ["PUBLIC"],
)

alias(
    name = "xfce",
    actual = "desktop//xfce:xfce",
    visibility = ["PUBLIC"],
)

alias(
    name = "lxqt",
    actual = "desktop//lxqt:lxqt",
    visibility = ["PUBLIC"],
)

alias(
    name = "cinnamon",
    actual = "desktop//cinnamon:cinnamon-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "mate",
    actual = "desktop//mate:mate",
    visibility = ["PUBLIC"],
)

alias(
    name = "budgie",
    actual = "desktop//budgie:budgie",
    visibility = ["PUBLIC"],
)

# Wayland compositors
alias(
    name = "sway",
    actual = "desktop//sway:sway-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "hyprland",
    actual = "desktop//hyprland:hyprland-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "wayfire",
    actual = "desktop//wayfire:wayfire-desktop",
    visibility = ["PUBLIC"],
)

# X11 window managers
alias(
    name = "i3",
    actual = "desktop//i3:i3-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "bspwm",
    actual = "desktop//bspwm:bspwm-desktop",
    visibility = ["PUBLIC"],
)

alias(
    name = "awesome",
    actual = "desktop//awesome:awesome-desktop",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Desktop package groups
# =============================================================================

filegroup(
    name = "desktop-foundation",
    srcs = [
        "//packages/linux/desktop:desktop-foundation",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "all-desktops",
    srcs = [
        "//packages/linux/desktop:all-desktops",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "wayland-compositors",
    srcs = [
        "//packages/linux/desktop:wayland-compositors",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "tiling-desktops",
    srcs = [
        "//packages/linux/desktop:tiling-desktops",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "monitoring-packages",
    srcs = [
        "system//apps/htop:htop",
        "system//apps/lsof:lsof",
        "system//apps/strace:strace",
        "core//procps-ng:procps-ng",
    ],
    visibility = ["PUBLIC"],
)

filegroup(
    name = "lightweight-desktops",
    srcs = [
        "//packages/linux/desktop:lightweight-desktops",
    ],
    visibility = ["PUBLIC"],
)

# =============================================================================
# Emulation and Virtualization aliases
# =============================================================================

# QEMU - Full system emulator
alias(
    name = "qemu",
    actual = "emulation//hypervisors/qemu:qemu",
    visibility = ["PUBLIC"],
)

# libvirt - Virtualization API
alias(
    name = "libvirt",
    actual = "emulation//virtualization/libvirt:libvirt",
    visibility = ["PUBLIC"],
)

# virt-manager - VM management GUI
alias(
    name = "virt-manager",
    actual = "emulation//virtualization/virt-manager:virt-manager",
    visibility = ["PUBLIC"],
)


# Docker
alias(
    name = "docker",
    actual = "emulation//containers:docker-full",
    visibility = ["PUBLIC"],
)

# Podman
alias(
    name = "podman",
    actual = "emulation//containers:podman-full",
    visibility = ["PUBLIC"],
)

# containerd
alias(
    name = "containerd",
    actual = "emulation//containers/containerd:containerd",
    visibility = ["PUBLIC"],
)

# Firecracker - Secure microVMs
alias(
    name = "firecracker",
    actual = "emulation//utilities/firecracker:firecracker",
    visibility = ["PUBLIC"],
)

# Cloud Hypervisor
alias(
    name = "cloud-hypervisor",
    actual = "emulation//utilities/cloud-hypervisor:cloud-hypervisor",
    visibility = ["PUBLIC"],
)

# crosvm - Chrome OS VMM
alias(
    name = "crosvm",
    actual = "emulation//utilities/crosvm:crosvm",
    visibility = ["PUBLIC"],
)

# virtme-ng - Fast kernel testing
alias(
    name = "virtme-ng",
    actual = "emulation//kernel/virtme-ng:virtme-ng",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Cloud Hypervisor Integration
# =============================================================================

# Cloud Hypervisor full stack (CH + virtiofsd + firmware)
alias(
    name = "ch-full",
    actual = "emulation//:cloud-hypervisor-full",
    visibility = ["PUBLIC"],
)

# Cloud Hypervisor minimal (CH + virtiofsd)
alias(
    name = "ch-minimal",
    actual = "emulation//:cloud-hypervisor-minimal",
    visibility = ["PUBLIC"],
)

# Cloud Hypervisor optimized kernel
alias(
    name = "kernel-ch",
    actual = "kernel//buckos-kernel:buckos-kernel-ch",
    visibility = ["PUBLIC"],
)

# Cloud Hypervisor firmware
alias(
    name = "hypervisor-fw",
    actual = "boot//rust-hypervisor-firmware:rust-hypervisor-firmware",
    visibility = ["PUBLIC"],
)

# Cloud Hypervisor UEFI firmware
alias(
    name = "edk2-cloudhv",
    actual = "boot//edk2-cloudhv:edk2-cloudhv",
    visibility = ["PUBLIC"],
)

# Cloud Hypervisor boot scripts
alias(
    name = "ch-boot-direct",
    actual = "boot//cloud-hypervisor-boot:ch-boot-direct",
    visibility = ["PUBLIC"],
)

alias(
    name = "ch-boot-virtiofs",
    actual = "boot//cloud-hypervisor-boot:ch-boot-virtiofs",
    visibility = ["PUBLIC"],
)

alias(
    name = "ch-boot-network",
    actual = "boot//cloud-hypervisor-boot:ch-boot-network",
    visibility = ["PUBLIC"],
)

# Cloud Hypervisor disk images
alias(
    name = "ch-disk-minimal",
    actual = "system//cloud-hypervisor:ch-minimal-disk",
    visibility = ["PUBLIC"],
)

alias(
    name = "ch-disk-full",
    actual = "system//cloud-hypervisor:ch-full-disk",
    visibility = ["PUBLIC"],
)

# =============================================================================
# Emulation package groups
# =============================================================================

# Essential virtualization (QEMU + libvirt + virt-manager)
filegroup(
    name = "emulation-essential",
    srcs = [
        "emulation//:essential",
    ],
    visibility = ["PUBLIC"],
)

# =============================================================================
# Container package groups
# =============================================================================

# Core container runtime
filegroup(
    name = "container-runtime",
    srcs = [
        "system//containers:container-runtime",
    ],
    visibility = ["PUBLIC"],
)

# Server virtualization
filegroup(
    name = "emulation-server",
    srcs = [
        "emulation//:server",
    ],
    visibility = ["PUBLIC"],
)

# Container networking
filegroup(
    name = "container-networking",
    srcs = [
        "system//containers:container-networking",
    ],
    visibility = ["PUBLIC"],
)

# Desktop virtualization (with GUI)
filegroup(
    name = "emulation-desktop",
    srcs = [
        "emulation//:desktop",
    ],
    visibility = ["PUBLIC"],
)

# Podman ecosystem tools
filegroup(
    name = "podman-tools",
    srcs = [
        "system//containers:podman-tools",
    ],
    visibility = ["PUBLIC"],
)

# Cloud/microVM hypervisors
filegroup(
    name = "emulation-cloud",
    srcs = [
        "emulation//:cloud",
    ],
    visibility = ["PUBLIC"],
)

# Container utilities and monitoring
filegroup(
    name = "container-utilities",
    srcs = [
        "system//containers:container-utilities",
    ],
    visibility = ["PUBLIC"],
)

# Development tools for kernel testing
filegroup(
    name = "emulation-development",
    srcs = [
        "emulation//:development",
    ],
    visibility = ["PUBLIC"],
)

# Container security tools
filegroup(
    name = "container-security",
    srcs = [
        "system//containers:container-security",
    ],
    visibility = ["PUBLIC"],
)

# Container runtimes
filegroup(
    name = "container-packages",
    srcs = [
        "emulation//containers:all-containers",
    ],
    visibility = ["PUBLIC"],
)

# All emulation packages
filegroup(
    name = "emulation-all",
    srcs = [
        "emulation//:all",
    ],
    visibility = ["PUBLIC"],
)

# Complete container stack
filegroup(
    name = "container-packages-complete",
    srcs = [
        "system//containers:all-containers",
    ],
    visibility = ["PUBLIC"],
)

# =============================================================================
# System Profile Sets
# =============================================================================

load("//defs:package_sets.bzl", "system_set", "combined_set", "task_set", "desktop_set", "package_set")

# Pre-configured system profiles
system_set(
    name = "system-minimal",
    profile = "minimal",
    description = "Minimal bootable system",
)

system_set(
    name = "system-server",
    profile = "server",
    description = "Standard server configuration",
)

system_set(
    name = "system-desktop",
    profile = "desktop",
    description = "Desktop system with GUI support",
)

system_set(
    name = "system-developer",
    profile = "developer",
    description = "Development workstation",
)

system_set(
    name = "system-hardened",
    profile = "hardened",
    description = "Security-hardened system",
)

system_set(
    name = "system-embedded",
    profile = "embedded",
    description = "Embedded/IoT system",
)

system_set(
    name = "system-container",
    profile = "container",
    description = "Container base image",
)

# =============================================================================
# Task-Specific Sets
# =============================================================================

task_set(
    name = "task-web-server",
    task = "web-server",
    description = "Web server configuration",
)

task_set(
    name = "task-database-server",
    task = "database-server",
    description = "Database server configuration",
)

task_set(
    name = "task-container-host",
    task = "container-host",
    description = "Container host system",
)

task_set(
    name = "task-virtualization-host",
    task = "virtualization-host",
    description = "Virtualization host system",
)

task_set(
    name = "task-vpn-server",
    task = "vpn-server",
    description = "VPN server configuration",
)

task_set(
    name = "task-monitoring",
    task = "monitoring",
    description = "System monitoring tools",
)

task_set(
    name = "task-benchmarking",
    task = "benchmarking",
    description = "Performance benchmarking tools",
)

# =============================================================================
# Desktop Environment Sets
# =============================================================================

desktop_set(
    name = "desktop-kde",
    environment = "kde-desktop",
    description = "KDE Plasma desktop environment",
)

desktop_set(
    name = "desktop-xfce",
    environment = "xfce-desktop",
    description = "XFCE desktop environment",
)

desktop_set(
    name = "desktop-sway",
    environment = "sway-desktop",
    description = "Sway Wayland compositor",
)

desktop_set(
    name = "desktop-hyprland",
    environment = "hyprland-desktop",
    description = "Hyprland Wayland compositor",
)

desktop_set(
    name = "desktop-i3",
    environment = "i3-desktop",
    description = "i3 tiling window manager",
)

# =============================================================================
# Combined Sets (Example Configurations)
# =============================================================================

# Full-stack web server with monitoring
combined_set(
    name = "full-stack-server",
    sets = ["@web-server", "@database-server", "@monitoring"],
    additions = [
        "network//vpn/wireguard-tools:wireguard-tools",
    ],
    description = "Complete web application server stack",
)

# DevOps workstation
combined_set(
    name = "devops-workstation",
    sets = ["@developer", "@container-host", "@monitoring"],
    description = "DevOps development workstation",
)

# Secure server with VPN
system_set(
    name = "secure-server",
    profile = "hardened",
    additions = [
        "network//vpn/wireguard-tools:wireguard-tools",
        "network//vpn/openvpn:openvpn",
    ],
    description = "Hardened server with VPN support",
)

# CI/CD runner
combined_set(
    name = "ci-runner",
    sets = ["@container-host"],
    additions = [
        "editors//vim",
    ],
    removals = [
        "system//docs:texinfo",
    ],
    description = "CI/CD runner with container support",
)

# Lightweight server (minimal + SSH)
system_set(
    name = "lightweight-server",
    profile = "minimal",
    additions = [
        "network//openssh:openssh",
        "editors//vim",
        "system//apps/sudo:sudo",
    ],
    description = "Lightweight server with SSH access",
)

# =============================================================================
# Validation Target
# =============================================================================
# Use this to validate all dependencies exist without building:
#   buck2 uquery 'deps("//...")' > /dev/null && echo "All deps valid"
#
# Note: Buck2 doesn't support //... as a dependency, so validation must be done
# via uquery. The command above will fail fast if any dependency doesn't exist.
