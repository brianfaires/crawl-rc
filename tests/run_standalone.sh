#!/usr/bin/env bash
set -euo pipefail

# Smoke test runner for standalone BRC feature files.
# Tests each file in bin/standalone_features/ in isolation — no buehler.rc, just the feature alone.
# Verifies that each feature: (1) loads without Lua errors, (2) survives 3 ready() turns.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/config.sh"

# ─── Prerequisite checks ────────────────────────────────────────────────────

if [[ "${CRAWL_BIN}" = /* ]]; then
  CRAWL_BIN_RESOLVED="${CRAWL_BIN}"
else
  CRAWL_BIN_RESOLVED="$(cd "${REPO_ROOT}" && cd "$(dirname "${CRAWL_BIN}")" 2>/dev/null && pwd)/$(basename "${CRAWL_BIN}")"
fi
if [[ -z "${CRAWL_BIN_RESOLVED}" || ! -x "${CRAWL_BIN_RESOLVED}" ]]; then
  echo "ERROR: crawl binary not found or not executable at: ${CRAWL_BIN}" >&2
  exit 1
fi

if [[ "${FAKE_PTY_BIN}" = /* ]]; then
  FAKE_PTY_BIN_RESOLVED="${FAKE_PTY_BIN}"
else
  FAKE_PTY_BIN_RESOLVED="$(cd "${REPO_ROOT}" && cd "$(dirname "${FAKE_PTY_BIN}")" 2>/dev/null && pwd)/$(basename "${FAKE_PTY_BIN}")"
fi
if [[ -z "${FAKE_PTY_BIN_RESOLVED}" || ! -x "${FAKE_PTY_BIN_RESOLVED}" ]]; then
  echo "ERROR: fake_pty not found or not executable at: ${FAKE_PTY_BIN}" >&2
  exit 1
fi

if command -v gtimeout &>/dev/null; then
  TIMEOUT_CMD="gtimeout"
elif command -v timeout &>/dev/null; then
  TIMEOUT_CMD="timeout"
else
  echo "ERROR: 'timeout' command not found. On macOS: brew install coreutils" >&2
  exit 1
fi

STANDALONE_DIR="${REPO_ROOT}/bin/standalone_features"
if [[ ! -d "${STANDALONE_DIR}" ]]; then
  echo "ERROR: ${STANDALONE_DIR} not found. Run 'python3 build/create_standalone_features.py' first." >&2
  exit 1
fi

# ─── Feature selection ────────────────────────────────────────────────────────

if [[ $# -gt 0 ]]; then
  RC_FILES=("${STANDALONE_DIR}/${1}.rc")
  if [[ ! -f "${RC_FILES[0]}" ]]; then
    echo "ERROR: ${RC_FILES[0]} not found" >&2
    exit 1
  fi
else
  RC_FILES=()
  while IFS= read -r f; do RC_FILES+=("$f"); done < <(find "${STANDALONE_DIR}" -maxdepth 1 -name "*.rc" | sort)
fi

# ─── Temp dir ────────────────────────────────────────────────────────────────

TMPDIR_BRC="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_BRC}"' EXIT

# ─── Smoke harness assembly ───────────────────────────────────────────────────

# Injected BEFORE feature content: helpers only, no hook definitions.
smoke_header() {
  cat <<'LUA'
-- BRC Standalone Smoke Harness
-- Injected before feature content. Provides _sa_done() for clean exit.
local _smoke_turn = 0
local _smoke_done = false
local function _sa_done()
  if not _smoke_done then
    _smoke_done = true
    crawl.do_commands({"CMD_SAVE_GAME_NOW"})
  end
end
LUA
}

# Injected AFTER feature content: wraps hooks defined by the feature.
# $1 = feature name label for [PASS]/[FAIL] messages
smoke_tail() {
  local name="$1"
  cat <<LUA
-- Smoke wrappers injected after feature content

-- Wrap ready(): run 3 clean turns then PASS, or catch errors and FAIL.
-- If the feature has no ready(), _orig_ready is nil and we just count turns.
local _orig_ready = ready
local _smoke_last_turn = -1
function ready(...)
  if _smoke_done then return end
  if you.turns() >= 20 then
    crawl.stderr("[FAIL] ${name}: timed out after 20 turns")
    _sa_done()
    return
  end
  -- One count per game turn (mirrors the standalone feature's own turn guard)
  if you.turns() <= _smoke_last_turn then return end
  _smoke_last_turn = you.turns()
  if _orig_ready then
    local ok, err = pcall(_orig_ready, ...)
    if not ok then
      crawl.stderr("[FAIL] ${name}: ready() error: " .. tostring(err))
      _sa_done()
      return
    end
  end
  _smoke_turn = _smoke_turn + 1
  if _smoke_turn >= 3 then
    crawl.stderr("[PASS] ${name}: loaded and ran 3 turns without error")
    _sa_done()
  else
    -- Advance to next turn so ready() fires again (game waits for input otherwise)
    crawl.do_commands({"CMD_WAIT"})
  end
end

-- Wrap c_answer_prompt: answer save/quit prompts after _sa_done(), delegate rest to feature.
local _orig_cap = c_answer_prompt
function c_answer_prompt(prompt)
  if _smoke_done then
    local p = prompt:lower()
    if p:find("save") or p:find("quit") or p:find("leave") or p:find("exit") then
      return true
    end
  end
  if _orig_cap then return _orig_cap(prompt) end
end
LUA
}

# Extracts the Lua body of a standalone .rc file:
# strips ## comment header lines, the opening { line, and the closing } line.
extract_feature_body() {
  local rc_file="$1"
  local open_line
  open_line=$(grep -n "^{$" "${rc_file}" | head -1 | cut -d: -f1)
  if [[ -z "${open_line}" ]]; then
    echo "ERROR: no opening { found in ${rc_file}" >&2
    return 1
  fi
  # Skip past {, then drop the final } line (sed '$d' is portable; head -n -1 is not on macOS)
  tail -n "+$((open_line + 1))" "${rc_file}" | sed '$d'
}

# ─── Run tests ───────────────────────────────────────────────────────────────

PASS_COUNT=0
FAIL_COUNT=0
ERROR_COUNT=0

for RC_FILE in "${RC_FILES[@]}"; do
  FEATURE_NAME="$(basename "${RC_FILE}" .rc)"
  TEMP_RC="${TMPDIR_BRC}/${FEATURE_NAME}.rc"
  STDERR_LOG="${TMPDIR_BRC}/${FEATURE_NAME}.stderr"

  # Build smoke RC: single { } Lua block containing header + feature body + tail
  {
    echo "{"
    smoke_header
    extract_feature_body "${RC_FILE}"
    smoke_tail "${FEATURE_NAME}"
    echo "}"
  } > "${TEMP_RC}"

  set +e
  $TIMEOUT_CMD "${TIMEOUT_SEC}" \
    "${FAKE_PTY_BIN_RESOLVED}" "${CRAWL_BIN_RESOLVED}" $CRAWL_FLAGS -rc "${TEMP_RC}" \
    > "${TMPDIR_BRC}/${FEATURE_NAME}.stdout" \
    2> "${STDERR_LOG}"
  EXIT_CODE=$?
  set -e

  PASS_LINES=$(grep -c "^\[PASS\]" "${STDERR_LOG}" 2>/dev/null || true)
  FAIL_LINES=$(grep -c "^\[FAIL\]" "${STDERR_LOG}" 2>/dev/null || true)
  ERROR_LINES=$(grep -c "^\[ERROR\]" "${STDERR_LOG}" 2>/dev/null || true)

  if [[ $((PASS_LINES + FAIL_LINES + ERROR_LINES)) -eq 0 ]]; then
    if [[ "${EXIT_CODE}" -eq 124 ]]; then
      echo "[TIMEOUT] ${FEATURE_NAME}: no result within ${TIMEOUT_SEC}s"
    else
      echo "[ERROR] ${FEATURE_NAME}: no result lines (exit code ${EXIT_CODE})"
      if [[ -s "${STDERR_LOG}" ]]; then
        echo "  --- stderr ---"
        tail -20 "${STDERR_LOG}" | sed 's/^/  /'
      fi
    fi
    (( ++ERROR_COUNT ))
  elif [[ "${FAIL_LINES}" -gt 0 || "${ERROR_LINES}" -gt 0 ]]; then
    grep -E "^\[(PASS|FAIL|ERROR)\]" "${STDERR_LOG}" | sed "s/^/  /"
    (( ++FAIL_COUNT ))
  else
    grep "^\[PASS\]" "${STDERR_LOG}" | sed "s/^/  /"
    (( ++PASS_COUNT ))
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"
TOTAL=$((PASS_COUNT + FAIL_COUNT + ERROR_COUNT))
echo "Standalone smoke: ${PASS_COUNT}/${TOTAL} passed"
if [[ "${FAIL_COUNT}" -gt 0 || "${ERROR_COUNT}" -gt 0 ]]; then
  echo "FAILED"
  exit 1
else
  echo "OK"
  exit 0
fi
