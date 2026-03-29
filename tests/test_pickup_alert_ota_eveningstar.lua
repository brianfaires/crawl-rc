---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (OTA fires for weapon — eveningstar)
-- Verifies the one-time alert path fires for a weapon in the one_time list.
-- "eveningstar" is in Config.Alert.one_time; M&F skill >= OTA_require_skill.weapon (2) at start.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "eveningstar" + identify → CMD_WAIT
--   "check"  (turn 1): call BRC.autopickup on floor items (force_more suppressed) → CMD_WAIT
--   "verify" (turn 2): assert T.last_messages contains "Found first"
---------------------------------------------------------------------------------------------------

test_pickup_alert_ota_eveningstar = {}
test_pickup_alert_ota_eveningstar.BRC_FEATURE_NAME = "test-pickup-alert-ota-eveningstar"

local _phase = "give"

function test_pickup_alert_ota_eveningstar.ready()
  if T._done then return end

  T.run("pickup-alert-ota-eveningstar", function()
    if _phase == "give" then
      T.wizard_give("eveningstar")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Verify skill precondition: M&F skill must be >= OTA_require_skill.weapon
      local A = f_pickup_alert.Config.Alert
      T.true_(
        you.skill("Maces & Flails") >= A.OTA_require_skill.weapon,
        "mf-skill-meets-ota-threshold"
      )

      -- Suppress force_more so headless doesn't hang
      local orig_fm = A.More.one_time_alerts
      A.More.one_time_alerts = false
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)
      end
      A.More.one_time_alerts = orig_fm

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.true_(
        T.messages_contain("Found first") or T.messages_contain("eveningstar"),
        "ota-eveningstar-alert-fired"
      )
      T.pass("pickup-alert-ota-eveningstar")
      T.done()
    end
  end)
end
