#!/bin/bash
# generate-qemu-script.sh — external generator for QEMU boot/run/test scripts.
# Receives artifact paths as positional args (resolved by buck2),
# string config via env vars.  Writes the boot .sh directly.
set -e

OUTPUT="$1"
MODE="$2"          # "interactive" or "cmd"
KERNEL_DIR="$3"
INITRAMFS="$4"

: "${QEMU_ARCH:=x86_64}"
: "${QEMU_MEMORY:=512M}"
: "${QEMU_CPUS:=2}"
: "${QEMU_KERNEL_ARGS:=console=ttyS0 quiet}"
: "${QEMU_EXTRA_ARGS:=}"
: "${QEMU_TIMEOUT:=120}"

# Determine binary and machine type from arch
case "$QEMU_ARCH" in
    aarch64)  QEMU_BIN="qemu-system-aarch64"; MACHINE="virt" ;;
    riscv64)  QEMU_BIN="qemu-system-riscv64"; MACHINE="virt" ;;
    *)        QEMU_BIN="qemu-system-x86_64";  MACHINE="q35"  ;;
esac

# --- Preamble (no expansion — literal bash for the output script) ---

cat > "$OUTPUT" << 'PREAMBLE'
#!/bin/bash
set -e
unset CDPATH

# Find project root by locating buck-out directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
while [ "$PROJECT_ROOT" != "/" ]; do
    if [ -d "$PROJECT_ROOT/buck-out" ] && [ -f "$PROJECT_ROOT/.buckroot" -o -f "$PROJECT_ROOT/.buckconfig" ]; then
        break
    fi
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

if [ "$PROJECT_ROOT" = "/" ]; then
    PROJECT_ROOT="$SCRIPT_DIR"
    while [[ "$PROJECT_ROOT" == *"/buck-out/"* ]]; do
        PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
    done
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
fi

cd "$PROJECT_ROOT"
PREAMBLE

# --- Kernel search (expanded at generation time) ---

cat >> "$OUTPUT" << EOF

KERNEL_DIR="$KERNEL_DIR"
INITRAMFS="$INITRAMFS"

# Find kernel image
KERNEL=""
for k in "\$KERNEL_DIR/boot/vmlinuz"* "\$KERNEL_DIR/boot/bzImage" "\$KERNEL_DIR/vmlinuz"*; do
    if [ -f "\$k" ]; then
        KERNEL="\$k"
        break
    fi
done

if [ -z "\$KERNEL" ]; then
    echo "Error: Cannot find kernel image in \$KERNEL_DIR"
    exit 1
fi
EOF

# --- Mode-specific body ---

case "$MODE" in
    interactive)
        cat >> "$OUTPUT" << EOF

echo "Booting BuckOs with QEMU..."
echo "  Kernel: \$KERNEL"
echo "  Initramfs: \$INITRAMFS"
echo ""
echo "Press Ctrl-A X to exit QEMU"
echo ""

$QEMU_BIN \\
    -machine $MACHINE \\
    -m $QEMU_MEMORY \\
    -smp $QEMU_CPUS \\
    -kernel "\$KERNEL" \\
    -initrd "\$INITRAMFS" \\
    -append "$QEMU_KERNEL_ARGS" \\
    -nographic \\
    -no-reboot \\
    $QEMU_EXTRA_ARGS \\
    "\$@"
EOF
        ;;

    cmd)
        cat >> "$OUTPUT" << EOF

OUTPUT_LOG=\$(timeout $QEMU_TIMEOUT $QEMU_BIN \\
    -machine $MACHINE \\
    -m $QEMU_MEMORY \\
    -smp $QEMU_CPUS \\
    -kernel "\$KERNEL" \\
    -initrd "\$INITRAMFS" \\
    -append "$QEMU_KERNEL_ARGS" \\
    -nographic \\
    -no-reboot \\
    -serial stdio \\
    -monitor none \\
    $QEMU_EXTRA_ARGS \\
    2>&1) || true

echo "\$OUTPUT_LOG"
RC=\$(echo "\$OUTPUT_LOG" | grep -oP '===QEMU_RC=\K\d+(?====)' | tail -1)
exit \${RC:-1}
EOF
        ;;

    *)
        echo "Error: Unknown mode: $MODE" >&2
        exit 1
        ;;
esac

chmod +x "$OUTPUT"
