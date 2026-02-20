#!/bin/bash
# generate-qemu-overlay.sh — create an overlay cpio containing /init.
# The /init runs a user command, reports exit code via serial, and powers off.
#
# Positional args (artifact paths resolved by buck2):
#   $1  output cpio path
#
# Env vars (string config):
#   QEMU_CMD        command to run
#   QEMU_NET        "true" to bring up networking before command
set -e

OUTPUT="$1"

: "${QEMU_CMD:=}"
: "${QEMU_NET:=false}"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# Build /init script
cat > "$WORKDIR/init" << 'INIT_HEADER'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /dev/pts && mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /run
INIT_HEADER

if [ "$QEMU_NET" = "true" ]; then
    cat >> "$WORKDIR/init" << 'NET_BLOCK'
ip link set lo up
ip link set eth0 up 2>/dev/null || true
dhcpcd eth0 2>/dev/null || udhcpc -i eth0 2>/dev/null || true
sleep 2
NET_BLOCK
fi

cat >> "$WORKDIR/init" << INIT_CMD
$QEMU_CMD
RC=\$?
echo "===QEMU_RC=\$RC==="
sync
poweroff -f
INIT_CMD

chmod +x "$WORKDIR/init"

# Build uncompressed cpio archive
(cd "$WORKDIR" && echo init | cpio -o -H newc 2>/dev/null) > "$OUTPUT"
