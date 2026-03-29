-- @species Sp
-- @background Mo
-- @weapon unarmed
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Spriggan race table classification)
-- Spriggan is LITTLE (SIZE_PENALTY.LITTLE). Not in any other size table,
-- and not in POIS_RES_RACES, UNDEAD_RACES, or NONLIVING_RACES.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_spriggan = {}
test_dynamic_options_race_spriggan.BRC_FEATURE_NAME = "test-dynamic-options-race-spriggan"

function test_dynamic_options_race_spriggan.ready()
  if T._done then return end

  T.run("dynamic-options-race-spriggan", function()
    local race = you.race()
    T.eq(race, "Spriggan", "char-is-spriggan")

    T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.LITTLE, "spriggan-little-size-penalty")
    T.true_(util.contains(BRC.LITTLE_RACES,     race), "spriggan-in-little-races")

    T.false_(util.contains(BRC.POIS_RES_RACES,  race), "spriggan-not-pois-res")
    T.false_(util.contains(BRC.UNDEAD_RACES,    race), "spriggan-not-undead")
    T.false_(util.contains(BRC.NONLIVING_RACES, race), "spriggan-not-nonliving")
    T.false_(util.contains(BRC.SMALL_RACES,     race), "spriggan-not-small")
    T.false_(util.contains(BRC.LARGE_RACES,     race), "spriggan-not-large")

    T.pass("dynamic-options-race-spriggan")
    T.done()
  end)
end
