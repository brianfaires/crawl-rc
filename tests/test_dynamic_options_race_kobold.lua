-- @species Ko
-- @background Be
-- @weapon shortsword
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Kobold race table classification)
-- Kobold is SMALL (SIZE_PENALTY.SMALL). Not LITTLE or LARGE.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_kobold = {}
test_dynamic_options_race_kobold.BRC_FEATURE_NAME = "test-dynamic-options-race-kobold"

function test_dynamic_options_race_kobold.ready()
  if T._done then return end

  T.run("dynamic-options-race-kobold", function()
    local race = you.race()
    T.eq(race, "Kobold", "char-is-kobold")

    T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.SMALL, "kobold-small-size-penalty")
    T.true_(util.contains(BRC.SMALL_RACES,   race), "kobold-in-small-races")

    T.false_(util.contains(BRC.LITTLE_RACES, race), "kobold-not-little")
    T.false_(util.contains(BRC.LARGE_RACES,  race), "kobold-not-large")
    T.false_(util.contains(BRC.UNDEAD_RACES, race), "kobold-not-undead")

    T.pass("dynamic-options-race-kobold")
    T.done()
  end)
end
