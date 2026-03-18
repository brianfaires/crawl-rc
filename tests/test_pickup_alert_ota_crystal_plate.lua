---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (OTA fires for armour — crystal plate armour)
-- Verifies the one-time alert path fires for an armour item in the one_time list.
-- "crystal plate armour" is in Config.Alert.one_time.
--
-- OTA_require_skill.armour = 2.5. To isolate this test from the skill gate (tested separately),
-- OTA_require_skill.armour is temporarily set to 0.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "crystal plate armour" + identify → CMD_WAIT
--   "check"  (turn 1): call BRC.autopickup on floor items (force_more + skill gate suppressed) → CMD_WAIT
--   "verify" (turn 2): assert T.last_messages contains "Found first"
---------------------------------------------------------------------------------------------------

test_pickup_alert_ota_crystal_plate = {}
test_pickup_alert_ota_crystal_plate.BRC_FEATURE_NAME = "test-pickup-alert-ota-crystal-plate"

local _phase = "give"

function test_pickup_alert_ota_crystal_plate.ready()
  if T._done then return end

  T.run("pickup-alert-ota-crystal-plate", function()
    if _phase == "give" then
      T.wizard_give("crystal plate armour")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      local A = f_pickup_alert.Config.Alert

      -- Temporarily bypass skill gate and force_more to isolate the OTA fire path
      local orig_skill = A.OTA_require_skill.armour
      local orig_fm    = A.More.one_time_alerts
      A.OTA_require_skill.armour = 0
      A.More.one_time_alerts     = false

      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)
      end

      A.OTA_require_skill.armour = orig_skill
      A.More.one_time_alerts     = orig_fm

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.true_(
        T.messages_contain("Found first") or T.messages_contain("crystal plate"),
        "ota-crystal-plate-alert-fired"
      )
      T.pass("pickup-alert-ota-crystal-plate")
      T.done()
    end
  end)
end
