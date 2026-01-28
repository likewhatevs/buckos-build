# Cross-Language USE Flag Support

This document describes how USE flags work across different programming languages and build systems in BuckOs.

## Overview

USE flags now work natively with all language-specific package definitions. Each language has its own mechanism for conditional features, and USE flags are automatically mapped to the appropriate language-specific format.

**All package types now use `ebuild_package()` as the unified backend with language-specific eclasses.**

## Deprecated Functions

The following functions are deprecated and will be removed in a future release:
- **`use_package()`** → Use `autotools_package()` instead
- **`configure_make_package`** (Buck2 rule) → Use `autotools_package()` instead

These have been replaced with `autotools_package()` which uses the eclass system for consistency with all other language packages.

## Supported Languages and Build Systems

### 1. Rust/Cargo - `cargo_package()`

**Cargo Features**: Maps USE flags to Cargo features via `use_features`

```python
cargo_package(
    name = "ripgrep",
    version = "14.0.0",
    src_uri = "https://github.com/BurntSushi/ripgrep/archive/14.0.0.tar.gz",
    sha256 = "...",
    iuse = ["pcre2", "simd"],
    use_defaults = ["simd"],
    use_features = {
        "pcre2": "pcre2",           # Maps to --features=pcre2
        "simd": "simd-accel",       # Maps to --features=simd-accel
    },
    use_deps = {
        "pcre2": ["//packages/linux/dev-libs/pcre2"],
    },
)
```

**How it works**:
- USE flags → Cargo features
- `use_features` maps USE flag names to Cargo feature names
- Generates `--features=feature1,feature2` or `--no-default-features`

### 2. Go - `go_package()`

**Build Tags**: Maps USE flags to Go build tags via `use_tags`

```python
go_package(
    name = "go-sqlite3",
    version = "1.14.18",
    src_uri = "https://github.com/mattn/go-sqlite3/archive/v1.14.18.tar.gz",
    sha256 = "...",
    iuse = ["icu", "json1", "fts5"],
    use_defaults = ["json1"],
    use_tags = {
        "icu": "icu",               # Maps to -tags=icu
        "json1": "json1",           # Maps to -tags=json1
        "fts5": "fts5",
    },
    use_deps = {
        "icu": ["//packages/linux/dev-libs/icu"],
    },
)
```

**How it works**:
- USE flags → Go build tags
- `use_tags` maps USE flag names to Go build tag names
- Generates `-tags=tag1,tag2`

### 3. Python - `python_package()`

**Extras**: Maps USE flags to Python package extras via `use_extras`

```python
python_package(
    name = "requests",
    version = "2.31.0",
    src_uri = "https://github.com/psf/requests/archive/v2.31.0.tar.gz",
    sha256 = "...",
    iuse = ["socks", "security"],
    use_defaults = ["security"],
    use_extras = {
        "socks": "socks",           # Maps to pip install requests[socks]
        "security": "security",     # Maps to pip install requests[security]
    },
    use_deps = {
        "socks": ["//packages/linux/dev-python/pysocks"],
    },
)
```

**How it works**:
- USE flags → Python extras
- `use_extras` maps USE flag names to extra names
- Installs with extras: `package[extra1,extra2]`

### 4. CMake - `cmake_package()`

**CMake Options**: Maps USE flags to CMake options via `use_options`

```python
cmake_package(
    name = "libfoo",
    version = "1.2.3",
    src_uri = "https://example.com/libfoo-1.2.3.tar.gz",
    sha256 = "...",
    iuse = ["ssl", "tests", "doc"],
    use_defaults = ["ssl"],
    use_options = {
        "ssl": "ENABLE_SSL",        # Maps to -DENABLE_SSL=ON/OFF
        "tests": "BUILD_TESTING",   # Maps to -DBUILD_TESTING=ON/OFF
        "doc": "BUILD_DOCUMENTATION",
    },
    use_deps = {
        "ssl": ["//packages/linux/dev-libs/openssl"],
    },
)
```

**How it works**:
- USE flags → CMake options
- Enabled: `-DOPTION=ON`
- Disabled: `-DOPTION=OFF`

### 5. Meson - `meson_package()`

**Meson Features**: Maps USE flags to Meson features via `use_options`

```python
meson_package(
    name = "libbar",
    version = "2.3.4",
    src_uri = "https://example.com/libbar-2.3.4.tar.xz",
    sha256 = "...",
    iuse = ["ssl", "tests", "doc"],
    use_defaults = ["ssl"],
    use_options = {
        "ssl": "ssl",               # Maps to -Dssl=enabled/disabled
        "tests": "tests",           # Maps to -Dtests=enabled/disabled
        "doc": "docs",
    },
    use_deps = {
        "ssl": ["//packages/linux/dev-libs/openssl"],
    },
)
```

**How it works**:
- USE flags → Meson feature options
- Enabled: `-Dfeature=enabled`
- Disabled: `-Dfeature=disabled`

### 6. Autotools - `autotools_package()`

**Configure Arguments**: Maps USE flags to configure arguments

```python
autotools_package(
    name = "curl",
    version = "8.5.0",
    src_uri = "https://curl.se/download/curl-8.5.0.tar.xz",
    sha256 = "...",
    iuse = ["ssl", "http2", "ipv6"],
    use_defaults = ["ssl", "ipv6"],
    use_configure = {
        "ssl": "--with-ssl",
        "-ssl": "--without-ssl",
        "http2": "--with-nghttp2",
        "ipv6": "--enable-ipv6",
        "-ipv6": "--disable-ipv6",
    },
    use_deps = {
        "ssl": ["//packages/linux/dev-libs/openssl"],
    },
)
```

**How it works**:
- USE flags → autoconf/automake configure arguments
- Enabled: Adds specified flag (e.g., `--with-ssl`)
- Disabled: Adds disabled flag (e.g., `--without-ssl`)
- Uses the autotools eclass with `ebuild_package()` backend

## USE_EXPAND Support

New USE_EXPAND variables have been added for language version targeting:

### Go Versions
```python
GO_TARGETS = ["go1_21", "go1_22", "go1_23"]
```

### Rust Target Triples
```python
RUST_TARGETS = [
    "x86_64_unknown_linux_gnu",
    "x86_64_unknown_linux_musl",
    "aarch64_unknown_linux_gnu",
    "aarch64_unknown_linux_musl",
    "armv7_unknown_linux_gnueabihf",
    "i686_unknown_linux_gnu",
    "riscv64gc_unknown_linux_gnu",
]
```

### Node.js Versions
```python
NODE_TARGETS = ["node18", "node20", "node21"]
```

Example usage:
```python
load("//defs:use_expand.bzl", "expand_use")

# Expand to rust_targets_x86_64_unknown_linux_gnu, etc.
use_flags = expand_use(
    rust_targets = ["x86_64_unknown_linux_gnu", "aarch64_unknown_linux_gnu"],
)
```

## Common Parameters

All language-specific package functions now support these USE flag parameters:

- **`iuse`**: List of USE flags this package supports
- **`use_defaults`**: Default enabled USE flags
- **`use_deps`**: Dict mapping USE flag to conditional dependencies
- **`global_use`**: Global USE flag configuration (from `set_use_flags()`)
- **`package_overrides`**: Package-specific USE overrides (from `package_use()`)

Language-specific mapping parameter:
- **Cargo**: `use_features` - Maps to Cargo features
- **Go**: `use_tags` - Maps to Go build tags
- **Python**: `use_extras` - Maps to Python extras
- **CMake**: `use_options` - Maps to CMake options
- **Meson**: `use_options` - Maps to Meson features
- **Autotools**: `use_configure` - Maps to configure arguments

## Unified Architecture

All package functions now follow the same pattern:

```
Language Package Function → Eclass → ebuild_package() → Buck2 Rule
```

**Examples:**
- `cargo_package()` → `cargo` eclass → `ebuild_package()` → `ebuild_package` rule
- `go_package()` → `go-module` eclass → `ebuild_package()` → `ebuild_package` rule
- `python_package()` → `python-single-r1` eclass → `ebuild_package()` → `ebuild_package` rule
- `cmake_package()` → `cmake` eclass → `ebuild_package()` → `ebuild_package` rule
- `meson_package()` → `meson` eclass → `ebuild_package()` → `ebuild_package` rule
- `autotools_package()` → `autotools` eclass → `ebuild_package()` → `ebuild_package` rule

**Old (deprecated):**
- `use_package()` → `configure_make_package` rule (direct Buck2 rule, less flexible)
- `configure_make_package()` (direct Buck2 rule)

## Helper Functions

New helper functions in `defs/use_flags.bzl`:

### Cargo/Rust
- `use_cargo_features(use_features, enabled_flags)` - Get enabled Cargo features
- `use_cargo_args(use_features, enabled_flags, extra_args)` - Generate Cargo build args

### Go
- `use_go_tags(use_tags, enabled_flags)` - Get enabled Go build tags
- `use_go_build_args(use_tags, enabled_flags, extra_args)` - Generate Go build args

### CMake
- `use_cmake_options(use_options, enabled_flags)` - Generate CMake options

### Meson
- `use_meson_options(use_options, enabled_flags)` - Generate Meson options

## Resolution Order

USE flags are resolved in this order (later overrides earlier):

1. Package IUSE defaults (from `use_defaults`)
2. Global profile USE flags (from profiles)
3. Global USE flags (from `set_use_flags()`)
4. Per-package overrides (from `package_use()`)

## Complete Example: Multi-Language Project

```python
# Global USE flag configuration
global_use = set_use_flags(["ssl", "http2", "ipv6", "-debug"])

# Rust component with USE flags
cargo_package(
    name = "my-rust-tool",
    version = "1.0.0",
    src_uri = "...",
    sha256 = "...",
    iuse = ["ssl", "http2", "simd"],
    use_defaults = ["simd"],
    use_features = {
        "ssl": "tls",
        "http2": "http2",
        "simd": "simd-accel",
    },
    global_use = global_use,
)

# Go component with USE flags
go_package(
    name = "my-go-service",
    version = "2.0.0",
    src_uri = "...",
    sha256 = "...",
    iuse = ["ssl", "sqlite", "postgres"],
    use_defaults = ["sqlite"],
    use_tags = {
        "ssl": "openssl",
        "sqlite": "sqlite",
        "postgres": "postgres",
    },
    global_use = global_use,
)

# Python component with USE flags
python_package(
    name = "my-python-lib",
    version = "3.0.0",
    src_uri = "...",
    sha256 = "...",
    iuse = ["ssl", "async"],
    use_defaults = ["async"],
    use_extras = {
        "ssl": "security",
        "async": "async",
    },
    global_use = global_use,
)
```

## Benefits

1. **Consistent Interface**: Same USE flag parameters across all languages
2. **Language-Native**: Maps to each language's native feature system
3. **Dependency Management**: Conditional dependencies work the same everywhere
4. **Profile Support**: Global USE flag profiles apply to all languages
5. **Flexibility**: Mix and match different languages with unified configuration
