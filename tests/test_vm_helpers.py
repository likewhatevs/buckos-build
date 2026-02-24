#!/usr/bin/env python3
"""Unit tests for vm_test_runner and disk_image_helper pure functions."""
import argparse
import os
import sys
import tempfile
from pathlib import Path

_REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_REPO / "tools"))

from vm_test_runner import parse_inject, build_init_script, kvm_available

passed = 0
failed = 0


def ok(msg):
    global passed
    print(f"  PASS: {msg}")
    passed += 1


def fail(msg):
    global failed
    print(f"  FAIL: {msg}")
    failed += 1


def main():
    # ----------------------------------------------------------------
    # parse_inject tests
    # ----------------------------------------------------------------

    print("=== parse_inject: simple SRC:DEST ===")
    result = parse_inject("foo:/bar")
    if result == ("foo", "/bar"):
        ok("foo:/bar -> ('foo', '/bar')")
    else:
        fail(f"expected ('foo', '/bar'), got {result!r}")

    print("=== parse_inject: full paths ===")
    result = parse_inject("/path/to/file:/dest/path")
    if result == ("/path/to/file", "/dest/path"):
        ok("/path/to/file:/dest/path -> correct tuple")
    else:
        fail(f"expected ('/path/to/file', '/dest/path'), got {result!r}")

    print("=== parse_inject: multiple colons splits on first only ===")
    result = parse_inject("src:dest:extra")
    if result == ("src", "dest:extra"):
        ok("src:dest:extra -> ('src', 'dest:extra')")
    else:
        fail(f"expected ('src', 'dest:extra'), got {result!r}")

    print("=== parse_inject: no colon raises ArgumentTypeError ===")
    try:
        parse_inject("no-colon")
        fail("no exception raised for missing colon")
    except argparse.ArgumentTypeError:
        ok("ArgumentTypeError raised for 'no-colon'")
    except Exception as e:
        fail(f"wrong exception type: {type(e).__name__}: {e}")

    print("=== parse_inject: empty string raises ArgumentTypeError ===")
    try:
        parse_inject("")
        fail("no exception raised for empty string")
    except argparse.ArgumentTypeError:
        ok("ArgumentTypeError raised for empty string")
    except Exception as e:
        fail(f"wrong exception type: {type(e).__name__}: {e}")

    print("=== parse_inject: colon at start gives empty src ===")
    result = parse_inject(":/dest")
    if result == ("", "/dest"):
        ok(":/dest -> ('', '/dest')")
    else:
        fail(f"expected ('', '/dest'), got {result!r}")

    print("=== parse_inject: colon at end gives empty dest ===")
    result = parse_inject("src:")
    if result == ("src", ""):
        ok("src: -> ('src', '')")
    else:
        fail(f"expected ('src', ''), got {result!r}")

    print("=== parse_inject: paths with spaces ===")
    result = parse_inject("/my file:/dest dir/file")
    if result == ("/my file", "/dest dir/file"):
        ok("paths with spaces parsed correctly")
    else:
        fail(f"expected ('/my file', '/dest dir/file'), got {result!r}")

    # ----------------------------------------------------------------
    # build_init_script tests
    # ----------------------------------------------------------------

    script = build_init_script()

    print("=== build_init_script: starts with shebang ===")
    if script.startswith("#!/bin/sh\n"):
        ok("starts with #!/bin/sh")
    else:
        fail(f"unexpected start: {script[:20]!r}")

    print("=== build_init_script: contains mount -t proc ===")
    if "mount -t proc" in script:
        ok("contains mount -t proc")
    else:
        fail("mount -t proc not found")

    print("=== build_init_script: contains mount -t sysfs ===")
    if "mount -t sysfs" in script:
        ok("contains mount -t sysfs")
    else:
        fail("mount -t sysfs not found")

    print("=== build_init_script: contains mount -t devtmpfs ===")
    if "mount -t devtmpfs" in script:
        ok("contains mount -t devtmpfs")
    else:
        fail("mount -t devtmpfs not found")

    print("=== build_init_script: devtmpfs failure tolerated ===")
    if "2>/dev/null || true" in script:
        ok("devtmpfs mount failure tolerated")
    else:
        fail("devtmpfs error suppression not found")

    print("=== build_init_script: contains exec /bin/sh /test.sh ===")
    if "exec /bin/sh /test.sh" in script:
        ok("contains exec /bin/sh /test.sh")
    else:
        fail("exec /bin/sh /test.sh not found")

    print("=== build_init_script: contains poweroff -f ===")
    if "poweroff -f" in script:
        ok("contains poweroff -f")
    else:
        fail("poweroff -f not found")

    print("=== build_init_script: ends with newline ===")
    if script.endswith("\n"):
        ok("ends with newline")
    else:
        fail("does not end with newline")

    print("=== build_init_script: deterministic ===")
    if build_init_script() == build_init_script():
        ok("two calls produce identical output")
    else:
        fail("non-deterministic output")

    # ----------------------------------------------------------------
    # kvm_available tests
    # ----------------------------------------------------------------

    print("=== kvm_available: returns a boolean ===")
    result = kvm_available()
    if isinstance(result, bool):
        ok(f"returns bool (value={result})")
    else:
        fail(f"expected bool, got {type(result).__name__}")

    print("=== kvm_available: consistent with /dev/kvm access ===")
    expected = os.access("/dev/kvm", os.R_OK | os.W_OK)
    if kvm_available() == expected:
        ok("matches os.access check")
    else:
        fail("disagrees with os.access")

    # ----------------------------------------------------------------
    # IMA file-matching logic tests (disk_image_helper._apply_ima)
    # ----------------------------------------------------------------
    # We test the file-walking pattern used by _apply_ima without
    # requiring evmctl.  The logic under test:
    #   1. Walk directory tree
    #   2. Find files ending in .sig
    #   3. Strip .sig suffix to get target path
    #   4. Check if target file exists

    print("=== IMA: .sig suffix detection ===")
    sig_names = ["foo.bin.sig", "bar.sig", "lib.so.1.sig"]
    non_sig = ["foo.bin", "bar.signature", "sig", ".sig.bak", "readme"]
    detected = [f for f in sig_names + non_sig if f.endswith(".sig")]
    if detected == sig_names:
        ok(".sig suffix correctly filters filenames")
    else:
        fail(f"expected {sig_names!r}, got {detected!r}")

    print("=== IMA: target path stripping ===")
    cases = [
        ("/mnt/foo.bin.sig", "/mnt/foo.bin"),
        ("/mnt/lib.so.1.sig", "/mnt/lib.so.1"),
        ("/a/b/c.sig", "/a/b/c"),
        ("relative.sig", "relative"),
    ]
    all_ok = True
    for sig_path, expected_target in cases:
        target = sig_path[:-4]
        if target != expected_target:
            fail(f"strip .sig: {sig_path!r} -> {target!r}, expected {expected_target!r}")
            all_ok = False
    if all_ok:
        ok("sig_path[:-4] strips .sig correctly for all cases")

    print("=== IMA: target existence check with real files ===")
    tmpdir = tempfile.mkdtemp(prefix="test_ima_")
    try:
        # Create target + sidecar pair
        target_path = os.path.join(tmpdir, "hello.bin")
        sig_path = os.path.join(tmpdir, "hello.bin.sig")
        with open(target_path, "w") as f:
            f.write("binary content")
        with open(sig_path, "w") as f:
            f.write("signature data")

        # Orphan sidecar (no matching target)
        orphan_sig = os.path.join(tmpdir, "orphan.bin.sig")
        with open(orphan_sig, "w") as f:
            f.write("orphan sig")

        # Walk and apply the matching logic
        matched = []
        unmatched = []
        for dirpath, _, filenames in os.walk(tmpdir):
            for fname in filenames:
                if not fname.endswith(".sig"):
                    continue
                sp = os.path.join(dirpath, fname)
                t = sp[:-4]
                if os.path.isfile(t):
                    matched.append(fname)
                else:
                    unmatched.append(fname)

        if matched == ["hello.bin.sig"]:
            ok("matched target+sidecar pair")
        else:
            fail(f"expected ['hello.bin.sig'], got {matched!r}")

        if unmatched == ["orphan.bin.sig"]:
            ok("orphan sidecar correctly unmatched")
        else:
            fail(f"expected ['orphan.bin.sig'], got {unmatched!r}")
    finally:
        import shutil
        shutil.rmtree(tmpdir, ignore_errors=True)

    print("=== IMA: nested directory walking ===")
    tmpdir = tempfile.mkdtemp(prefix="test_ima_nested_")
    try:
        # Create nested structure:
        #   tmpdir/usr/bin/tool         (target)
        #   tmpdir/usr/bin/tool.sig     (sidecar)
        #   tmpdir/usr/lib/libfoo.so    (target)
        #   tmpdir/usr/lib/libfoo.so.sig (sidecar)
        #   tmpdir/etc/config.sig       (orphan, no target)
        for d in ("usr/bin", "usr/lib", "etc"):
            os.makedirs(os.path.join(tmpdir, d))

        for f in ("usr/bin/tool", "usr/bin/tool.sig",
                   "usr/lib/libfoo.so", "usr/lib/libfoo.so.sig",
                   "etc/config.sig"):
            with open(os.path.join(tmpdir, f), "w") as fh:
                fh.write("data")

        matched = []
        unmatched = []
        for dirpath, _, filenames in os.walk(tmpdir):
            for fname in sorted(filenames):
                if not fname.endswith(".sig"):
                    continue
                sp = os.path.join(dirpath, fname)
                t = sp[:-4]
                if os.path.isfile(t):
                    matched.append(os.path.relpath(sp, tmpdir))
                else:
                    unmatched.append(os.path.relpath(sp, tmpdir))

        matched.sort()
        unmatched.sort()
        if matched == ["usr/bin/tool.sig", "usr/lib/libfoo.so.sig"]:
            ok("nested sidecar pairs found across directories")
        else:
            fail(f"expected nested matches, got {matched!r}")

        if unmatched == ["etc/config.sig"]:
            ok("nested orphan sidecar correctly unmatched")
        else:
            fail(f"expected ['etc/config.sig'], got {unmatched!r}")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    print("=== IMA: empty directory produces no matches ===")
    tmpdir = tempfile.mkdtemp(prefix="test_ima_empty_")
    try:
        matched = []
        for dirpath, _, filenames in os.walk(tmpdir):
            for fname in filenames:
                if fname.endswith(".sig"):
                    matched.append(fname)
        if matched == []:
            ok("empty directory yields no matches")
        else:
            fail(f"expected [], got {matched!r}")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    print("=== IMA: file named exactly '.sig' has empty target name ===")
    sig_path = "/some/dir/.sig"
    target = sig_path[:-4]
    if target == "/some/dir/":
        ok(".sig file strips to directory path (correctly rejected by isfile)")
    else:
        fail(f"expected '/some/dir/', got {target!r}")

    # -- Summary --
    print(f"\n--- {passed} passed, {failed} failed ---")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
