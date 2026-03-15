#!/usr/bin/env bash
# BRC test runner configuration.
# Sourced by tests/run.sh. REPO_ROOT is set before sourcing.
# Override any variable by setting it in your environment.
# Example: CRAWL_BIN=/path/to/crawl ./tests/run.sh

# Path to crawl binary.
# Default: standard layout where crawl-rc/ is at crawl-ref/settings/crawl-rc/
# and the binary is at crawl-ref/source/crawl
CRAWL_BIN="${CRAWL_BIN:-${REPO_ROOT}/../../source/crawl}"

# Flags passed to every test run
CRAWL_FLAGS="${CRAWL_FLAGS:--headless -seed 1 -no-save -name brc_test -wizard -no-throttle}"

# Per-test timeout in seconds.
# On macOS, requires GNU coreutils: brew install coreutils
TIMEOUT_SEC="${TIMEOUT_SEC:-30}"
