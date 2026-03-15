# Testing Framework Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an automated integration testing framework that runs BRC inside a real headless crawl process and reports pass/fail results from the command line.

**Architecture:** Tests are Lua files that define BRC feature modules; they get injected into a temporary RC file (built by splitting `buehler.rc` just before `BRC.init()`) so their globals are registered automatically. A shell runner builds the RC, launches crawl headlessly, parses `[PASS]`/`[FAIL]`/`[ERROR]` lines from stderr, and exits with the appropriate code.

**Tech Stack:** Lua 5.1 (crawl's embedded interpreter), bash, DCSS crawl binary (v0.34 or v0.35-dev)

**Spec:** `docs/superpowers/specs/2026-03-14-testing-framework-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `tests/harness.lua` | Create | `T` BRC feature module: assertions, lifecycle, message capture, wizard stubs |
| `tests/test_startup.lua` | Create | Smoke test: verifies BRC loads and activates with features registered |
| `tests/config.sh` | Create | Crawl binary path, base flags, timeout duration |
| `tests/run.sh` | Create | Prerequisite checks, RC build, crawl launch, result parsing, summary |
| `package.json` | Modify | Add `"test": "./tests/run.sh"` script |

---

## Chunk 1: Test Harness and Smoke Test

### Task 1: Create `tests/harness.lua`

**Files:**
- Create: `tests/harness.lua`

This file is injected as raw Lua inside `buehler.rc`'s final `{ }` block, just before `BRC.init()` runs. All code here executes at RC load time.

- [ ] **Step 1: Create `tests/` directory and `tests/harness.lua`**

```lua
---------------------------------------------------------------------------------------------------
-- BRC Test Harness
-- Injected before BRC.init() so T is registered as a BRC feature automatically.
-- Provides T.* API for assertions, lifecycle, and message capture.
---------------------------------------------------------------------------------------------------

-- Override config before BRC.init() sees it (prevents interactive "ask" prompt in headless mode)
BRC.Config.to_use = "Testing"

-- T is the harness feature module. BRC picks it up via T.BRC_FEATURE_NAME.
T = {}
T.BRC_FEATURE_NAME = "test-harness"
T.timeout_turns = 20
T._done = false

-- Message capture buffer (populated by T.c_message hook)
T.last_messages = {}

---------------------------------------------------------------------------------------------------
-- Output helpers — write directly to stderr so run.sh can parse them separately from stdout
---------------------------------------------------------------------------------------------------

local function stderr(line)
  io.stderr:write(line .. "\n")
  io.stderr:flush()
end

function T.pass(name)
  stderr("[PASS] " .. tostring(name))
end

function T.fail(name, reason)
  stderr("[FAIL] " .. tostring(name) .. ": " .. tostring(reason))
end

function T.error_(name, msg)
  stderr("[ERROR] " .. tostring(name) .. ": " .. tostring(msg))
end

---------------------------------------------------------------------------------------------------
-- Assertions
---------------------------------------------------------------------------------------------------

function T.eq(actual, expected, name)
  if actual == expected then
    T.pass(name)
  else
    T.fail(name, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
  end
end

function T.true_(val, name)
  if val then
    T.pass(name)
  else
    T.fail(name, "expected true, got " .. tostring(val))
  end
end

function T.false_(val, name)
  if not val then
    T.pass(name)
  else
    T.fail(name, "expected false, got " .. tostring(val))
  end
end

function T.contains(str, pattern, name)
  if string.find(tostring(str), pattern) then
    T.pass(name)
  else
    T.fail(name, string.format("pattern %q not found in %q", pattern, tostring(str)))
  end
end

---------------------------------------------------------------------------------------------------
-- T.run(name, fn): wrap test logic in pcall to prevent BRC's interactive error handler from
-- firing (which would hang in headless mode). Always call T.done() after T.run().
---------------------------------------------------------------------------------------------------

function T.run(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    T.error_(name, err)
    T.done()
  end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------

-- T.done(): signal test completion and quit crawl.
-- Answers save/quit prompts via c_answer_prompt so crawl exits cleanly.
function T.done()
  T._done = true
  crawl.sendkeys("S") -- save-and-quit key; under -no-save, crawl exits without saving
end

-- Timeout guard: if T.done() not called within T.timeout_turns, fail and quit.
function T.ready()
  if T._done then return end
  if you.turns() >= T.timeout_turns then
    T.fail("timeout", string.format("test did not complete within %d turns", T.timeout_turns))
    T.done()
  end
end

-- Auto-answer save/quit prompts so T.done() exits cleanly without blocking.
function T.c_answer_prompt(prompt)
  if T._done then
    local p = prompt:lower()
    if p:find("save") or p:find("quit") or p:find("exit") or p:find("leave") then
      return true
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Message capture
---------------------------------------------------------------------------------------------------

function T.c_message(text, channel)
  table.insert(T.last_messages, {text = text, channel = channel})
end

function T.messages_contain(pattern)
  for _, msg in ipairs(T.last_messages) do
    if string.find(msg.text, pattern) then return true end
  end
  return false
end

---------------------------------------------------------------------------------------------------
-- Wizard helpers (v2 stubs — not implemented in v1)
---------------------------------------------------------------------------------------------------

function T.wizard_give(item_spec)
  T.error_("wizard_give", "not implemented in v1")
  T.done()
end

function T.wizard_set_xl(level)
  T.error_("wizard_set_xl", "not implemented in v1")
  T.done()
end

function T.wizard_teleport()
  T.error_("wizard_teleport", "not implemented in v1")
  T.done()
end
```

- [ ] **Step 2: Verify file exists**

```sh
ls -la /path/to/crawl-rc/tests/harness.lua
```

Expected: file exists, ~120 lines

---

### Task 2: Create `tests/test_startup.lua`

**Files:**
- Create: `tests/test_startup.lua`

This is the smoke test. It verifies BRC activates and registers at least one feature.

- [ ] **Step 1: Create `tests/test_startup.lua`**

```lua
---------------------------------------------------------------------------------------------------
-- test_startup: Smoke test — verifies BRC loads and initializes successfully.
-- This is the first test and the proof of concept for the testing framework.
---------------------------------------------------------------------------------------------------

test_startup = {}
test_startup.BRC_FEATURE_NAME = "test-startup"

function test_startup.ready()
  -- BRC.active is false on turn 0; wait until turn 1 when BRC activates
  if you.turns() < 1 then return end

  -- T.run wraps logic in pcall so Lua errors produce [ERROR] lines instead of hanging crawl
  T.run("startup", function()

    -- BRC should be active by turn 1
    T.true_(BRC.active, "brc-active")

    -- Features table should exist and be non-empty
    local features = BRC.get_registered_features()
    T.true_(features ~= nil, "features-not-nil")

    local count = 0
    for _ in pairs(features) do count = count + 1 end
    T.true_(count > 0, "features-registered")

    -- Overall test pass
    T.pass("startup")
    T.done()

  end) -- T.run handles errors; caller must call T.done() on success path (done above)
end
```

- [ ] **Step 2: Verify file exists**

```sh
ls -la /path/to/crawl-rc/tests/test_startup.lua
```

Expected: file exists, ~30 lines

---

### Task 3: Commit the test files

- [ ] **Step 1: Stage and commit**

```sh
git -C /path/to/crawl-rc add tests/
git -C /path/to/crawl-rc commit -m "feat(tests): add test harness and startup smoke test"
```

Expected: commit created, pre-commit hook runs luacheck (harness.lua and test_startup.lua are not in `lua/` so they won't be linted by the existing hook — that's fine)

---

## Chunk 2: Runner Infrastructure

### Task 4: Create `tests/config.sh`

**Files:**
- Create: `tests/config.sh`

- [ ] **Step 1: Create `tests/config.sh`**

`config.sh` is sourced by `run.sh`, which sets `REPO_ROOT` before sourcing. `REPO_ROOT` is the absolute path to `crawl-rc/`. The default crawl binary path resolves as: `crawl-rc/../../source/crawl` → `crawl-ref/source/crawl`.

```sh
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
```

- [ ] **Step 2: Verify path is correct for your setup**

From the repo root, check that the derived path resolves to the crawl binary:
```sh
ls /Users/brian/dev/dcss/crawl/crawl-ref/source/crawl
```
Expected: crawl binary exists

---

### Task 5: Create `tests/run.sh`

**Files:**
- Create: `tests/run.sh`

This is the main test runner. It:
1. Validates prerequisites
2. For each test, builds a temp RC by injecting harness+test before `BRC.init()`
3. Runs crawl with timeout, capturing stderr
4. Parses `[PASS]`/`[FAIL]`/`[ERROR]` lines
5. Reports summary and exits appropriately

- [ ] **Step 1: Create `tests/run.sh`**

```sh
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
  echo "  Set CRAWL_BIN=/path/to/crawl or build crawl first." >&2
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

  # Run crawl with timeout
  set +e
  $TIMEOUT_CMD "${TIMEOUT_SEC}" \
    "${CRAWL_BIN_RESOLVED}" $CRAWL_FLAGS -rc "${TEMP_RC}" \
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
```

- [ ] **Step 2: Make run.sh executable**

```sh
chmod +x /path/to/crawl-rc/tests/run.sh
```

---

### Task 6: Update `package.json`

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Add `test` script to `package.json`**

Edit the `scripts` section to add:
```json
"test": "./tests/run.sh",
```

Full `scripts` section after edit:
```json
"scripts": {
  "test": "./tests/run.sh",
  "lint": "luacheck --formatter plain lua/",
  "lint:fix": "luacheck --formatter plain --fix lua/",
  "lint:quiet": "luacheck --formatter plain --quiet lua/"
},
```

---

### Task 7: Commit runner infrastructure

- [ ] **Step 1: Stage and commit**

```sh
git -C /path/to/crawl-rc add tests/config.sh tests/run.sh package.json
git -C /path/to/crawl-rc commit -m "feat(tests): add test runner (run.sh, config.sh)"
```

---

## Chunk 3: End-to-End Verification

### Task 8: Run the test suite end-to-end

This task verifies the full pipeline works: RC build → crawl launch → result parsing → exit code.

- [ ] **Step 1: Confirm crawl binary exists**

```sh
ls -la /Users/brian/dev/dcss/crawl/crawl-ref/source/crawl
```

Expected: executable file exists

- [ ] **Step 2: Run the smoke test directly**

```sh
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc
./tests/run.sh test_startup
```

Expected output (approximately):
```
  [PASS] brc-active
  [PASS] features-not-nil
  [PASS] features-registered
  [PASS] startup

────────────────────────────────────────
Results: 1/1 passed
OK
```

Exit code: 0

- [ ] **Step 3: Verify npm test also works**

```sh
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc
npm test
```

Expected: same output as step 2, exits 0

- [ ] **Step 4: Verify a failed test produces a non-zero exit**

Add a temporary failing assertion to `test_startup.lua` (e.g., `T.false_(BRC.active, "should-fail")`), run the test, confirm exit code is 1 and `[FAIL]` appears in output. Then revert.

```sh
# Add temporary failure (edit test_startup.lua to add T.false_(BRC.active, "should-fail") inside T.run())
./tests/run.sh test_startup
echo "Exit code: $?"
```

Expected:
```
  [FAIL] should-fail: expected false, got true
  ...
Results: 0/1 passed
FAILED
```
Exit code: 1

Revert the temporary change before committing:
```sh
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc restore tests/test_startup.lua
```

- [ ] **Step 5: Commit verification result (if any fixes were needed)**

```sh
git -C /path/to/crawl-rc add -p   # stage only real fixes
git -C /path/to/crawl-rc commit -m "fix(tests): <describe what was fixed>"
```

---

## Troubleshooting

**Problem: No output / crawl exits immediately**
- Check stderr log at `/tmp` for Lua errors
- Verify `buehler.rc` builds correctly: `node build/concat_rc.js`
- Run crawl manually: `./crawl -headless -seed 1 -no-save -name brc_test -wizard -no-throttle -rc /tmp/manual_test.rc`

**Problem: `[PASS]` lines not appearing in output**
- `io.stderr:write()` may not be available in this crawl build's Lua
- Fallback: replace `io.stderr:write(line .. "\n")` with `crawl.mpr(line)` in harness.lua
  - Note: with the Testing config, `crawl.mpr()` goes to stderr via `logs_to_stderr = true`
  - Grep for the lines in the combined output file instead

**Problem: BRC prompts for config selection (hangs)**
- Verify `BRC.Config.to_use = "Testing"` line in `harness.lua` is injected before `BRC.init()`
- Check `INIT_LINE` is being found correctly: `grep -n "^BRC\.init()$" bin/buehler.rc`

**Problem: `T.done()` doesn't quit crawl**
- Try `crawl.sendkeys("Sy")` (S followed by y to confirm) instead of just `"S"`
- Or rely on the 30-second timeout to kill crawl (increase `T.timeout_turns` to avoid false timeout failures)

**Problem: macOS `timeout` not found**
- Install: `brew install coreutils` (provides `gtimeout`)
