---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (race constants)
-- Verifies that Mummy is correctly classified in BRC race constant tables.
-- These tables control which force_more messages are set in f_dynamic_options.init().
--
-- Mummy is:
--   - in BRC.UNDEAD_RACES   → triggers force_more for "holy wrath" weapons
--   - in BRC.POIS_RES_RACES → skips force_more for "curare" (no curare risk)
--   - NOT in BRC.NONLIVING_RACES (Djinni, Gargoyle only)
--
-- Also verifies BRC.eq.is_useless_ego() for Mummy-specific ego uselessness:
--   - "holy" ego: useless for undead (Mummy)
--   - "rPois" ego: useless for poison-resistant races (Mummy)
---------------------------------------------------------------------------------------------------

test_dynamic_options_race = {}
test_dynamic_options_race.BRC_FEATURE_NAME = "test-dynamic-options-race"

function test_dynamic_options_race.ready()
  if T._done then return end

  T.run("dynamic-options-race", function()
    local race = you.race()
    T.eq(race, "Mummy", "char-is-mummy")

    -- Race table membership
    T.true_(util.contains(BRC.UNDEAD_RACES, race), "mummy-is-undead")
    T.true_(util.contains(BRC.POIS_RES_RACES, race), "mummy-has-pois-res")
    T.false_(util.contains(BRC.NONLIVING_RACES, race), "mummy-not-nonliving")

    -- Ego uselessness: holy weapons are useless for undead races
    T.true_(BRC.eq.is_useless_ego("holy"), "holy-ego-useless-for-mummy")
    -- Ego uselessness: rPois ego useless for poison-resistant races
    T.true_(BRC.eq.is_useless_ego("rPois"), "rpois-ego-useless-for-mummy")

    T.pass("dynamic-options-race")
    T.done()
  end)
end
