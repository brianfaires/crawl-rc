#!/usr/bin/env bash
# BRC test runner configuration.
# Sourced by tests/run.sh. REPO_ROOT is set before sourcing.
# Override any variable by setting it in your environment.
# Example: CRAWL_BIN=/path/to/crawl ./tests/run.sh

# Path to crawl console binary.
# Default: standard layout where crawl-rc/ is at crawl-ref/settings/crawl-rc/
# and the binary is at crawl-ref/source/crawl-console
CRAWL_BIN="${CRAWL_BIN:-${REPO_ROOT}/../../source/crawl-console}"

# Path to fake_pty — provides a PTY for stdin/stdout so the console binary runs headlessly.
# fake_pty passes stderr through to the shell, which lets run.sh capture crawl.stderr() output.
FAKE_PTY_BIN="${FAKE_PTY_BIN:-${REPO_ROOT}/../../source/util/fake_pty}"

# Flags passed to every test run.
# -species mu -background be -extra-opt-first weapon=mace: auto-create a Mummy Berserker
# -extra-opt-first restart_after_game=false: exit when game ends instead of looping
CRAWL_FLAGS="${CRAWL_FLAGS:--seed 1 -no-save -name brc_test -species mu -background be -wizard -no-throttle -extra-opt-first restart_after_game=false -extra-opt-first weapon=mace}"

# Per-test timeout in seconds.
# On macOS, requires GNU coreutils: brew install coreutils
TIMEOUT_SEC="${TIMEOUT_SEC:-30}"
