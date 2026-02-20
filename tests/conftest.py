from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest


def _find_repo_root() -> Path:
    """Walk up from this file looking for .buckroot."""
    d = Path(__file__).resolve().parent
    while d != d.parent:
        if (d / ".buckroot").exists():
            return d
        d = d.parent
    pytest.fail("Could not find .buckroot in any parent directory")


def _parse_uquery_labels(stdout: str) -> dict[str, list[str]]:
    """Parse buck2 uquery --output-attribute labels output into {target: [labels]}."""
    # Strip non-JSON lines (e.g. Build ID on stderr mixed in)
    lines = stdout.strip().splitlines()
    json_start = next((i for i, l in enumerate(lines) if l.strip().startswith("{")), None)
    if json_start is None:
        return {}
    json_text = "\n".join(lines[json_start:])
    try:
        data = json.loads(json_text)
    except json.JSONDecodeError:
        # Fallback: regex extraction
        result: dict[str, list[str]] = {}
        for m in re.finditer(
            r'"(root//[^"]+)":\s*\{[^}]*"labels":\s*\[([^\]]*)\]',
            stdout,
            re.DOTALL,
        ):
            target = m.group(1)
            labels = [s.strip().strip('"') for s in m.group(2).split(",") if s.strip()]
            result[target] = labels
        return result

    result = {}
    for target, attrs in data.items():
        result[target] = attrs.get("labels", [])
    return result


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return _find_repo_root()


@pytest.fixture(scope="session")
def buck2(repo_root: Path):
    """Callable wrapper: buck2("targets", "//...") -> CompletedProcess.

    Skips all tests if buck2 is not on PATH.
    """
    buck2_path = shutil.which("buck2")
    if buck2_path is None:
        pytest.skip("buck2 not found on PATH")

    def _run(*args: str, check: bool = True, timeout: int = 120) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["buck2", *args],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=check,
            timeout=timeout,
        )

    return _run


@pytest.fixture(scope="session")
def all_targets(buck2) -> list[str]:
    """Cached list of all targets from buck2 targets //..."""
    result = buck2("targets", "//...")
    targets = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return targets


@pytest.fixture(scope="session")
def all_target_labels(buck2) -> dict[str, list[str]]:
    """Cached mapping of target -> labels from buck2 uquery."""
    result = buck2(
        "uquery", "//...", "--output-attribute", "labels", "--json",
        timeout=120,
    )
    return _parse_uquery_labels(result.stdout)


@pytest.fixture(scope="session")
def ch_binary(buck2, repo_root: Path) -> Path:
    """Build cloud-hypervisor and return the binary path."""
    result = buck2(
        "build", "--show-output",
        "-c", "buckos.use_host_toolchain=true",
        "//packages/linux/emulation/utilities/cloud-hypervisor:cloud-hypervisor",
        timeout=900,
    )
    for line in result.stdout.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2 and ":cloud-hypervisor" in parts[0] and ":cloud-hypervisor-" not in parts[0]:
            return repo_root / parts[1]
    pytest.fail(f"Could not find CH binary in build output:\n{result.stdout}")


@pytest.fixture(scope="session")
def parsed_buck_targets(repo_root: Path):
    """AST-parsed target definitions from BUCK files under packages/."""
    from tests.buck_parser import parse_buck_files
    return parse_buck_files(repo_root / "packages")


class QemuVM:
    """Wrapper around a QEMU VM with serial console interaction."""

    def __init__(self, proc: subprocess.Popen, repo_root: Path):
        self._proc = proc
        self._repo_root = repo_root

    def run(self, cmd: str, timeout: int = 30) -> subprocess.CompletedProcess:
        """Execute a command inside the VM via serial console.

        Uses pexpect to send a command and capture output between
        known delimiters on the serial console.
        """
        import pexpect

        # Write command to stdin, read from stdout
        marker = f"__DONE_{id(cmd)}__"
        full_cmd = f"{cmd}; echo {marker} $?\n"
        self._proc.stdin.write(full_cmd.encode())
        self._proc.stdin.flush()

        # Read until marker appears
        output_lines = []
        import select
        import time

        deadline = time.monotonic() + timeout
        buf = b""
        while time.monotonic() < deadline:
            ready, _, _ = select.select([self._proc.stdout], [], [], 1.0)
            if ready:
                chunk = self._proc.stdout.read1(4096)
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    decoded = line.decode("utf-8", errors="replace").rstrip()
                    if marker in decoded:
                        # Extract return code
                        parts = decoded.split(marker)
                        rc_str = parts[-1].strip() if len(parts) > 1 else "0"
                        try:
                            rc = int(rc_str)
                        except ValueError:
                            rc = 1
                        stdout = "\n".join(output_lines)
                        return subprocess.CompletedProcess(
                            args=cmd, returncode=rc, stdout=stdout, stderr=""
                        )
                    output_lines.append(decoded)

        raise TimeoutError(f"Command timed out after {timeout}s: {cmd}")

    def close(self):
        self._proc.terminate()
        try:
            self._proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self._proc.kill()
            self._proc.wait()


@pytest.fixture(scope="session")
def qemu_vm(buck2, repo_root):
    """Boot a Fedora-compatible QEMU VM for integration testing.

    Builds the fedora QEMU boot target, then launches qemu-system-x86_64
    with serial console on stdio. Yields a QemuVM instance for running
    commands. Tears down the VM on cleanup.

    Marked slow — skipped by `make test-fast`.
    """
    pytest.importorskip("pexpect")

    # Build the boot script
    result = buck2(
        "build", "//packages/linux/system:qemu-boot-fedora",
        "-c", "use.fedora=true",
        "--show-full-output",
        timeout=600,
    )

    # Parse the boot script path from build output
    boot_script = None
    for line in result.stdout.splitlines():
        if "qemu-boot-fedora" in line:
            parts = line.strip().split(None, 1)
            if len(parts) == 2:
                boot_script = Path(parts[1])
                break

    if not boot_script or not boot_script.exists():
        pytest.skip("Could not build qemu-boot-fedora target")

    # Launch QEMU with serial on stdio, no display
    proc = subprocess.Popen(
        ["bash", str(boot_script)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=repo_root,
    )

    # Wait for shell prompt (up to 60s for boot)
    import time
    import select

    deadline = time.monotonic() + 60
    buf = b""
    booted = False
    while time.monotonic() < deadline:
        ready, _, _ = select.select([proc.stdout], [], [], 1.0)
        if ready:
            chunk = proc.stdout.read1(4096)
            if chunk:
                buf += chunk
                # Look for shell prompt indicators
                if b"#" in buf or b"$" in buf or b"login:" in buf:
                    booted = True
                    break

    if not booted:
        proc.terminate()
        proc.wait()
        pytest.skip("QEMU VM did not boot within 60s")

    vm = QemuVM(proc, repo_root)
    yield vm
    vm.close()
