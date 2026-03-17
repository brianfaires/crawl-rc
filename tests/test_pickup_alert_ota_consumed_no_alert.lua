---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (OTA consumed - no second alert)
-- Verifies that after the buckler OTA fires and removes "buckler" from pa_OTA_items,
-- a second encounter with a buckler produces no OTA alert.
--
-- This exercises the known behavior in alert_OTA:
--   f_pa_data.remove_OTA(it) is called unconditionally before the do_alert guard,
--   so the OTA entry is consumed on first encounter. A second buckler sees no OTA entry
--   and alert_OTA returns nil immediately.
--
-- Phase flow:
--   "pre_check"    (turn 0): assert "buckler" IS in pa_OTA_items before any encounter
--                            wizard_give first buckler + identify → CMD_WAIT
--   "check_first"  (turn 1): call BRC.autopickup on floor buckler (fires OTA, removes entry)
--                            → CMD_WAIT
--   "verify_first" (turn 2): assert "Found first" alert fired for first buckler
--                            assert "buckler" is NO LONGER in pa_OTA_items
--                            wizard_give second buckler → CMD_WAIT
--   "check_second" (turn 3): clear message buffer, call BRC.autopickup on floor items → CMD_WAIT
--   "verify_second"(turn 4): assert NO "Found first" alert for second buckler
---------------------------------------------------------------------------------------------------

test_pickup_alert_ota_consumed_no_alert = {}
test_pickup_alert_ota_consumed_no_alert.BRC_FEATURE_NAME = "test-pickup-alert-ota-consumed-no-alert"

local _phase = "pre_check"

local function buckler_in_ota()
  for _, v in ipairs(pa_OTA_items) do
    if v == "buckler" then return true end
  end
  return false
end

function test_pickup_alert_ota_consumed_no_alert.ready()
  if T._done then return end

  T.run("pickup-alert-ota-consumed-no-alert", function()

    if _phase == "pre_check" then
      -- Verify "buckler" is in pa_OTA_items before any encounter
      T.true_(buckler_in_ota(), "buckler-in-ota-initially")
      T.wizard_give("buckler")
      T.wizard_identify_all()
      _phase = "check_first"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check_first" then
      -- test hook runs before f_pickup_alert.ready() (reverse alpha), so
      -- pa_last_ready_turn is still from the previous turn — the guard passes.
      -- Disable one_time_alerts force_more so headless mode doesn't hang.
      local orig_fm = f_pickup_alert.Config.Alert.More.one_time_alerts
      f_pickup_alert.Config.Alert.More.one_time_alerts = false
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)
      end
      f_pickup_alert.Config.Alert.More.one_time_alerts = orig_fm
      _phase = "verify_first"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify_first" then
      -- First buckler should have triggered the OTA alert
      T.true_(
        T.messages_contain("buckler") or T.messages_contain("Found first"),
        "ota-first-buckler-alert-fired"
      )
      -- OTA entry for "buckler" must now be gone
      T.false_(buckler_in_ota(), "buckler-removed-from-ota-after-first")

      -- Give a second buckler for the follow-up check
      T.wizard_give("buckler")
      T.wizard_identify_all()
      -- Clear the message buffer so we get a clean slate for the second check
      T.last_messages = {}
      _phase = "check_second"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check_second" then
      -- Clear messages again right before autopickup to capture only this turn's alerts
      T.last_messages = {}
      local orig_fm = f_pickup_alert.Config.Alert.More.one_time_alerts
      f_pickup_alert.Config.Alert.More.one_time_alerts = false
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)
      end
      f_pickup_alert.Config.Alert.More.one_time_alerts = orig_fm
      _phase = "verify_second"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify_second" then
      -- Second buckler must NOT fire a "Found first" OTA alert (OTA was already consumed)
      T.false_(
        T.messages_contain("Found first"),
        "ota-second-buckler-no-alert"
      )
      -- "buckler" should still be absent from pa_OTA_items
      T.false_(buckler_in_ota(), "buckler-still-absent-from-ota-after-second")

      T.pass("pickup-alert-ota-consumed-no-alert")
      T.done()
    end

  end)
end
