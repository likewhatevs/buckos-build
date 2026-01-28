# Download Tools Quick Start

## Generate Download Script

```bash
# Basic: Generate to stdout
./scripts/generate-download-script.py

# Save to file
./scripts/generate-download-script.py --output download-all.sh

# Custom download directory
./scripts/generate-download-script.py \
    --output download-all.sh \
    --output-dir /var/www/buckos-mirror

# Skip checksum verification (for unstable URLs)
./scripts/generate-download-script.py \
    --output download-all.sh \
    --skip-verification

# Use wget instead of curl
./scripts/generate-download-script.py \
    --output download-all.sh \
    --wget

# Slower rate for respectful mirroring
./scripts/generate-download-script.py \
    --output download-all.sh \
    --rate-limit 2.0
```

## Run Generated Script

```bash
# Run with default settings
bash download-all.sh

# Override download directory
OUTPUT_DIR=/path/to/mirror bash download-all.sh

# Edit the script to change OUTPUT_DIR permanently
nano download-all.sh
# Change: OUTPUT_DIR="downloads"
# To:     OUTPUT_DIR="/your/path"
```

## Python Downloader (Interactive)

```bash
# Basic usage
./scripts/download-all-sources.py --output-dir /path/to/mirror

# Fast download (more workers)
./scripts/download-all-sources.py \
    --output-dir /path/to/mirror \
    --workers 16 \
    --rate-limit 10

# Skip verification for unstable URLs
./scripts/download-all-sources.py \
    --output-dir /path/to/mirror \
    --skip-verification

# Download specific packages only
./scripts/download-all-sources.py \
    --output-dir /path/to/mirror \
    --targets "//packages/linux/core/..."
```

## Verify Mirror

```bash
# Basic verification (just check files exist)
./scripts/verify-mirror.py /path/to/mirror

# With checksum verification
./scripts/verify-mirror.py /path/to/mirror --check-checksums

# Generate report
./scripts/verify-mirror.py /path/to/mirror --report mirror-status.json

# Verbose output
./scripts/verify-mirror.py /path/to/mirror --check-checksums --verbose
```

## Common Workflows

### Create Local Mirror

```bash
# 1. Generate download script
./scripts/generate-download-script.py \
    --output mirror-sync.sh \
    --output-dir /var/www/buckos-mirror \
    --rate-limit 5

# 2. Run it
bash mirror-sync.sh

# 3. Verify
./scripts/verify-mirror.py /var/www/buckos-mirror
```

### Portable USB Mirror

```bash
# Download to USB drive
./scripts/download-all-sources.py \
    --output-dir /mnt/usb/buckos-sources \
    --workers 8 \
    --rate-limit 10

# Verify before unmounting
./scripts/verify-mirror.py /mnt/usb/buckos-sources
```

### Mirror for CI/CD

```bash
# In CI pipeline
./scripts/download-all-sources.py \
    --output-dir /cache/buckos-sources \
    --workers 20 \
    --rate-limit 50 \
    --skip-verification  # Faster, checksums verified by Buck

# Configure Buck to use cache
# .buckconfig:
# [http]
# mirror_url = file:///cache/buckos-sources
```

## Troubleshooting

### Script says "No such file or directory"

Make sure you're in the repo root:
```bash
cd /path/to/buckos-build
./scripts/generate-download-script.py
```

### Checksum mismatches

Some URLs (like GitHub `/refs/heads/main`) have changing checksums:
```bash
# Use --skip-verification
./scripts/generate-download-script.py \
    --output download-all.sh \
    --skip-verification
```

### Downloads too slow

```bash
# Increase workers and rate limit
./scripts/download-all-sources.py \
    --output-dir mirror \
    --workers 16 \
    --rate-limit 20
```

### Getting rate limited by servers

```bash
# Reduce rate limit
./scripts/download-all-sources.py \
    --output-dir mirror \
    --workers 2 \
    --rate-limit 2
```

## Current Status

Your repository has:
- **1,126 stable source files** (with verification)
- **9 unstable URLs** (branch archives, need `--skip-verification`)
- **Total: 1,135 files**

Unstable URLs to fix (should use tagged releases):
- crosvm
- rapl-read-ryzen
- archivemount
- gpu-burn
- minigbm
- gentoo-zsh-completions
- tmux-bash-completion
- hping
- vpnc
