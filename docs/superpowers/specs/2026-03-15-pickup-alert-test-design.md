# Design: T.wizard_give + test_pickup_alert

**Date:** 2026-03-15
**Status:** Approved

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
  -- Pre-queue: wizard subcommand '%' + item name + Enter
  -- cancellable_get_line_autohist reads from the same macro_buf as sendkeys
  crawl.sendkeys("%" .. item_spec .. "\r")
  -- Execute CMD_WIZARD synchronously; it reads the pre-queued subcommand and name
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

---

## Component 2: test_pickup_alert.lua

**Location:** `tests/test_pickup_alert.lua`

**What it tests:** When a notable weapon appears on the floor, BRC's pickup-alert
feature fires an alert message containing the item name.

**Test character:** Mummy Berserker, seed 1 — starts with a mace (no ego). A
weapon with a brand (e.g. "short sword of flaming") is a clear upgrade candidate
and should trigger an alert.

**Message flow:**
1. `f_pickup_alert.autopickup(it)` is called when autopickup runs on the floor item
2. `f_pa_weapons.alert_weapon(it)` evaluates it → returns an alert table
3. `f_pickup_alert.do_alert(...)` calls `BRC.mpr.que_optmore(...)` → adds to `_mpr_queue`
4. At end of `BRC.ready()`: `consume_queue()` calls `crawl.mpr(msg)` → `c_message` fires
5. `T.c_message` captures the message into `T.last_messages`

Because consume_queue fires at the END of the ready() cycle, the message is
available in `T.last_messages` on the NEXT ready() call.

**Phase state machine:**
```
Phase "give" (first ready() call):
  - Call T.wizard_give("short sword of flaming")
  - Call crawl.do_commands({"CMD_WAIT"}) to take a turn and trigger autopickup
  - Set phase = "check"
  - [BRC.ready() ends: consume_queue runs, T.c_message captures any alert]

Phase "check" (next ready() call):
  - Assert T.messages_contain("flaming") — item name appears in alert message
  - T.pass / T.done
```

**Timeout guard:** inherited from harness `T.ready()` — if neither phase completes
within `T.timeout_turns` (20), it emits `[FAIL] timeout` and quits.

**Assertion:** `T.messages_contain("flaming")` — matches against raw message text
including color markup. "flaming" appears in the item name portion of the alert
(`f_pickup_alert.do_alert` includes `item_name` in the message tokens), so it
survives color-code wrapping.

---

## Risk: CMD_WAIT timing

`crawl.do_commands({"CMD_WAIT"})` is called from within a `ready()` hook. This is
the standard pattern used by qw.rc for all autonomous actions. It advances the
game clock, runs `world_reacts()`, and triggers autopickup on floor items.

If autopickup does NOT run on CMD_WAIT (e.g. the item was already auto-evaluated
at wizard-give time), the phase "check" assertion may still pass because pickup-alert
could have queued the alert via a different path. If the test fails on first run, the
fix is to add an additional `CMD_WAIT` turn before the "check" phase.

---

## Files Changed

| File | Change |
|------|--------|
| `tests/harness.lua` | Replace `T.wizard_give` stub with implementation |
| `tests/test_pickup_alert.lua` | New file |
