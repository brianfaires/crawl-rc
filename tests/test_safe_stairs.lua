---------------------------------------------------------------------------------------------------
-- BRC feature test: safe-stairs
-- Verifies Config defaults and that ready() updates ss_prev_location tracking correctly.
-- ss_prev_location is a global persist; init() sets the internal ss_cur_location (local),
-- and ready() advances ss_prev_location = ss_cur_location.
---------------------------------------------------------------------------------------------------

test_safe_stairs = {}
test_safe_stairs.BRC_FEATURE_NAME = "test-safe-stairs"

function test_safe_stairs.ready()
  if T._done then return end

  T.run("safe-stairs", function()
    T.true_(f_safe_stairs ~= nil, "module-exists")
    T.eq(f_safe_stairs.BRC_FEATURE_NAME, "safe-stairs", "feature-name")
    T.true_(f_safe_stairs.Config ~= nil, "has-config")

    -- ss_prev_location is a global persist accessible from tests
    T.true_(ss_prev_location ~= nil, "ss-prev-location-accessible")

    -- After init() + ready(), ss_prev_location reflects current location
    local orig = ss_prev_location
    ss_prev_location = "X:99"   -- force wrong value
    f_safe_stairs.init()
    f_safe_stairs.ready()
    T.eq(ss_prev_location, you.where(), "ready-updates-prev-location")
    ss_prev_location = orig

    T.pass("safe-stairs")
    T.done()
  end)
end
