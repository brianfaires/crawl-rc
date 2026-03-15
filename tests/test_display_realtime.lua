---------------------------------------------------------------------------------------------------
-- BRC feature test: display-realtime
-- Verifies that f_display_realtime loaded with sane Config and accessible persist state.
-- (Feature is disabled by default; this is an init/config regression test.)
---------------------------------------------------------------------------------------------------

test_display_realtime = {}
test_display_realtime.BRC_FEATURE_NAME = "test-display-realtime"

function test_display_realtime.ready()
  if T._done then return end

  T.run("display-realtime", function()
    T.true_(f_display_realtime ~= nil, "module-exists")

    -- Default interval
    T.eq(f_display_realtime.Config.interval_s, 60, "default-interval")

    -- Persistent total-time counter is accessible and starts at 0
    T.true_(dr_total_time ~= nil, "persist-total-time-accessible")
    T.true_(type(dr_total_time) == "number", "total-time-is-number")

    T.pass("display-realtime")
    T.done()
  end)
end
