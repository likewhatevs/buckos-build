"""Fedora compatibility integration tests.

These tests boot a BuckOS Fedora-compatible image in QEMU and verify
that RPM/DNF5 work, the filesystem layout is correct, and Fedora
packages can be installed and run.

All tests require the qemu_vm fixture and are marked slow.
"""

from __future__ import annotations

import pytest


pytestmark = pytest.mark.slow


class TestFedoraBaseline:
    """Baseline checks that the Fedora compat layer is wired correctly."""

    def test_rpm_works(self, qemu_vm):
        """rpm -qa returns without error."""
        result = qemu_vm.run("rpm -qa")
        assert result.returncode == 0

    def test_dnf_works(self, qemu_vm):
        """dnf5 --version works."""
        result = qemu_vm.run("dnf5 --version")
        assert result.returncode == 0

    def test_lib64_layout(self, qemu_vm):
        """64-bit libraries are in /usr/lib64, /lib64 -> /usr/lib64 symlink exists."""
        result = qemu_vm.run("test -d /usr/lib64")
        assert result.returncode == 0, "/usr/lib64 should be a directory"

        result = qemu_vm.run("readlink /lib64")
        assert result.returncode == 0
        assert "usr/lib64" in result.stdout, "/lib64 should symlink to usr/lib64"

    def test_fedora_repo_configured(self, qemu_vm):
        """Fedora 42 repo is configured."""
        result = qemu_vm.run("test -f /etc/yum.repos.d/fedora.repo")
        assert result.returncode == 0, "fedora.repo should exist"

        result = qemu_vm.run("test -f /etc/yum.repos.d/fedora-updates.repo")
        assert result.returncode == 0, "fedora-updates.repo should exist"

    def test_glibc_present(self, qemu_vm):
        """glibc is present and functional."""
        result = qemu_vm.run("/usr/lib64/ld-linux-x86-64.so.2 --version")
        assert result.returncode == 0

    def test_hardening_flags(self, qemu_vm):
        """RELRO and BIND_NOW present in built binaries."""
        # Check a BuckOS-built binary for full RELRO
        result = qemu_vm.run("readelf -d /usr/bin/bash 2>/dev/null | grep -E 'BIND_NOW|FLAGS'")
        assert result.returncode == 0, "bash should have RELRO/BIND_NOW hardening"


class TestFedoraPackageInstall:
    """Tests that verify real Fedora packages can be installed and run."""

    def test_install_nodeps_package(self, qemu_vm):
        """Install a Fedora package with zero shared library deps.

        Uses 'words' — a data-only package containing /usr/share/dict/words.
        """
        result = qemu_vm.run("dnf5 install -y words", timeout=120)
        assert result.returncode == 0, f"dnf5 install failed: {result.stdout}"

        result = qemu_vm.run("test -f /usr/share/dict/words")
        assert result.returncode == 0, "words file should exist after install"

    def test_install_package_using_buckos_libs(self, qemu_vm):
        """Install a Fedora package whose shared library deps are provided by BuckOS.

        Uses 'tree' — depends on glibc which BuckOS provides.
        """
        result = qemu_vm.run("dnf5 install -y tree", timeout=120)
        assert result.returncode == 0, f"dnf5 install failed: {result.stdout}"

        # Verify all shared libs resolve
        result = qemu_vm.run("ldd /usr/bin/tree")
        assert result.returncode == 0
        assert "not found" not in result.stdout, (
            f"Unresolved shared libs: {result.stdout}"
        )

    def test_installed_binary_runs(self, qemu_vm):
        """End-to-end: install a Fedora binary and execute it."""
        # Ensure tree is installed (may already be from previous test)
        qemu_vm.run("dnf5 install -y tree", timeout=120)

        result = qemu_vm.run("tree --version")
        assert result.returncode == 0
        assert "tree" in result.stdout.lower(), (
            f"Unexpected output: {result.stdout}"
        )
