#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root (directory containing this script's parent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load configuration
source "${SCRIPT_DIR}/config.sh"

# ─── Prerequisite checks ────────────────────────────────────────────────────

# Check buehler.rc exists
if [[ ! -f "${REPO_ROOT}/bin/buehler.rc" ]]; then
  echo "ERROR: bin/buehler.rc not found. Run 'node build/concat_rc.js' first." >&2
  exit 1
fi

# Check crawl binary — resolve to absolute path without relying on `realpath` (not on macOS by default)
if [[ "${CRAWL_BIN}" = /* ]]; then
  CRAWL_BIN_RESOLVED="${CRAWL_BIN}"
else
  CRAWL_BIN_RESOLVED="$(cd "${REPO_ROOT}" && cd "$(dirname "${CRAWL_BIN}")" 2>/dev/null && pwd)/$(basename "${CRAWL_BIN}")"
fi
if [[ -z "${CRAWL_BIN_RESOLVED}" || ! -x "${CRAWL_BIN_RESOLVED}" ]]; then
  echo "ERROR: crawl binary not found or not executable at: ${CRAWL_BIN}" >&2
  echo "  Set CRAWL_BIN=/path/to/crawl-console or build crawl first." >&2
  exit 1
fi

# Check fake_pty — required to provide a PTY for the console binary
if [[ "${FAKE_PTY_BIN}" = /* ]]; then
  FAKE_PTY_BIN_RESOLVED="${FAKE_PTY_BIN}"
else
  FAKE_PTY_BIN_RESOLVED="$(cd "${REPO_ROOT}" && cd "$(dirname "${FAKE_PTY_BIN}")" 2>/dev/null && pwd)/$(basename "${FAKE_PTY_BIN}")"
fi
if [[ -z "${FAKE_PTY_BIN_RESOLVED}" || ! -x "${FAKE_PTY_BIN_RESOLVED}" ]]; then
  echo "ERROR: fake_pty not found or not executable at: ${FAKE_PTY_BIN}" >&2
  echo "  Build crawl first (fake_pty is built alongside crawl in crawl-ref/source/util/)." >&2
  exit 1
fi

# Check timeout command (gtimeout on macOS, timeout on Linux)
if command -v gtimeout &>/dev/null; then
  TIMEOUT_CMD="gtimeout"
elif command -v timeout &>/dev/null; then
  TIMEOUT_CMD="timeout"
else
  echo "ERROR: 'timeout' command not found." >&2
  echo "  On macOS: brew install coreutils" >&2
  exit 1
fi

# Find the line number of the standalone BRC.init() call in buehler.rc
# This is the injection point: harness + test go BEFORE this line.
INIT_LINE=$(grep -n "^BRC\.init()$" "${REPO_ROOT}/bin/buehler.rc" | tail -1 | cut -d: -f1)
if [[ -z "${INIT_LINE}" ]]; then
  echo "ERROR: Could not find 'BRC.init()' line in bin/buehler.rc" >&2
  exit 1
fi

# ─── Test discovery ──────────────────────────────────────────────────────────

if [[ $# -gt 0 ]]; then
  # Run a specific test file (pass name without .lua, e.g. "test_startup")
  TEST_FILES=("${SCRIPT_DIR}/${1}.lua")
  if [[ ! -f "${TEST_FILES[0]}" ]]; then
    echo "ERROR: Test file not found: ${TEST_FILES[0]}" >&2
    exit 1
  fi
else
  # Run all test_*.lua files (portable: works on bash 3.2 / macOS)
  TEST_FILES=()
  while IFS= read -r f; do TEST_FILES+=("$f"); done < <(find "${SCRIPT_DIR}" -maxdepth 1 -name "test_*.lua" | sort)
fi

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo "No test files found in ${SCRIPT_DIR}" >&2
  exit 1
fi

# ─── Run tests ───────────────────────────────────────────────────────────────

TMPDIR_BRC="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_BRC}"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ERROR_COUNT=0
RESULTS=()

for TEST_FILE in "${TEST_FILES[@]}"; do
  TEST_NAME="$(basename "${TEST_FILE}" .lua)"
  TEMP_RC="${TMPDIR_BRC}/${TEST_NAME}.rc"
  STDERR_LOG="${TMPDIR_BRC}/${TEST_NAME}.stderr"

  # Build temp RC: everything before BRC.init(), then harness, then test, then BRC.init() + }
  head -n $((INIT_LINE - 1)) "${REPO_ROOT}/bin/buehler.rc" > "${TEMP_RC}"
  cat "${SCRIPT_DIR}/harness.lua" >> "${TEMP_RC}"
  cat "${TEST_FILE}" >> "${TEMP_RC}"
  tail -n "+${INIT_LINE}" "${REPO_ROOT}/bin/buehler.rc" >> "${TEMP_RC}"

  # Run crawl with timeout.
  # fake_pty provides a PTY for stdin/stdout so the console binary runs headlessly.
  # It does NOT wrap stderr, so crawl.stderr() output flows directly to the shell redirection.
  set +e
  $TIMEOUT_CMD "${TIMEOUT_SEC}" \
    "${FAKE_PTY_BIN_RESOLVED}" "${CRAWL_BIN_RESOLVED}" $CRAWL_FLAGS -rc "${TEMP_RC}" \
    > "${TMPDIR_BRC}/${TEST_NAME}.stdout" \
    2> "${STDERR_LOG}"
  EXIT_CODE=$?
  set -e

  # Parse results from stderr
  PASS_LINES=$(grep -c "^\[PASS\]" "${STDERR_LOG}" 2>/dev/null || true)
  FAIL_LINES=$(grep -c "^\[FAIL\]" "${STDERR_LOG}" 2>/dev/null || true)
  ERROR_LINES=$(grep -c "^\[ERROR\]" "${STDERR_LOG}" 2>/dev/null || true)

  if [[ $((PASS_LINES + FAIL_LINES + ERROR_LINES)) -eq 0 ]]; then
    # No result lines: crash, hang, or timeout
    if [[ "${EXIT_CODE}" -eq 124 ]]; then
      echo "[TIMEOUT] ${TEST_NAME}: no result within ${TIMEOUT_SEC}s"
    else
      echo "[ERROR] ${TEST_NAME}: no result lines (exit code ${EXIT_CODE})"
      if [[ -s "${STDERR_LOG}" ]]; then
        echo "  --- stderr ---"
        tail -20 "${STDERR_LOG}" | sed 's/^/  /'
      fi
    fi
    (( ++ERROR_COUNT ))
    RESULTS+=("FAIL:${TEST_NAME}")
  elif [[ "${FAIL_LINES}" -gt 0 || "${ERROR_LINES}" -gt 0 ]]; then
    grep -E "^\[(PASS|FAIL|ERROR)\]" "${STDERR_LOG}" | sed "s/^/  /"
    (( ++FAIL_COUNT ))
    RESULTS+=("FAIL:${TEST_NAME}")
  else
    grep "^\[PASS\]" "${STDERR_LOG}" | sed "s/^/  /"
    (( ++PASS_COUNT ))
    RESULTS+=("PASS:${TEST_NAME}")
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"
TOTAL=$((PASS_COUNT + FAIL_COUNT + ERROR_COUNT))
echo "Results: ${PASS_COUNT}/${TOTAL} passed"
if [[ "${FAIL_COUNT}" -gt 0 || "${ERROR_COUNT}" -gt 0 ]]; then
  echo "FAILED"
  exit 1
else
  echo "OK"
  exit 0
fi
