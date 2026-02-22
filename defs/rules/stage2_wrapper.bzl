"""
Stage 2 wrapper rule: creates wrapper scripts to run Stage 2 native binaries on the host.

Stage 2 builds native binaries that are linked against the BuckOS sysroot's glibc.
These can't run directly on the host (wrong libc). This rule creates wrapper scripts
that invoke the sysroot's dynamic linker (ld-linux-x86-64.so.2) explicitly with
LD_LIBRARY_PATH pointing to sysroot libs.

Wrapper pattern:
    #!/bin/bash
    SYSROOT="<path-to-stage2-sysroot>"
    LD_LIBRARY_PATH="$SYSROOT/usr/lib64:$SYSROOT/lib64" \
      exec "$SYSROOT/lib64/ld-linux-x86-64.so.2" \
      --library-path "$LD_LIBRARY_PATH" \
      "<stage2-binary>" "$@"
"""

load("//defs:providers.bzl", "BootstrapStageInfo")

TARGET_TRIPLE = "x86_64-buckos-linux-gnu"

def _stage2_wrapper_impl(ctx):
    stage2 = ctx.attrs.stage2[BootstrapStageInfo]
    stage2_output = ctx.attrs.stage2[DefaultInfo].default_outputs[0]

    # Output directory for wrapper scripts
    output = ctx.actions.declare_output("wrappers", dir = True)

    # Create a script that generates all the wrappers
    script = cmd_args("/bin/bash", "-ce")
    script_body = cmd_args(
        "PROJECT_ROOT=$PWD && ",
        delimiter = "",
    )
    script_body.add(cmd_args(
        "STAGE2_DIR=$PROJECT_ROOT/", stage2_output, " && ",
        delimiter = "",
    ))
    script_body.add(cmd_args(
        "OUTPUT_DIR=$PROJECT_ROOT/", output.as_output(), " && ",
        delimiter = "",
    ))

    # Create directory structure matching stage2
    script_body.add(
        "mkdir -p $OUTPUT_DIR/tools/bin && " +
        "mkdir -p $OUTPUT_DIR/tools/" + TARGET_TRIPLE + "/sys-root && ",
    )

    # Create a symlink to the sysroot (so the compiler can find headers/libs)
    script_body.add(
        "ln -sfn $STAGE2_DIR/tools/" + TARGET_TRIPLE + "/sys-root/* $OUTPUT_DIR/tools/" + TARGET_TRIPLE + "/sys-root/ 2>/dev/null || " +
        "cp -a $STAGE2_DIR/tools/" + TARGET_TRIPLE + "/sys-root/. $OUTPUT_DIR/tools/" + TARGET_TRIPLE + "/sys-root/ && ",
    )

    # Generate wrapper for each tool in tools/bin
    script_body.add("""
for tool in $STAGE2_DIR/tools/bin/*; do
    if [ -f "$tool" ] && [ -x "$tool" ]; then
        name=$(basename "$tool")
        wrapper=$OUTPUT_DIR/tools/bin/$name

        # Check if it's a real binary (ELF) or a script/symlink
        if file "$tool" 2>/dev/null | grep -q "ELF"; then
            # Create wrapper script for ELF binaries
            cat > "$wrapper" << 'WRAPPER_EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYSROOT="${SCRIPT_DIR}/../""" + TARGET_TRIPLE + """/sys-root"
TOOL_NAME="$(basename "$0")"
REAL_TOOL="${SCRIPT_DIR}/../../.stage2-real/tools/bin/${TOOL_NAME}"

# Library paths for the dynamic linker
LIB_PATH="$SYSROOT/usr/lib64:$SYSROOT/lib64:$SYSROOT/usr/lib:$SYSROOT/lib"

# Invoke the sysroot's dynamic linker to run the stage2 binary
exec "$SYSROOT/lib64/ld-linux-x86-64.so.2" \\
    --library-path "$LIB_PATH" \\
    "$REAL_TOOL" "$@"
WRAPPER_EOF
            chmod +x "$wrapper"
        else
            # For scripts and symlinks, create a passthrough wrapper
            ln -sfn "$tool" "$wrapper" 2>/dev/null || cp "$tool" "$wrapper"
        fi
    fi
done && """,
    )

    # Create .stage2-real symlink pointing to actual stage2 output
    script_body.add(
        "ln -sfn $STAGE2_DIR $OUTPUT_DIR/.stage2-real && ",
    )

    script_body.add("true")
    script.add(script_body)
    ctx.actions.run(script, category = "create_wrappers", identifier = ctx.attrs.name)

    # Return BootstrapStageInfo with wrapper paths
    return [
        DefaultInfo(default_output = output),
        BootstrapStageInfo(
            stage = 2,
            cc = output.project("tools/bin/" + TARGET_TRIPLE + "-gcc"),
            cxx = output.project("tools/bin/" + TARGET_TRIPLE + "-g++"),
            ar = output.project("tools/bin/" + TARGET_TRIPLE + "-ar"),
            sysroot = output.project("tools/" + TARGET_TRIPLE + "/sys-root"),
            target_triple = TARGET_TRIPLE,
            python = None,
            python_version = None,
        ),
    ]

stage2_wrapper = rule(
    impl = _stage2_wrapper_impl,
    attrs = {
        "stage2": attrs.dep(providers = [BootstrapStageInfo]),
    },
)
