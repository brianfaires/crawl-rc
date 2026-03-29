---------------------------------------------------------------------------------------------------
-- BRC feature test: misc-alerts (init() behavioral tests)
-- Verifies two init() side effects on global persist variables:
--
-- 1. ma_found_altar auto-set when preferred_god == "" (empty = disabled).
--    f_misc_alerts.init() sets ma_found_altar = true to suppress altar monitoring.
--
-- 2. ma_saved_msg cleared on init when non-empty (and printed as "MESSAGE: ...").
--    init() prints the saved message on startup then clears it.
---------------------------------------------------------------------------------------------------

test_misc_alerts_init = {}
test_misc_alerts_init.BRC_FEATURE_NAME = "test-misc-alerts-init"

function test_misc_alerts_init.ready()
  if T._done then return end

  T.run("misc-alerts-init", function()
    -- Save state
    local orig_found_altar = ma_found_altar
    local orig_saved_msg   = ma_saved_msg

    -- Test 1: preferred_god == "" → ma_found_altar set to true in init()
    ma_found_altar = false
    local orig_god = f_misc_alerts.Config.preferred_god
    f_misc_alerts.Config.preferred_god = ""
    f_misc_alerts.init()
    T.true_(ma_found_altar, "empty-preferred-god-sets-found-altar")
    f_misc_alerts.Config.preferred_god = orig_god

    -- Test 2: non-empty ma_saved_msg is cleared by init()
    ma_saved_msg = "hello from test"
    f_misc_alerts.init()
    T.eq(ma_saved_msg, "", "init-clears-saved-msg")

    -- Restore state
    ma_found_altar = orig_found_altar
    ma_saved_msg   = orig_saved_msg

    T.pass("misc-alerts-init")
    T.done()
  end)
end
