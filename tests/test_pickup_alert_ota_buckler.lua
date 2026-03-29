---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (one-time alert for buckler)
-- Verifies that the OTA (one-time alert) system fires for a buckler.
--
-- "buckler" is in f_pickup_alert.Config.Alert.one_time.
-- OTA_require_skill.shield = 0, so no Shields skill needed.
-- alert_OTA(buckler): no shield currently worn → do_alert = true → fires "Found first" alert.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("buckler") + identify → CMD_WAIT
--   "check"  (turn 1): call BRC.autopickup for floor items → queues OTA alert → CMD_WAIT
--   "verify" (turn 2): assert T.last_messages contains "buckler" or "Found first"
---------------------------------------------------------------------------------------------------

test_pickup_alert_ota_buckler = {}
test_pickup_alert_ota_buckler.BRC_FEATURE_NAME = "test-pickup-alert-ota-buckler"

local _phase = "give"

function test_pickup_alert_ota_buckler.ready()
  if T._done then return end

  T.run("pickup-alert-ota-buckler", function()
    if _phase == "give" then
      T.wizard_give("buckler")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- test hook runs before f_pickup_alert.ready() (reverse alpha), so pa_last_ready_turn
      -- is still from the previous turn. you.turns() != pa_last_ready_turn passes the guard.
      --
      -- one_time_alerts force_more = true by default; disable temporarily so headless doesn't hang.
      local orig_fm = f_pickup_alert.Config.Alert.More.one_time_alerts
      f_pickup_alert.Config.Alert.More.one_time_alerts = false
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)
      end
      f_pickup_alert.Config.Alert.More.one_time_alerts = orig_fm
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- OTA alert message should contain the item name or "Found first"
      T.true_(
        T.messages_contain("buckler") or T.messages_contain("Found first"),
        "ota-buckler-alert-fired"
      )
      T.pass("pickup-alert-ota-buckler")
      T.done()
    end
  end)
end
