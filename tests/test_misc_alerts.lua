---------------------------------------------------------------------------------------------------
-- BRC feature test: misc-alerts
-- Verifies that f_misc_alerts loaded with sane Config and accessible persist state.
---------------------------------------------------------------------------------------------------

test_misc_alerts = {}
test_misc_alerts.BRC_FEATURE_NAME = "test-misc-alerts"

function test_misc_alerts.ready()
  if T._done then return end

  T.run("misc-alerts", function()
    T.true_(f_misc_alerts ~= nil, "module-exists")

    -- Default low-HP threshold is 35%
    T.eq(f_misc_alerts.Config.alert_low_hp_threshold, 35, "hp-threshold-default")

    -- Persistent state is accessible (globals set by BRC.Data.persist)
    T.true_(ma_alerted_max_piety ~= nil, "persist-max-piety-accessible")
    T.true_(ma_saved_msg ~= nil, "persist-saved-msg-accessible")
    T.true_(ma_found_altar ~= nil, "persist-found-altar-accessible")

    -- ma_saved_msg starts empty (init clears it after displaying)
    T.true_(type(ma_saved_msg) == "string", "saved-msg-is-string")

    T.pass("misc-alerts")
    T.done()
  end)
end
