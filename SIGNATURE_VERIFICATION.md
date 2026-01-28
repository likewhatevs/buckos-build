# GPG Signature Verification for Package Downloads

## Overview

The package build system now supports GPG/PGP signature verification for downloaded source files. This provides an additional layer of security beyond SHA256 checksum verification.

## Features

- **Auto-detection of signatures**: Automatically tries common signature file patterns (.asc, .sig, .sign) by default
- **Optional signature verification**: Signature verification is entirely optional and backward-compatible
- **Automatic GPG key import**: Can automatically fetch keys from keyservers
- **Custom keyring support**: Use your own keyring file with trusted keys
- **Works with all package types**: Supports simple_package, cmake_package, meson_package, cargo_package, go_package, python_package, and use_package
- **Non-blocking**: If auto-detection is enabled but no signature is found, build continues normally

## Usage

### Auto-Detection (Default Behavior)

By default, the build system will automatically try to find and verify signature files:

```python
simple_package(
    name = "example",
    version = "1.0.0",
    src_uri = "https://example.com/example-1.0.0.tar.gz",
    sha256 = "abc123...",
    gpg_key = "0x1234567890ABCDEF",  # System will auto-detect .asc, .sig, or .sign files
)
```

The system automatically tries these URLs in order:
1. `https://example.com/example-1.0.0.tar.gz.asc`
2. `https://example.com/example-1.0.0.tar.gz.sig`
3. `https://example.com/example-1.0.0.tar.gz.sign`

If no signature is found, the build continues with only SHA256 verification. If a signature is found but verification fails, the build fails.

### Explicit Signature URI

You can explicitly specify the signature file location:

```python
simple_package(
    name = "example",
    version = "1.0.0",
    src_uri = "https://example.com/example-1.0.0.tar.gz",
    sha256 = "abc123...",
    signature_uri = "https://example.com/example-1.0.0.tar.gz.asc",
    gpg_key = "0x1234567890ABCDEF",
)
```

### Disable Auto-Detection

If you want to disable auto-detection for a specific package:

```python
simple_package(
    name = "example",
    version = "1.0.0",
    src_uri = "https://example.com/example-1.0.0.tar.gz",
    sha256 = "abc123...",
    auto_detect_signature = False,  # No signature checking
)
```

### Global Control via Environment Variable

Similar to Gentoo's USE flags, you can control signature verification globally using the `BUCKOS_VERIFY_SIGNATURES` environment variable:

```bash
# Disable signature verification for all packages
BUCKOS_VERIFY_SIGNATURES=0 buck2 build //packages/linux/...

# Enable signature verification for all packages
BUCKOS_VERIFY_SIGNATURES=1 buck2 build //packages/linux/...

# Set persistently in your shell profile
export BUCKOS_VERIFY_SIGNATURES=0
```

**Values:**
- `1` or `true` - Enable signature verification globally (overrides per-package settings)
- `0` or `false` - Disable signature verification globally (overrides per-package settings)
- Not set - Use per-package `auto_detect_signature` setting (default behavior)

This is useful when:
- Building on systems without GPG configured
- Doing local development where signature verification adds overhead
- CI/CD environments where you want consistent behavior across all packages

### Using a Custom Keyring

```python
cmake_package(
    name = "myproject",
    version = "2.0.0",
    src_uri = "https://myproject.org/releases/myproject-2.0.0.tar.xz",
    sha256 = "def456...",
    signature_uri = "https://myproject.org/releases/myproject-2.0.0.tar.xz.sig",
    gpg_keyring = "/path/to/trusted-keys.gpg",
)
```

### Signature Only (Pre-imported Keys)

If the GPG key is already in the system keyring:

```python
python_package(
    name = "requests",
    version = "2.31.0",
    src_uri = "https://pypi.io/packages/requests-2.31.0.tar.gz",
    sha256 = "ghi789...",
    signature_uri = "https://pypi.io/packages/requests-2.31.0.tar.gz.asc",
)
```

## Parameters

All package macros (`simple_package`, `cmake_package`, `meson_package`, `cargo_package`, `go_package`, `python_package`, `use_package`) now accept these optional parameters:

- **`signature_uri`** (optional): URL to the GPG signature file (typically `.asc` or `.sig`). If not specified, auto-detection is used.
- **`gpg_key`** (optional): GPG key ID or fingerprint to import from keyserver
- **`gpg_keyring`** (optional): Path to a GPG keyring file containing trusted keys
- **`auto_detect_signature`** (default: `True`): Automatically try to find signature files using common extensions (.asc, .sig, .sign)

## How It Works

1. **Download**: Source file is downloaded and SHA256 checksum is verified (required)
2. **Signature Detection/Download**:
   - If `signature_uri` is explicitly provided, that signature file is downloaded
   - If `auto_detect_signature=True` (default), tries common patterns: `.asc`, `.sig`, `.sign`
   - If no signature is found and auto-detection is enabled, logs informational message and continues
3. **Key Import**: If `gpg_key` is specified, the key is imported from `hkps://keys.openpgp.org`
4. **Verification**: If a signature file is found, it's verified against the downloaded file
5. **Success/Failure**: Build continues if verification passes OR if no signature was found during auto-detection. Build fails if signature verification explicitly fails.

## Security Considerations

### Defense in Depth

Signature verification provides defense-in-depth:
- **SHA256 checksum**: Protects against corrupted downloads and accidental changes
- **GPG signature**: Protects against malicious source substitution and verifies authenticity

### Trust Model

- If using `gpg_key`, you're trusting the keyserver to provide the correct key
- If using `gpg_keyring`, you're trusting the keys in that keyring file
- Always verify key fingerprints through trusted channels before adding them to keyrings

### Key Management

For production use, consider:
1. Maintaining a local keyring with verified keys
2. Verifying key fingerprints through multiple channels (website, GitHub, in-person, etc.)
3. Regularly updating and auditing trusted keys

## Examples by Package Type

### autotools (simple_package)

```python
# With auto-detection (recommended)
simple_package(
    name = "curl",
    version = "8.5.0",
    src_uri = "https://curl.se/download/curl-8.5.0.tar.xz",
    sha256 = "...",
    gpg_key = "27EDEAF22F3ABCEB50DB9A125CC908FDB71E12C2",
    # Will automatically try curl-8.5.0.tar.xz.asc, .sig, .sign
)

# With explicit signature URI
simple_package(
    name = "curl",
    version = "8.5.0",
    src_uri = "https://curl.se/download/curl-8.5.0.tar.xz",
    sha256 = "...",
    signature_uri = "https://curl.se/download/curl-8.5.0.tar.xz.asc",
    gpg_key = "27EDEAF22F3ABCEB50DB9A125CC908FDB71E12C2",
)
```

### CMake (cmake_package)

```python
cmake_package(
    name = "opencv",
    version = "4.8.0",
    src_uri = "https://github.com/opencv/opencv/archive/4.8.0.tar.gz",
    sha256 = "...",
    signature_uri = "https://github.com/opencv/opencv/releases/download/4.8.0/opencv-4.8.0.tar.gz.asc",
    gpg_keyring = "//keyrings:opencv.gpg",
)
```

### Rust (cargo_package)

```python
cargo_package(
    name = "ripgrep",
    version = "14.0.0",
    src_uri = "https://github.com/BurntSushi/ripgrep/archive/14.0.0.tar.gz",
    sha256 = "...",
    signature_uri = "https://github.com/BurntSushi/ripgrep/releases/download/14.0.0/ripgrep-14.0.0.tar.gz.asc",
    gpg_key = "3F5C2A8367B9FD2C",
    bins = ["rg"],
)
```

## Backward Compatibility

All signature verification parameters are optional. Existing package definitions without signature verification will continue to work exactly as before:

```python
# This still works - no signature verification
simple_package(
    name = "example",
    version = "1.0.0",
    src_uri = "https://example.com/example-1.0.0.tar.gz",
    sha256 = "abc123...",
)
```

## Troubleshooting

### Signature verification fails

1. Check that the signature URL is correct
2. Verify the GPG key ID matches the key that signed the release
3. Ensure GPG is installed on the build system
4. Check network connectivity to keyservers

### Key import fails

- The key might not be on the default keyserver
- Try using a custom keyring with pre-imported keys
- Manually import the key to the system keyring

### Build hangs during verification

- Ensure you're using `--batch` mode (automatically handled by the implementation)
- Check that GPG isn't trying to prompt for input
