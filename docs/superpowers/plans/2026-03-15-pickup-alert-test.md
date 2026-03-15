# pickup-alert test Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `T.wizard_give` in the test harness and write `test_pickup_alert.lua`, the first BRC feature test.

**Architecture:** Two files change. `harness.lua` gains a real `T.wizard_give` (replaces stub) plus a `T.wizard_identify_all` helper. `test_pickup_alert.lua` is a new standalone test that uses those helpers plus a 2-phase ready() state machine to verify the pickup-alert feature fires for a wizard-placed weapon.

**Tech Stack:** Lua (DCSS sandbox), `npm test` / `./tests/run.sh` for verification.

---

## Chunk 1: T.wizard_give + test_pickup_alert.lua

### Task 1: Implement T.wizard_give in harness.lua

**Files:**
- Modify: `tests/harness.lua` (wizard helpers section, lines 138–153)

Background: `crawl.sendkeys(str)` appends to `macro_buf`. `crawl.do_commands({"CMD_WIZARD"})` fires `handle_wizard_command()`, which reads the next key from `macro_buf`. The flush inside `do_commands` is a no-op by default, so pre-queued keys survive. Wizard subcommand `'%'` → `wizard_create_spec_object_by_name()` reads the item name from `macro_buf` (via `cancellable_get_line_autohist` → `getchm`). Wizard subcommand `'y'` → `wizard_identify_all_items()` — no further input needed; identifies all items (floor + inventory) immediately.

- [ ] **Step 1: Replace the three wizard stubs in tests/harness.lua**

The current stubs are lines 137–152:
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

Replace with:
```lua
function T.wizard_give(item_spec)
  -- Pre-queue '%' + item name + Enter; CMD_WIZARD reads them from macro_buf.
  -- flush_input_buffer(FLUSH_BEFORE_COMMAND) inside do_commands is a no-op by
  -- default, so the pre-queued keys survive.
  crawl.sendkeys("%" .. item_spec .. "\r")
  crawl.do_commands({"CMD_WIZARD"})
  -- Item now exists on the floor at you.pos()
end

function T.wizard_identify_all()
  -- 'y' subcommand -> wizard_identify_all_items() (wizard.cc:172).
  -- No further input needed; identifies floor + inventory items immediately.
  crawl.sendkeys("y")
  crawl.do_commands({"CMD_WIZARD"})
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

- [ ] **Step 2: Verify test_startup still passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc
./tests/run.sh test_startup
```

Expected output includes:
```
  [PASS] brc-active
  [PASS] features-not-nil
  [PASS] features-registered
  [PASS] startup
```
and ends with `OK`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/harness.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "feat(tests): implement T.wizard_give and T.wizard_identify_all"
```

---

### Task 2: Write test_pickup_alert.lua

**Files:**
- Create: `tests/test_pickup_alert.lua`

Background on the state machine:

`test.ready()` is registered as BRC feature "test-harness". Features are registered alphabetically; ready() hooks are called in reverse order. "test-harness" > "pickup-alert" alphabetically, so `test.ready()` runs **before** `f_pickup_alert.ready()` each cycle.

`f_pickup_alert.autopickup()` has a guard: `if you.turns() ~= pa_last_ready_turn then`. `pa_last_ready_turn` is set by `f_pickup_alert.ready()` at the start of each cycle. Since test.ready() runs first, at turn 1 the test sees `pa_last_ready_turn = 0` (from turn 0) — the guard passes and alerts can fire.

At turn 0 both are 0 (pa_last_ready_turn is initialized in `f_pickup_alert.init()`), so the guard blocks at turn 0. The "advance" phase calls CMD_WAIT to reach turn 1.

`BRC.autopickup(it)` (brc.lua:336) calls `safe_call_all_hooks("autopickup", it)`, which dispatches to `f_pickup_alert.autopickup(it)`. DCSS's native autopickup (`request_autopickup()`) does NOT fire on CMD_WAIT or wizard item creation, so we call it directly.

`BRC.mpr.consume_queue()` fires at the end of each `BRC.ready()` cycle, flushing queued messages to `crawl.mpr()`, which triggers `c_message`. `T.c_message` captures each message into `T.last_messages`. Since consume_queue runs after the feature ready() hooks, messages queued during turn 1's inner ready() are in `T.last_messages` by the time CMD_WAIT returns to turn 0's "advance" code.

- [ ] **Step 1: Create tests/test_pickup_alert.lua**

```lua
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert
-- Wizard-gives a branded weapon and verifies that pickup-alert fires an alert message.
---------------------------------------------------------------------------------------------------

local test_pickup_alert = {}
test_pickup_alert.BRC_FEATURE_NAME = "test-pickup-alert"

local _phase = "advance"

function test_pickup_alert.ready()
  if T._done then return end

  T.run("pickup-alert", function()
    if _phase == "advance" then
      -- Turn 0: pa_last_ready_turn = 0 = you.turns() → alert guard would block.
      -- CMD_WAIT advances to turn 1; inner ready() fires and executes "give" phase.
      _phase = "give"
      crawl.do_commands({"CMD_WAIT"})
      -- Execution resumes here after CMD_WAIT and its inner ready() have fully returned.
      -- Inner ready's consume_queue() already flushed the alert into T.last_messages.
      T.true_(T.messages_contain("flaming"), "alert-fired")
      T.pass("pickup-alert")
      T.done()

    elseif _phase == "give" then
      -- Turn 1: test.ready() runs before f_pickup_alert.ready() updates pa_last_ready_turn.
      -- you.turns() = 1, pa_last_ready_turn = 0 → alert guard passes.
      T.wizard_give("short sword of flaming")
      T.wizard_identify_all()  -- ensure it.is_identified = true (guard in f_pickup_alert.autopickup)
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)  -- dispatches to f_pickup_alert.autopickup(it) → queues alert
      end
      _phase = "done"  -- re-entry guard; actual assertion is inline in "advance" above
    end
  end)
end
```

- [ ] **Step 2: Run the full test suite**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc
npm test
```

Expected:
```
  [PASS] brc-active
  [PASS] features-not-nil
  [PASS] features-registered
  [PASS] startup
  [PASS] alert-fired
  [PASS] pickup-alert

Results: 2/2 passed — OK
```

If `test_pickup_alert` fails with `[FAIL] alert-fired: expected true, got false`:
- Check whether `it.is_identified` is still false despite `wizard_identify_all`. Run `./tests/run.sh test_pickup_alert` and look at full stderr for any BRC error messages.
- If so, the item spec may need adjustment. Try `"short sword {ego:flaming}"` or `"short sword of flaming id:all"` as the item spec string.

If the test hangs and times out:
- Likely the CMD_WAIT inner ready() is not triggering. Check that the harness RC is valid by running `./tests/run.sh test_startup` first.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_pickup_alert.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "feat(tests): add test_pickup_alert — first BRC feature test"
```
