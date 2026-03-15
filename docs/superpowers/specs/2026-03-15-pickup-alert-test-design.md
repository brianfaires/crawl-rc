# Design: T.wizard_give + test_pickup_alert

**Date:** 2026-03-15
**Status:** Implemented

## Scope

Implement `T.wizard_give(item_spec)` in the test harness and use it to write
`test_pickup_alert.lua` — the first BRC feature test.

Out of scope: other wizard helpers (`T.wizard_set_xl`, `T.wizard_teleport`),
other feature tests.

---

## Background

The v1 test harness has three wizard helper stubs that call `T.error_` and
`T.done()`. This spec covers implementing `T.wizard_give` and deleting the stub.

Crawl's wizard mode (`-wizard` flag already in CRAWL_FLAGS) exposes item-giving
via the `&` → `%` key sequence, which calls `wizard_create_spec_object_by_name()`.
That function reads an item name via `cancellable_get_line_autohist`, which pulls
from the same `macro_buf` as `crawl.sendkeys()`. This means the full interaction
can be driven programmatically.

---

## Component 1: T.wizard_give

**Location:** `tests/harness.lua` — replace the existing stub.

**Implementation:**
```lua
function T.wizard_give(item_spec)
  -- Pre-queue: wizard subcommand '%' + item name + Enter.
  -- cancellable_get_line_autohist reads from the same macro_buf as sendkeys.
  crawl.sendkeys("%" .. item_spec .. "\r")
  -- Execute CMD_WIZARD; handle_wizard_command() reads the pre-queued '%' and name.
  crawl.do_commands({"CMD_WIZARD"})
  -- Item now exists on the floor at you.pos()
end
```

Key facts from source:
- `wizard.cc`: `'%'` subcommand → `wizard_create_spec_object_by_name()`
- `wiz-item.cc`: calls `cancellable_get_line_autohist` → `line_reader::read_line` → `getchm`
- `macro.cc`: `getchm` reads from `macro_buf`; `crawl.sendkeys` writes to `macro_buf`
- Item is placed at `you.pos()` via `create_item_named(buf, you.pos(), &error)`
- `&` key is not remapped by any BRC macro (confirmed from init log)

**Pre-queue survival:** `crawl.do_commands` calls `flush_input_buffer(FLUSH_BEFORE_COMMAND)`
at `l-crawl.cc:603`. That flush is a no-op by default: `macro.cc:929` only actually
clears `macro_buf` when `Options.flush_input[reason]` is true or `reason` is one of
the five special FLUSH_* constants. `FLUSH_BEFORE_COMMAND` is not in that set, so
the pre-queued keys survive.

---

## Component 2: test_pickup_alert.lua

**Location:** `tests/test_pickup_alert.lua`

**What it tests:** When a notable weapon appears on the floor, BRC's pickup-alert
feature fires an alert message containing the item name.

**Test character:** Mummy Berserker, seed 1 — starts with a mace (no ego). A
weapon with a brand (e.g. "short sword of flaming") is a clear upgrade candidate
and should trigger an early-weapon alert at XL 1.

**Message flow:**
1. `BRC.autopickup(it)` is called directly from the test
   (`brc.lua:336`: `BRC.autopickup` calls `safe_call_all_hooks("autopickup", it)`,
   which dispatches to `f_pickup_alert.autopickup(it)` via the registered hook)
2. `f_pa_weapons.alert_weapon(it)` evaluates it → returns an alert table
3. `f_pickup_alert.do_alert(...)` calls `BRC.mpr.que_optmore(...)` → adds to `_mpr_queue`
4. At end of `BRC.ready()`: `consume_queue()` calls `crawl.mpr(msg)` → `c_message` fires
5. `T.c_message` captures the message into `T.last_messages`

**CMD_WAIT behavior (verified empirically):**
`crawl.do_commands({"CMD_WAIT"})` is synchronous and returns immediately to Lua
after the game processes the action. It does NOT synchronously trigger the next
`BRC.ready()` cycle — that fires in the subsequent game loop iteration. Only ONE
turn-advancing command may be issued per `ready()` invocation; a second call causes
"Cannot currently process new keys (turn is over)". Test features must be declared
as globals (not `local`) so BRC's `_G` scan in `register_all_features` finds them.

**Phase state machine (3 separate ready() calls):**
```
Phase "give" (turn 0):
  - Call T.wizard_give("short sword of flaming") → item on floor
  - Call T.wizard_identify_all() to ensure it.is_identified = true
  - Set phase = "check"
  - Call crawl.do_commands({"CMD_WAIT"}) → advances to turn 1, returns immediately
  - Return from ready()  [turn 0's consume_queue fires after this; queue is empty]

Phase "check" (turn 1, separate game loop iteration):
  - test_pickup_alert.ready() runs BEFORE f_pickup_alert.ready() (reverse alpha order)
  - pa_last_ready_turn = 0, you.turns() = 1 → alert guard passes
  - Iterate you.floor_items(); call BRC.autopickup(it) → alert queued
  - Set phase = "verify"
  - Call crawl.do_commands({"CMD_WAIT"}) → advances to turn 2, returns immediately
  - Return from ready()  [turn 1's consume_queue fires after this → T.last_messages populated]

Phase "verify" (turn 2, separate game loop iteration):
  - Assert T.messages_contain("flaming")
  - T.pass / T.done
```

**Timeout guard:** inherited from harness `T.ready()` — if neither phase completes
within `T.timeout_turns` (20), it emits `[FAIL] timeout` and quits.

**Assertion:** `T.messages_contain("flaming")` — matches against raw message text.
`c_message` at `message.cc:1566` passes raw `text.c_str()` including color tags.
`do_alert` in `pa-main.lua` wraps the item name in a color tag via
`BRC.txt[alert_col.item](string.format(" %s ", item_name))`, producing something like
`<14> short sword of flaming (+0, 7/2/1) </14>`. The word "flaming" appears inside
the tag body, not as part of the tag markup itself, so `string.find(text, "flaming")`
matches it. If `T.last_messages` is empty (queue never flushed), `T.messages_contain`
returns false (it iterates an empty table), which causes the assertion to fail.

---

## Why Direct BRC.autopickup Works

`f_pickup_alert.autopickup()` guards against re-alerting within the same turn:

```lua
if you.turns() ~= pa_last_ready_turn then
  check_and_trigger_alerts(it, unworn_aux_item)
end
```

`pa_last_ready_turn` is set to `you.turns()` at the top of `f_pickup_alert.ready()`.

**Hook call order:** BRC registers features alphabetically and calls their ready() hooks
in reverse order (`call_all_hooks` iterates `#hooks` → 1). "pickup-alert" < "test-harness"
alphabetically, so `test.ready()` runs **before** `f_pickup_alert.ready()` each cycle.

At turn 1, when `test.ready()` runs:
- `you.turns() = 1`
- `pa_last_ready_turn = 0` (set by f_pickup_alert.ready() at turn 0, not yet updated)
- `1 ≠ 0` → the alert guard passes ✓

DCSS autopickup (via `request_autopickup()`) does NOT fire on CMD_WAIT or wizard item
creation — it is only called from `stairs.cc`, `movement.cc`, and `god-abil.cc`. The
direct `BRC.autopickup(it)` call is therefore required.

**Turn 0 exception:** at turn 0, both `you.turns()` and `pa_last_ready_turn` are 0
(pa_last_ready_turn is initialized to `you.turns()` in `f_pickup_alert.init()`). The
guard would block any direct autopickup call at turn 0. The CMD_WAIT in "advance"
advances to turn 1 specifically to avoid this.

---

## Item Identification

`f_pickup_alert.autopickup()` skips unidentified branded items:
```lua
or (not it.is_identified and (it.branded or it.artefact or ...))
```

A "short sword of flaming" has a brand. To guarantee `it.is_identified` is true,
the "give" phase always calls `wizard_identify_all_items()` immediately after giving
the item, using wizard subcommand `'y'` (`wizard.cc:172`):

```lua
crawl.sendkeys("y")
crawl.do_commands({"CMD_WIZARD"})  -- 'y' reads no further input; acts immediately
```

This identifies all items on the floor and in inventory, ensuring the brand is
visible before `BRC.autopickup` is called.

---

## Files Changed

| File | Change |
|------|--------|
| `tests/harness.lua` | Replace `T.wizard_give` stub with implementation |
| `tests/test_pickup_alert.lua` | New file |
