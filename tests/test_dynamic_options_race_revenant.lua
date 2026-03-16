-- @species Re
-- @background Gl
-- @weapon quarterstaff
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Revenant race table classification)
-- Revenant is in UNDEAD_RACES and POIS_RES_RACES. Not in NONLIVING_RACES.
-- Both holy and rPois egos are useless for Revenant.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_revenant = {}
test_dynamic_options_race_revenant.BRC_FEATURE_NAME = "test-dynamic-options-race-revenant"

function test_dynamic_options_race_revenant.ready()
  if T._done then return end

  T.run("dynamic-options-race-revenant", function()
    local race = you.race()
    T.eq(race, "Revenant", "char-is-revenant")

    T.true_(util.contains(BRC.UNDEAD_RACES,     race), "revenant-undead")
    T.true_(util.contains(BRC.POIS_RES_RACES,   race), "revenant-pois-res")
    T.false_(util.contains(BRC.NONLIVING_RACES, race), "revenant-not-nonliving")

    T.true_(BRC.eq.is_useless_ego("holy"),  "revenant-holy-useless")
    T.true_(BRC.eq.is_useless_ego("rPois"), "revenant-rpois-useless")

    T.pass("dynamic-options-race-revenant")
    T.done()
  end)
end
