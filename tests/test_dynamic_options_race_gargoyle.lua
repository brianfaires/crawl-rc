-- @species Gr
-- @background Be
-- @weapon mace
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Gargoyle race table classification)
-- Gargoyle is NONLIVING (not UNDEAD) and in POIS_RES_RACES.
-- Exercises the nonliving miasma path and the rPois useless-ego path,
-- without triggering the undead holy-wrath path.
--
-- Key distinctions vs Mummy (which is UNDEAD + POIS_RES):
--   - Gargoyle: NONLIVING=true, UNDEAD=false → holy wrath force_more NOT set
--   - Gargoyle: rPois useless, but holy NOT useless
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_gargoyle = {}
test_dynamic_options_race_gargoyle.BRC_FEATURE_NAME = "test-dynamic-options-race-gargoyle"

function test_dynamic_options_race_gargoyle.ready()
  if T._done then return end

  T.run("dynamic-options-race-gargoyle", function()
    local race = you.race()
    T.eq(race, "Gargoyle", "char-is-gargoyle")

    T.true_(util.contains(BRC.NONLIVING_RACES, race), "gargoyle-nonliving")
    T.true_(util.contains(BRC.POIS_RES_RACES, race), "gargoyle-pois-res")
    T.false_(util.contains(BRC.UNDEAD_RACES, race), "gargoyle-not-undead")

    T.true_(BRC.you.miasma_immune(), "gargoyle-miasma-immune")
    T.false_(BRC.eq.is_useless_ego("holy"), "holy-not-useless-for-gargoyle")
    T.true_(BRC.eq.is_useless_ego("rPois"), "rpois-useless-for-gargoyle")

    T.pass("dynamic-options-race-gargoyle")
    T.done()
  end)
end
