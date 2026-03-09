#!/usr/bin/env python3
"""Rewrite padded ELF interpreters to point to a concrete ld-linux path.

Takes a directory of stage3 host tools (with padded ///...///lib64/ld-linux
interpreters from GCC specs) and rewrites them to point to the actual
buckos ld-linux at a known absolute path.  This makes the binaries
directly executable on the host without using the host's ld-linux.

Used by the host_tools_exec rule to produce host-runnable hermetic tools.
"""

import argparse
import os
import shutil
import struct
import stat
import sys


def _patch_elf_interpreter(path, new_interp_bytes):
    """Patch PT_INTERP in a 64-bit little-endian ELF to new_interp_bytes.

    Only patches interpreters with leading /// padding (from GCC specs).
    Returns True if patched.
    """
    try:
        with open(path, "rb") as f:
            data = bytearray(f.read())
    except (PermissionError, OSError):
        return False

    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        return False

    e_phoff = struct.unpack_from("<Q", data, 32)[0]
    e_phentsize = struct.unpack_from("<H", data, 54)[0]
    e_phnum = struct.unpack_from("<H", data, 56)[0]

    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if struct.unpack_from("<I", data, off)[0] != 3:  # PT_INTERP
            continue

        p_offset = struct.unpack_from("<Q", data, off + 8)[0]
        p_filesz = struct.unpack_from("<Q", data, off + 32)[0]

        end = data.find(0, p_offset, p_offset + p_filesz)
        if end < 0:
            end = p_offset + p_filesz
        old_interp = data[p_offset:end]

        # Only rewrite padded interpreters (from GCC specs)
        if not old_interp.startswith(b"///"):
            return False

        if len(new_interp_bytes) <= p_filesz:
            data[p_offset:p_offset + len(new_interp_bytes)] = new_interp_bytes
            for j in range(len(new_interp_bytes), p_filesz):
                data[p_offset + j] = 0
        else:
            # Append to end of file
            new_offset = len(data)
            data.extend(new_interp_bytes)
            struct.pack_into("<Q", data, off + 8, new_offset)
            struct.pack_into("<Q", data, off + 32, len(new_interp_bytes))
            struct.pack_into("<Q", data, off + 40, len(new_interp_bytes))

        orig_mode = os.stat(path).st_mode
        os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)
        with open(path, "wb") as f:
            f.write(data)
        os.chmod(path, orig_mode)
        return True

    return False


def main():
    parser = argparse.ArgumentParser(
        description="Copy host tools and rewrite ELF interpreters")
    parser.add_argument("--tools-dir", required=True,
                        help="Input stage3 host tools directory (merged FHS tree)")
    parser.add_argument("--ld-linux", required=True,
                        help="Path to buckos ld-linux-x86-64.so.2 (sysroot artifact)")
    parser.add_argument("--output-dir", required=True,
                        help="Output directory")
    args = parser.parse_args()

    tools_dir = os.path.abspath(args.tools_dir)
    output_dir = os.path.abspath(args.output_dir)
    ld_linux = os.path.abspath(args.ld_linux)

    if not os.path.isdir(tools_dir):
        print(f"error: tools dir not found: {tools_dir}", file=sys.stderr)
        sys.exit(1)

    if not os.path.isfile(ld_linux):
        print(f"error: ld-linux not found: {ld_linux}", file=sys.stderr)
        sys.exit(1)

    # Copy the entire tools directory tree
    shutil.copytree(tools_dir, output_dir, symlinks=True,
                    dirs_exist_ok=True)

    # Rewrite padded interpreters to the actual buckos ld-linux path
    new_interp = ld_linux.encode("ascii") + b"\x00"
    patched = 0
    for dirpath, _, filenames in os.walk(output_dir):
        for name in filenames:
            fpath = os.path.join(dirpath, name)
            if os.path.islink(fpath) or not os.path.isfile(fpath):
                continue
            try:
                with open(fpath, "rb") as f:
                    if f.read(4) != b"\x7fELF":
                        continue
            except (PermissionError, OSError):
                continue
            if _patch_elf_interpreter(fpath, new_interp):
                patched += 1

    print(f"Rewrote interpreter in {patched} binaries -> {ld_linux}",
          file=sys.stderr)

    # Rewrite script shebangs containing buck-out paths.  Build-time
    # shebangs like #!/.../buck-out/.../bash become stale when the remote
    # cache restores actions on a different machine.  Replace with
    # #!/usr/bin/env <interpreter> so scripts find tools via PATH.
    rewritten = 0
    for dirpath, _, filenames in os.walk(output_dir):
        for name in filenames:
            fpath = os.path.join(dirpath, name)
            if os.path.islink(fpath) or not os.path.isfile(fpath):
                continue
            try:
                with open(fpath, "rb") as f:
                    first = f.read(2)
                    if first != b"#!":
                        continue
                    line = first + f.readline()
            except (PermissionError, OSError):
                continue
            shebang = line.decode("utf-8", errors="replace").strip()
            if "buck-out" not in shebang:
                continue
            # Extract interpreter basename (e.g. bash, perl, python3)
            interp_path = shebang[2:].strip().split()[0]
            interp_name = os.path.basename(interp_path)
            if not interp_name:
                continue
            try:
                with open(fpath, "r") as f:
                    content = f.read()
                orig_mode = os.stat(fpath).st_mode
                os.chmod(fpath, stat.S_IRUSR | stat.S_IWUSR)
                with open(fpath, "w") as f:
                    f.write(f"#!/usr/bin/env {interp_name}\n")
                    f.write(content[content.index("\n") + 1:])
                os.chmod(fpath, orig_mode)
                rewritten += 1
            except (ValueError, OSError):
                continue
    if rewritten:
        print(f"Rewrote {rewritten} script shebangs (buck-out -> /usr/bin/env)",
              file=sys.stderr)

    # Cross-link lib/ and lib64/ so RPATH entries for either directory
    # resolve all shared libraries.  Some binaries (e.g. librustc_driver)
    # have RUNPATH=$ORIGIN/../lib while others search lib64/.  The linker
    # also needs rpath-link to resolve DT_NEEDED chains across both dirs.
    _cross_link_lib_dirs(output_dir)


def _cross_link_lib_dirs(output_dir):
    """Create bidirectional symlinks between lib/ and lib64/.

    Ensures shared libraries are discoverable from both directories.
    Only creates symlinks for files missing from one side — real files
    and existing symlinks are never overwritten.
    """
    lib_dir = os.path.join(output_dir, "lib")
    lib64_dir = os.path.join(output_dir, "lib64")

    # Never cross-link libc.so.6 — derive_lib_paths uses its presence
    # as a sentinel to exclude directories from LD_LIBRARY_PATH (to
    # prevent poisoning host processes with buckos glibc).  Symlinking
    # it into lib/ causes both dirs to be excluded, breaking transitive
    # DT_NEEDED resolution for the linker.
    _GLIBC_SKIP = {"libc.so.6"}

    linked = 0
    for src_dir, dst_dir, label in [
        (lib64_dir, lib_dir, "lib/ -> lib64/"),
        (lib_dir, lib64_dir, "lib64/ -> lib/"),
    ]:
        if not os.path.isdir(src_dir):
            continue
        os.makedirs(dst_dir, exist_ok=True)
        for name in os.listdir(src_dir):
            if name in _GLIBC_SKIP:
                continue
            dst_path = os.path.join(dst_dir, name)
            if not os.path.exists(dst_path) and not os.path.islink(dst_path):
                src_path = os.path.join(src_dir, name)
                # Only symlink files, not directories
                if os.path.isfile(src_path) or os.path.islink(src_path):
                    os.symlink(os.path.relpath(src_path, dst_dir), dst_path)
                    linked += 1

    if linked:
        print(f"Created {linked} lib/ <-> lib64/ cross-symlinks",
              file=sys.stderr)


if __name__ == "__main__":
    main()
