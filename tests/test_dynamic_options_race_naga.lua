-- @species Na
-- @background Be
-- @weapon falchion
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Naga race table classification)
-- Naga is LARGE (SIZE_PENALTY.LARGE) and in POIS_RES_RACES.
-- Not in UNDEAD_RACES or NONLIVING_RACES.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_naga = {}
test_dynamic_options_race_naga.BRC_FEATURE_NAME = "test-dynamic-options-race-naga"

function test_dynamic_options_race_naga.ready()
  if T._done then return end

  T.run("dynamic-options-race-naga", function()
    local race = you.race()
    T.eq(race, "Naga", "char-is-naga")

    T.true_(util.contains(BRC.POIS_RES_RACES, race), "naga-pois-res")
    T.true_(util.contains(BRC.LARGE_RACES, race), "naga-large")
    T.false_(util.contains(BRC.UNDEAD_RACES, race), "naga-not-undead")
    T.false_(util.contains(BRC.NONLIVING_RACES, race), "naga-not-nonliving")

    T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.LARGE, "naga-large-size-penalty")
    T.true_(BRC.eq.is_useless_ego("rPois"), "naga-rpois-useless")
    T.false_(BRC.eq.is_useless_ego("holy"), "holy-not-useless-for-naga")

    T.pass("dynamic-options-race-naga")
    T.done()
  end)
end
