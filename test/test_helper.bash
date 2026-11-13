#!/usr/bin/env bash
# Shared fixtures for lab tests.

# Run a repo task through mise so tests exercise the real task path.
lab() {
  cd "$REPO_DIR" && mise run -q "$@"
}
export -f lab

# Run the public task with only the environment needed by real concurrency
# probes, excluding the per-test mock BATS and Rush commands.
lab_isolated() {
  env -i \
    HOME="$HOME" \
    PATH="$PATH" \
    TMPDIR="${TMPDIR:-/tmp}" \
    MISE_TRUSTED_CONFIG_PATHS="$REPO_DIR" \
    PROBE_DIR="${PROBE_DIR:-}" \
    mise -C "$REPO_DIR" run -q "$@"
}
export -f lab_isolated
