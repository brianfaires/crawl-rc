# BRC Automated Testing Framework — Design Spec

**Date:** 2026-03-14
**Project:** crawl-rc (BRC — Buehler RC)
**Status:** Approved

---

## Background

BRC is a modular Lua-based RC system for Dungeon Crawl Stone Soup (DCSS). It has ~6,365 lines of Lua across 27 features. Currently there is no automated testing — the only way to verify behavior is to play the game and hope the right scenarios occur. This makes regressions hard to catch, v0.35 compatibility hard to verify, and refactoring risky.

The goal of this framework is to run BRC integration tests inside a real crawl process, headlessly, from the command line.

---

## Approach

**Integration tests using crawl's stress test pattern.**

Each test:
1. Gets built into a temporary RC file: `buehler.rc` (split before `BRC.init()`) + test harness + test code + `BRC.init()` call
2. Is run as: `crawl -headless -seed 1 -no-save -wizard -no-throttle -rc /tmp/brc_test.rc`
3. Uses crawl's Lua API to exercise BRC
4. Writes `[PASS]` / `[FAIL]` / `[ERROR]` lines to stderr
5. Quits crawl when done

A shell script runner builds, launches, parses, and reports results.

**Fallback:** If the stress test pattern proves insufficient, individual tests can be adapted to use crawl's `-test` framework by placing them in crawl's `test/` directory.

---

## File Structure

```
crawl-rc/
└── tests/
    ├── run.sh                  # Main test runner
    ├── config.sh               # Crawl binary path and test settings
    ├── harness.lua             # Test harness: T.* API, lifecycle management
    └── test_startup.lua        # Smoke test: BRC loads without errors (FIRST TEST)
```

---

## RC Build Order

This is the most critical implementation detail.

`buehler.rc` ends with a `{ }` block that defines crawl hook functions (`ready()`, `c_message()`, etc.) and calls `BRC.init()`. `BRC.init()` calls `register_all_features()`, which scans `_G` for all tables with `BRC_FEATURE_NAME` set.

**To inject test features, they must be defined before `BRC.init()` runs.**

`run.sh` builds the temp RC as follows:

```sh
INIT_LINE=$(grep -n "BRC\.init()" bin/buehler.rc | tail -1 | cut -d: -f1)
head -n $((INIT_LINE - 1)) bin/buehler.rc > /tmp/brc_test.rc  # everything before BRC.init()
cat tests/harness.lua >> /tmp/brc_test.rc                      # defines T table + T.BRC_FEATURE_NAME
cat tests/test_foo.lua >> /tmp/brc_test.rc                     # defines test feature table
tail -n +$INIT_LINE bin/buehler.rc >> /tmp/brc_test.rc         # BRC.init() and hook function definitions
```

**Why this works:** Harness and test globals are defined in the same Lua scope before `BRC.init()` is called. `register_all_features()` picks them up automatically — no explicit `BRC.register()` calls needed in test files.

**Config selection:** `buehler.rc` sets `BRC.Config.to_use = "ask"` in `_header.lua`. `harness.lua` must override this with `BRC.Config.to_use = "Testing"` before `BRC.init()` runs. Since the harness is injected before `BRC.init()`, this line in `harness.lua` runs at the right time:

```lua
BRC.Config.to_use = "Testing"  -- Override before BRC.init() sees it
```

This uses the existing Testing config (which sets `logs_to_stderr = true` and debug messages on), preventing any interactive config-selection prompt that would hang headless mode.

---

## Components

### `tests/run.sh`

Before running any tests, validate prerequisites:

```sh
if [ ! -f bin/buehler.rc ]; then
  echo "ERROR: bin/buehler.rc not found. Run 'node build/concat_rc.js' first." >&2
  exit 1
fi

if ! command -v timeout &>/dev/null && ! command -v gtimeout &>/dev/null; then
  echo "ERROR: 'timeout' command not found. On macOS: brew install coreutils" >&2
  exit 1
fi

# Use gtimeout on macOS (GNU coreutils), timeout on Linux
TIMEOUT_CMD=$(command -v gtimeout || command -v timeout)
```

For each `test_*.lua` file (or a specific named test if argument provided):

1. Build temp RC (as described in "RC Build Order" above)
2. Run with timeout, capturing stderr separately:
   ```sh
   $TIMEOUT_CMD $TIMEOUT_SEC $CRAWL_BIN $CRAWL_FLAGS -rc /tmp/brc_test.rc \
     > /tmp/brc_test_stdout.log \
     2> /tmp/brc_test_stderr.log
   ```
3. Parse **stderr only** for `[PASS]`/`[FAIL]`/`[ERROR]` lines
4. If no result lines found: report `[ERROR] test_foo: no output (crash, hang, or timeout)`
5. Print summary; exit 0 if all passed, 1 if any failed or errored

### `tests/config.sh`

```sh
CRAWL_BIN="${CRAWL_BIN:-../source/crawl}"   # relative to repo root
CRAWL_FLAGS="-headless -seed 1 -no-save -name brc_test -wizard -no-throttle"
TIMEOUT_SEC="${TIMEOUT_SEC:-30}"
```

### `tests/harness.lua`

Injected before `BRC.init()`. All code at the top level of this file runs during RC loading, in the same Lua scope as BRC.

#### Config override (first thing in file)

```lua
BRC.Config.to_use = "Testing"
```

#### The T table (test harness feature)

`T` is a BRC feature module. `register_all_features()` will register it automatically because `T.BRC_FEATURE_NAME` is set:

```lua
T = {}
T.BRC_FEATURE_NAME = "test-harness"
T.last_messages = {}
T.timeout_turns = 20
T._done = false
T._results = {}
```

#### Lifecycle

The harness `ready()` hook runs every turn (registered via BRC's hook system):

```lua
function T.ready()
  if T._done then return end

  -- Timeout guard
  if you.turns() >= T.timeout_turns then
    T.fail("timeout", string.format("test did not complete within %d turns", T.timeout_turns))
    T.done()
    return
  end
end
```

`T.done()` quits crawl:

```lua
function T.done()
  T._done = true
  crawl.sendkeys("S")  -- save-and-quit; with -no-save this exits cleanly
end
```

`crawl.sendkeys("S")` sends the save-quit key. Under `-no-save`, crawl exits without writing a save file. This is the correct quit mechanism for headless mode.

#### Message capture

```lua
function T.c_message(text, channel)
  table.insert(T.last_messages, {text = text, channel = channel})
end

function T.messages_contain(pattern)
  for _, msg in ipairs(T.last_messages) do
    if string.find(msg.text, pattern) then return true end
  end
  return false
end
```

#### Assertions

All assertion functions write results to stderr using `io.stderr:write()`:

```lua
function T.pass(name)
  io.stderr:write("[PASS] " .. name .. "\n")
  io.stderr:flush()
  table.insert(T._results, {status = "pass", name = name})
end

function T.fail(name, reason)
  io.stderr:write("[FAIL] " .. name .. ": " .. tostring(reason) .. "\n")
  io.stderr:flush()
  table.insert(T._results, {status = "fail", name = name})
end

function T.error_(name, msg)
  io.stderr:write("[ERROR] " .. name .. ": " .. tostring(msg) .. "\n")
  io.stderr:flush()
  table.insert(T._results, {status = "error", name = name})
end

function T.eq(actual, expected, name)
  if actual == expected then
    T.pass(name)
  else
    T.fail(name, string.format("expected %s, got %s",
      tostring(expected), tostring(actual)))
  end
end

function T.true_(val, name)
  if val then T.pass(name) else T.fail(name, "expected true, got " .. tostring(val)) end
end

function T.false_(val, name)
  if not val then T.pass(name) else T.fail(name, "expected false, got " .. tostring(val)) end
end

function T.contains(str, pattern, name)
  if string.find(tostring(str), pattern) then
    T.pass(name)
  else
    T.fail(name, string.format("pattern %q not found in %q", pattern, tostring(str)))
  end
end
```

#### Test runner helper

To prevent BRC's `handle_feature_error` interactive prompt (which hangs headless mode) from firing on test errors, test files must catch their own Lua errors. The harness provides `T.run()` to make this easy:

```lua
function T.run(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    T.error_(name, err)
    T.done()
  end
end
```

Test files use this pattern:

```lua
function my_test.ready()
  if you.turns() < 1 then return end  -- BRC.active is false on turn 0
  T.run("my-test", function()
    T.true_(BRC.active, "brc-active")
    -- ... more assertions ...
    T.pass("my-test")
    T.done()
  end)
end
```

#### Wizard helpers (v2 — stubs only in v1)

```lua
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

### `tests/test_startup.lua`

The first test. Verifies BRC initializes successfully.

```lua
test_startup = {}
test_startup.BRC_FEATURE_NAME = "test-startup"

function test_startup.ready()
  -- BRC.active is false on turn 0; wait until turn 1
  if you.turns() < 1 then return end

  T.run("startup", function()
    T.true_(BRC.active, "brc-active")

    local features = BRC.get_registered_features()
    T.true_(features ~= nil, "features-not-nil")

    local count = 0
    for _ in pairs(features) do count = count + 1 end
    T.true_(count > 0, "features-registered")

    T.pass("startup")
    T.done()
  end)
end
```

---

## Result Protocol

Test result lines are written to **stderr only**, using the format:

```
[PASS] <name>
[FAIL] <name>: <reason>
[ERROR] <name>: <reason>
```

The runner treats:
- At least one `[PASS]`, no `[FAIL]`/`[ERROR]` → **passed**
- Any `[FAIL]` or `[ERROR]` → **failed**
- No result lines at all → **error** (crash, hang, or timeout)

---

## `package.json` Change

Add a `test` script to `package.json`:

```json
"scripts": {
  "test": "./tests/run.sh",
  ...
}
```

---

## Running Tests

```sh
# Run all tests
./tests/run.sh

# Run a specific test
./tests/run.sh test_startup

# Via npm
npm test
```

**Prerequisites:**
- A local crawl build (v0.34 or v0.35-dev); path configured in `tests/config.sh` or `$CRAWL_BIN`
- `bin/buehler.rc` built (run `node build/concat_rc.js` if not current)
- `timeout` command available (Linux: built-in; macOS: `brew install coreutils`)

---

## Success Criteria for v1

The framework is successful when:
1. `./tests/run.sh` validates prerequisites and fails fast with a clear error if they are missing
2. `test_startup` passes — BRC loads, initializes, and reports active with features registered
3. A failed assertion produces a `[FAIL]` line and non-zero exit from `run.sh`
4. A Lua error in test code produces an `[ERROR]` line rather than a hang or silent failure
5. Total wall-clock time for the startup test is under 30 seconds

---

## Future Tests (Out of Scope for v1)

- `test_pickup_alert.lua` — wizard-give a weapon, assert alert message fires
- `test_announce_hp_mp.lua` — wizard-set HP, assert HP meter message
- `test_inscribe_stats.lua` — pick up armor, assert stat inscription added
- `test_no_regressions.lua` — loads all features and runs 10 turns without errors
