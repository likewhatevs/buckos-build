# Buck2 Build Results

Building targets in order of longest to shortest name.

## Summary
| Status | Count |
|--------|-------|
| Passed | 140 |
| Failed | 60 |
| Untested | 3684 |

## Fixes Applied

### 1. cross-binutils: Disabled GDB and makeinfo
- **Issue**: Configure failed requiring GMP/MPFR for GDB; make install failed due to missing makeinfo
- **Fix**: Added `--disable-gdb --disable-gdbserver --disable-sim --disable-libdecnumber --disable-readline` and `MAKEINFO=true`
- **File**: `toolchains/bootstrap/BUCK`

### 2. cross-gcc-pass1: Link GMP/MPFR/MPC sources
- **Issue**: GCC configure failed with "Building GCC requires GMP 4.2+, MPFR 3.1.0+ and MPC 0.8.0+"
- **Fix**: Added src_prepare phase that finds and symlinks GMP, MPFR, MPC source directories into GCC source tree for in-tree build
- **File**: `toolchains/bootstrap/BUCK`

## Results by Category

### Passed Builds (sample - 140 total)
Most `-src` (source download) targets pass successfully:
- `root//packages/linux/dev-tools/dev-utils/include-what-you-use:include-what-you-use-src`
- `root//packages/linux/system/filesystem/management/multipath-tools:multipath-tools-src`
- `root//packages/linux/desktop/wayland-utilities/swaylock-effects:swaylock-effects-src`
- `root//packages/linux/system/power/x86_energy_perf_policy:x86_energy_perf_policy`
- `root//packages/linux/communication/email-clients/gui/thunderbird:thunderbird`
- `root//packages/linux/emulation/utilities/cloud-hypervisor:cloud-hypervisor`
- `root//packages/linux/communication/email-clients/cli/himalaya:himalaya`
- `root//packages/linux/network/dns/tools/dnscrypt-proxy:dnscrypt-proxy`
- `root//packages/linux/communication/email-servers/opensmtpd:opensmtpd`
- `root//packages/linux/dev-tools/dev-utils/diff-so-fancy:diff-so-fancy`
- `root//packages/linux/laptop/battery/laptop-mode-tools:laptop-mode-tools`
- `root//packages/linux/system/containers/utils:docker-credential-helpers`

### Failed Builds (sample - 60 total)

Most failures are due to missing dependencies (primarily glib needing pcre2):

- `root//packages/linux/emulation/virtualization/virtualbox:virtualbox-guest-additions` - glib→pcre2
- `root//packages/linux/dev-tools/dev-utils/include-what-you-use:include-what-you-use` - glib→pcre2
- `root//packages/linux/system/filesystem/management/multipath-tools:multipath-tools` - glib→pcre2
- `root//packages/linux/desktop/wayland-utilities/swaylock-effects:swaylock-effects` - glib→pcre2
- `root//packages/linux/system/filesystem/native/squashfs-tools:squashfs-tools` - glib→pcre2
- `root//packages/linux/gaming/libraries/vulkan-tools:vulkan-validation-layers` - glib→pcre2
- `root//packages/linux/examples/multi-version/openssl:openssl-multi-slot-*` - slot mechanism issues

### Root Cause Analysis

**Primary Issue**: `glib` package fails due to missing `pcre2` dependency:
```
undefined reference to `pcre2_match_8@PCRE2_10.47'
```

This blocks many desktop/utility packages that depend on glib.

## Statistics

- Total targets: 3884
- Tested: 200 (first 200 by longest name)
- Pass rate: 70% (140/200)
- Source downloads: ~90% pass rate
- Actual package builds: ~50% pass rate (due to glib dependency chain)
