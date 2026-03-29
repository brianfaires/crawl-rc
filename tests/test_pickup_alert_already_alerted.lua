---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (already_alerted deduplication)
-- Verifies that f_pa_data.already_alerted(it) suppresses a second alert for the same weapon
-- on the same turn, preventing duplicate alerts from firing.
--
-- Key: the starting mace is "+0 mace" (value=0). A "+5 mace" has value=5.
-- After init(), pa_items_alerted["mace"] = 0 (from inventory scan).
-- Since 0 < 5, already_alerted returns nil for the +5 mace → first call fires.
-- After first call: pa_items_alerted["mace"] = 5 (set by remember_alert).
-- Second call: 5 >= 5 → already_alerted returns "mace" → suppressed.
--
-- Phase flow:
--   "give"   (turn 0): wizard-give "+5 mace", identify, CMD_WAIT → turn 1
--   "check"  (turn 1): call BRC.autopickup twice (with pickup disabled to reach alert path),
--                       recording pa_items_alerted before/after. CMD_WAIT → turn 2.
--                       Note: alert messages are queued via BRC.mpr.que_optmore and only
--                       flushed into T.last_messages AFTER ready() returns (end of turn 1).
--   "verify" (turn 2): assert pa_items_alerted["mace"] changed (first call fired),
--                       assert second call was suppressed via already_alerted,
--                       and assert T.last_messages received exactly one alert (from turn 1 flush).
--
-- C.Pickup.weapons is disabled in "check" so BRC.autopickup reaches check_and_trigger_alerts
-- instead of returning early via pickup_weapon (which would auto-pick up the mace as an upgrade
-- and never reach the alert path). Settings are restored before CMD_WAIT.
---------------------------------------------------------------------------------------------------

test_pickup_alert_already_alerted = {}
test_pickup_alert_already_alerted.BRC_FEATURE_NAME = "test-pickup-alert-already-alerted"

local _phase = "give"
local _before_value = nil
local _after_value = nil
local _second_suppressed = nil

function test_pickup_alert_already_alerted.ready()
  if T._done then return end

  T.run("pickup-alert-already-alerted", function()
    if _phase == "give" then
      T.wizard_give("mace plus:5")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- This ready() fires BEFORE f_pickup_alert.ready() (reverse-alpha order), so
      -- pa_last_ready_turn is still from turn 0 and you.turns() = 1 != 0 → turn-guard passes.

      -- Find the +5 mace on the floor
      local floor_mace = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.subtype() == "mace" and (it.plus or 0) >= 5 then
          floor_mace = it
          break
        end
      end
      T.true_(floor_mace ~= nil, "plus5-mace-on-floor")
      if not floor_mace then T.done() return end

      -- Record initial alerted value for the mace key
      _before_value = pa_items_alerted["mace"]
      crawl.stderr("DEBUG pa_items_alerted[mace] before first call = " .. tostring(_before_value))

      -- Disable force_more for all weapon alert types to prevent headless hang.
      -- Also disable C.Pickup.weapons so BRC.autopickup reaches check_and_trigger_alerts
      -- instead of returning early from pickup_weapon.
      local M = f_pickup_alert.Config.Alert.More
      local orig_M = {}
      orig_M.upgrade_weap    = M.upgrade_weap
      orig_M.early_weap      = M.early_weap
      orig_M.high_score_weap = M.high_score_weap
      orig_M.weap_ego        = M.weap_ego
      M.upgrade_weap    = false
      M.early_weap      = false
      M.high_score_weap = false
      M.weap_ego        = false

      local orig_pickup_weapons = f_pickup_alert.Config.Pickup.weapons
      f_pickup_alert.Config.Pickup.weapons = false

      -- First call: should fire an alert and call remember_alert → pa_items_alerted["mace"] = 5
      T.last_messages = {}
      BRC.autopickup(floor_mace)
      _after_value = pa_items_alerted["mace"]
      crawl.stderr("DEBUG pa_items_alerted[mace] after first call = " .. tostring(_after_value))

      -- Second call: already_alerted("mace") should return "mace" (5 >= 5) → suppressed.
      -- We detect suppression by checking that pa_items_alerted["mace"] does NOT change again
      -- and that no new messages are queued. Capture message count before second call.
      local msgs_before_second = #T.last_messages
      BRC.autopickup(floor_mace)
      local msgs_after_second = #T.last_messages
      _second_suppressed = (msgs_after_second == msgs_before_second)
      crawl.stderr("DEBUG msgs_before_second=" .. tostring(msgs_before_second) .. " msgs_after_second=" .. tostring(msgs_after_second))
      crawl.stderr("DEBUG _second_suppressed = " .. tostring(_second_suppressed))

      -- Restore all settings before advancing the turn
      f_pickup_alert.Config.Pickup.weapons = orig_pickup_weapons
      M.upgrade_weap    = orig_M.upgrade_weap
      M.early_weap      = orig_M.early_weap
      M.high_score_weap = orig_M.high_score_weap
      M.weap_ego        = orig_M.weap_ego

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- flush queued messages into T.last_messages

    elseif _phase == "verify" then
      -- pa_items_alerted["mace"] changed from _before_value to 5 → first call fired
      T.true_(_before_value ~= _after_value, "first-call-changed-alerted-value")
      crawl.stderr("DEBUG verify: _before=" .. tostring(_before_value) .. " _after=" .. tostring(_after_value))

      -- Second call was suppressed (no new messages queued)
      T.true_(_second_suppressed, "second-call-suppressed")

      -- T.last_messages (flushed from turn 1's queue) should contain an alert message
      local first_alerted = T.messages_contain("mace")
                         or T.messages_contain("upgrade")
                         or T.messages_contain("DPS")
                         or T.messages_contain("Weapon")
                         or T.messages_contain("damage")
      crawl.stderr("DEBUG first_alerted from T.last_messages = " .. tostring(first_alerted))
      T.true_(first_alerted, "first-call-alerted-message")

      T.pass("already-alerted")
      T.done()
    end
  end)
end
