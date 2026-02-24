"""Shared environment sanitization for build helpers.

Buck2's local executor inherits the daemon's full host environment into
action subprocesses, but action cache keys only include explicitly declared
env={}.  Two hosts sharing a NativeLink CAS compute identical digests but
may produce different outputs when host env differs — cache poisoning.

This module provides a whitelist-based approach: start from a clean env
with only functional vars, pin determinism vars, and let each helper add
what it needs on top.
"""

import os

# Vars passed through from the host environment when present.
_PASSTHROUGH = frozenset({
    "HOME", "USER", "LOGNAME",
    "TMPDIR", "TEMP", "TMP",
    "TERM", "PATH",
    "BUCK_SCRATCH_PATH",
})

# Vars pinned to fixed values for determinism.
_DETERMINISM_PINS = {
    "LC_ALL": "C",
    "LANG": "C",
    "SOURCE_DATE_EPOCH": "315576000",
    "CCACHE_DISABLE": "1",
    "RUSTC_WRAPPER": "",
    "CARGO_BUILD_RUSTC_WRAPPER": "",
}


def clean_env():
    """Return a clean env dict for subprocess env= parameter.

    Copies only whitelisted vars from the host, then applies
    determinism pins.  Callers layer helper-specific vars on top.
    """
    env = {}
    for key in _PASSTHROUGH:
        val = os.environ.get(key)
        if val is not None:
            env[key] = val
    env.update(_DETERMINISM_PINS)
    return env


def sanitize_global_env():
    """Replace os.environ in-place with a clean environment.

    For helpers that mutate os.environ directly (Pattern B) rather
    than passing env= to subprocess.  Preserves whitelisted vars,
    applies determinism pins, drops everything else.
    """
    keep = {}
    for key in _PASSTHROUGH:
        val = os.environ.get(key)
        if val is not None:
            keep[key] = val
    os.environ.clear()
    os.environ.update(keep)
    os.environ.update(_DETERMINISM_PINS)
