-- @species Ds
-- @background Be
-- @weapon handaxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Demonspawn BRC.UNDEAD_RACES membership)
-- Demonspawn is in BRC.UNDEAD_RACES by intentional BRC design even though it is US_ALIVE
-- in DCSS. This makes holy ego useless for Demonspawn in BRC.
-- Demonspawn is NOT in NONLIVING_RACES or POIS_RES_RACES.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_demonspawn = {}
test_dynamic_options_race_demonspawn.BRC_FEATURE_NAME = "test-dynamic-options-race-demonspawn"

function test_dynamic_options_race_demonspawn.ready()
  if T._done then return end

  T.run("dynamic-options-race-demonspawn", function()
    local race = you.race()
    T.eq(race, "Demonspawn", "char-is-demonspawn")

    -- BRC-specific: Demonspawn is in BRC.UNDEAD_RACES even though US_ALIVE in DCSS
    T.true_(util.contains(BRC.UNDEAD_RACES, race), "demonspawn-in-brc-undead-races")
    T.true_(BRC.eq.is_useless_ego("holy"), "demonspawn-holy-useless")

    T.false_(util.contains(BRC.NONLIVING_RACES, race), "demonspawn-not-nonliving")
    T.false_(util.contains(BRC.POIS_RES_RACES,  race), "demonspawn-not-pois-res")
    T.false_(BRC.eq.is_useless_ego("rPois"), "rpois-not-useless-for-demonspawn")

    T.pass("dynamic-options-race-demonspawn")
    T.done()
  end)
end
