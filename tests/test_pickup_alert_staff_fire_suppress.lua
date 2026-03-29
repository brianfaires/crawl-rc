---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert staff of fire alert
-- Verifies that alert_staff fires for a "staff of fire" when the character has no rF+.
--
-- Character: Mummy Berserker (no innate rF+).
--
-- alert_staff flow (pa-misc.lua lines ~58-95):
--   basename == "staff of fire" → check you.res_fire() > 0 → false (Mummy has no rF+)
--   tag = "rF+", tag_color = lightred
--   scan inventory for matching tag → none found (floor item, not in inventory)
--   fire do_alert(it, "Staff resistance (rF+)", E.STAFF_RES, M.staff_resists)
--
-- Note on inventory suppression path (lines ~87-91):
--   If an inventory item's name("plain") contains "rF+", alert is suppressed.
--   This path requires the staff to be in inventory, which is hard to fake
--   without actual pickup. That path is not tested here (P1-Hard).
--
-- BRC.mpr.que_optmore queues messages; consume_queue() fires after all ready() hooks.
-- So "check" phase calls alert (queues message) + CMD_WAIT, then "verify" checks T.last_messages.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "staff of fire"; identify; CMD_WAIT → turn 1
--   "check"  (turn 1): call f_pa_misc.alert_staff directly; CMD_WAIT → turn 2
--   "verify" (turn 2): assert T.last_messages contains "Staff resistance"
---------------------------------------------------------------------------------------------------

test_pickup_alert_staff_fire_suppress = {}
test_pickup_alert_staff_fire_suppress.BRC_FEATURE_NAME = "test-pickup-alert-staff-fire-suppress"

local _phase = "give"
local _floor_staff = nil

function test_pickup_alert_staff_fire_suppress.ready()
  if T._done then return end

  T.run("pickup-alert-staff-fire-suppress", function()

    -- ── Phase 1: place staff of fire on the floor ───────────────────────────────────────────
    if _phase == "give" then
      T.wizard_give("staff of fire")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    -- ── Phase 2: call alert_staff directly (queues message) ─────────────────────────────────
    elseif _phase == "check" then

      -- Find staff of fire on floor
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_magic_staff(it) and it.name("base"):find("fire") then
          _floor_staff = it
          break
        end
      end
      T.true_(_floor_staff ~= nil, "staff-of-fire-on-floor")
      if not _floor_staff then T.done() return end

      crawl.stderr("floor_staff name(): "      .. tostring(_floor_staff.name()))
      crawl.stderr("floor_staff name(base): "  .. tostring(_floor_staff.name("base")))
      crawl.stderr("you.res_fire(): "           .. tostring(you.res_fire()))

      -- Suppress force_more for staff_resists to prevent headless hang.
      local M = f_pickup_alert.Config.Alert.More
      local orig_staff_resists = M.staff_resists
      M.staff_resists = false

      -- Forget any prior alert record so already_alerted() doesn't short-circuit
      f_pa_data.forget_alert(_floor_staff)

      -- Call alert_staff — should queue "Staff resistance" message for Mummy with no rF+
      local result = f_pa_misc.alert_staff(_floor_staff)

      M.staff_resists = orig_staff_resists

      crawl.stderr("alert_staff result: " .. tostring(result))

      -- Alert must fire (Mummy has no rF+, nothing in inventory covers rF+)
      T.true_(result ~= nil and result ~= false, "staff-fire-alert-fires")

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- consume_queue() fires during BRC.ready() this turn

    -- ── Phase 3: verify message was output ──────────────────────────────────────────────────
    elseif _phase == "verify" then
      T.true_(T.messages_contain("Staff resistance"), "staff-fire-alert-message")
      T.pass("pickup-alert-staff-fire-suppress")
      T.done()
    end
  end)
end
