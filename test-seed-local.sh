#!/usr/bin/env bash
# Replicate the test-seed CI job locally in Docker.
#
# Usage:
#   ./test-seed-local.sh                        # build seed first, then test
#   ./test-seed-local.sh /path/to/seed.tar.zst  # use existing seed archive
#   SEED_DOCKER_SHELL=1 ./test-seed-local.sh    # drop to shell instead of running tests
#
# The seed archive is either:
#   1. Passed as $1
#   2. Built via buck2 build //tc/bootstrap:seed-export
#
# The Docker container mirrors ubuntu-latest (Ubuntu 24.04) with only
# zstd and buck2 installed — same as the CI runner.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SEED_ARCHIVE="${1:-}"

# ── Build seed if not provided ────────────────────────────────────────
if [[ -z "$SEED_ARCHIVE" ]]; then
    echo "==> Building seed toolchain..."
    buck2 build //tc/bootstrap:seed-export --out "$REPO_ROOT/seed-toolchain.tar.zst" 2>&1 \
        | tee /tmp/seed-build.log | tail -20
    SEED_ARCHIVE="$REPO_ROOT/seed-toolchain.tar.zst"
fi

if [[ ! -f "$SEED_ARCHIVE" ]]; then
    echo "ERROR: seed archive not found: $SEED_ARCHIVE" >&2
    exit 1
fi

# Resolve to absolute path
SEED_ARCHIVE="$(realpath "$SEED_ARCHIVE")"

echo "==> Using seed: $SEED_ARCHIVE"

# ── Run in Docker ─────────────────────────────────────────────────────
# Mount repo read-only, copy seed into container's workdir.
# This matches CI: checkout is fresh, seed is downloaded alongside it.

DOCKER_CMD='
set -euo pipefail

# Install minimal deps (matches CI)
# Match ubuntu-latest runner: python3, build-essential (gcc, make, libc6-dev)
apt-get update -qq && apt-get install -yqq zstd curl python3 build-essential udev >/dev/null 2>&1

# Install buck2 (matches CI)
mkdir -p "$HOME/.local/bin"
curl -sL https://github.com/facebook/buck2/releases/download/latest/buck2-x86_64-unknown-linux-gnu.zst \
    | zstd -d -f -o "$HOME/.local/bin/buck2"
chmod +x "$HOME/.local/bin/buck2"
export PATH="$HOME/.local/bin:$PATH"

echo "==> buck2 version: $(buck2 --version)"

# Copy repo to writable location, excluding build artifacts
tar -C /src --exclude='buck-out' --exclude='.buckconfig.local' --exclude='seed-toolchain.tar.zst' -cf - . | tar -C /work -xf -
cp /seed/seed-toolchain.tar.zst /work/

cd /work

# Configure seed (matches CI exactly)
printf "[buckos]\nseed_path = seed-toolchain.tar.zst\n" >> .buckconfig.local
tmpdir=$(mktemp -d)
buck2 init "$tmpdir"
printf "\n[cells]\n" >> .buckconfig.local
grep "none = none" "$tmpdir/.buckconfig" >> .buckconfig.local
sed -n "/^\[cell_aliases\]/,/^[[:space:]]*$/p" "$tmpdir/.buckconfig" >> .buckconfig.local

echo "==> .buckconfig.local:"
cat .buckconfig.local
echo ""

if [[ "${SEED_DOCKER_SHELL:-}" == "1" ]]; then
    echo "==> Dropping to shell. Run tests with:"
    echo "    buck2 test //tests: --exclude test-kde-iso-boot"
    exec bash
fi

echo "==> Running tests..."
buck2 test //tests: --exclude test-kde-iso-boot
'

SEED_DIR="$(dirname "$SEED_ARCHIVE")"
SEED_NAME="$(basename "$SEED_ARCHIVE")"

docker_args=(
    --rm
    -v "$REPO_ROOT:/src:ro"
    -v "$SEED_DIR:/seed:ro"
    -e "SEED_DOCKER_SHELL=${SEED_DOCKER_SHELL:-}"
)

# Propagate proxy environment variables into the container
for var in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
    if [[ -n "${!var:-}" ]]; then
        docker_args+=(-e "$var=${!var}")
    fi
done

# Mount KVM if available (needed for QEMU-based tests)
if [[ -e /dev/kvm ]]; then
    docker_args+=(--device /dev/kvm)
fi

# Interactive mode if dropping to shell
if [[ "${SEED_DOCKER_SHELL:-}" == "1" ]]; then
    docker_args+=(-it)
fi

exec docker run "${docker_args[@]}" \
    -w /work \
    ubuntu:24.04 \
    bash -c "$DOCKER_CMD"
