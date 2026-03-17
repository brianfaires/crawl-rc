---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (one-time alert for kite shield)
-- Verifies that the OTA (one-time alert) system fires for a kite shield.
--
-- "kite shield" is in f_pickup_alert.Config.Alert.one_time.
-- OTA_require_skill.shield = 0, so no Shields skill needed.
-- alert_OTA(kite shield): player NOT wearing a tower shield → do_alert = true → fires "Found first" alert.
-- After alert fires, "kite shield" is removed from pa_OTA_items.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("kite shield") + identify → CMD_WAIT
--   "check"  (turn 1): call BRC.autopickup for floor items → queues OTA alert → CMD_WAIT
--   "verify" (turn 2): assert T.last_messages contains "kite shield" or "Found first"
--                      assert "kite shield" no longer in pa_OTA_items
---------------------------------------------------------------------------------------------------

test_pickup_alert_ota_kite_shield = {}
test_pickup_alert_ota_kite_shield.BRC_FEATURE_NAME = "test-pickup-alert-ota-kite-shield"

local _phase = "give"

function test_pickup_alert_ota_kite_shield.ready()
  if T._done then return end

  T.run("pickup-alert-ota-kite-shield", function()
    if _phase == "give" then
      T.wizard_give("kite shield")
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
        T.messages_contain("kite shield") or T.messages_contain("Found first"),
        "ota-kite-shield-alert-fired"
      )

      -- After alert, kite shield should be removed from OTA list
      local still_in_ota = false
      for _, v in ipairs(pa_OTA_items) do
        if v == "kite shield" then still_in_ota = true end
      end
      T.false_(still_in_ota, "kite-shield-removed-from-ota")

      T.pass("pickup-alert-ota-kite-shield")
      T.done()
    end
  end)
end
