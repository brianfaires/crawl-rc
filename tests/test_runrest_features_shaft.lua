---------------------------------------------------------------------------------------------------
-- BRC feature test: runrest-features (after_shaft — rr_shaft_location tracking)
-- Verifies that c_message sets rr_shaft_location when a shaft message arrives on plain channel,
-- and that ready() clears it when back at the recorded location.
--
-- rr_shaft_location is a global persist variable; readable and writable from tests.
-- BRC.you.in_hell() returns false on D:1, so the shaft condition fires.
--
-- Tests:
--   1. plain "you ... into a shaft" message → rr_shaft_location = you.where()
--   2. non-plain channel → rr_shaft_location unchanged (nil)
--   3. already-set guard → second shaft message doesn't overwrite existing value
--   4. ready() clears rr_shaft_location when you.where() == rr_shaft_location
---------------------------------------------------------------------------------------------------

test_runrest_features_shaft = {}
test_runrest_features_shaft.BRC_FEATURE_NAME = "test-runrest-features-shaft"

function test_runrest_features_shaft.ready()
  if T._done then return end

  T.run("runrest-features-shaft", function()
    f_runrest_features.init()
    local orig_shaft = rr_shaft_location
    local here = you.where()

    -- Test 1: plain shaft message sets rr_shaft_location
    rr_shaft_location = nil
    f_runrest_features.c_message("You fall into a shaft.", "plain")
    T.eq(rr_shaft_location, here, "shaft-message-sets-location")

    -- Test 2: non-plain channel is ignored
    rr_shaft_location = nil
    f_runrest_features.c_message("You fall into a shaft.", "warn")
    T.true_(rr_shaft_location == nil, "non-plain-shaft-ignored")

    -- Test 3: already-set guard — second message doesn't overwrite
    rr_shaft_location = "D:99"
    f_runrest_features.c_message("You fall into a shaft.", "plain")
    T.eq(rr_shaft_location, "D:99", "shaft-guard-no-overwrite")

    -- Test 4: ready() clears rr_shaft_location when at the recorded location
    rr_shaft_location = here
    f_runrest_features.ready()
    T.true_(rr_shaft_location == nil, "ready-clears-shaft-on-return")

    rr_shaft_location = orig_shaft
    T.pass("runrest-features-shaft")
    T.done()
  end)
end
