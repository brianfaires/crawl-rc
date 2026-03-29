---------------------------------------------------------------------------------------------------
-- BRC feature test: fully-recover (fr_bad_durations initialization and state)
-- Verifies that fr_bad_durations is initialized from BRC.BAD_DURATIONS and that
-- f_fully_recover module and Config are accessible.
--
-- fully_recovered() is module-local and cannot be called directly; we test it
-- observationally by checking HP/MP at turn 0 and verifying the persistent table is correct.
--
-- Assertions:
--   - f_fully_recover module exists and has a Config
--   - fr_bad_durations is a non-empty table
--   - fr_bad_durations has the same count as BRC.BAD_DURATIONS (copied on first load)
--   - A known entry from BRC.BAD_DURATIONS is present in fr_bad_durations
--   - Mummy Berserker starts at full HP (a pre-condition for fully_recovered())
--
-- Single-phase, turn 0 — no CMD_WAIT needed.
---------------------------------------------------------------------------------------------------

test_fully_recover_state = {}
test_fully_recover_state.BRC_FEATURE_NAME = "test-fully-recover-state"

function test_fully_recover_state.ready()
  if T._done then return end

  T.run("fully-recover-state", function()

    -- Module and Config existence
    T.true_(f_fully_recover ~= nil, "module-exists")
    T.true_(f_fully_recover.Config ~= nil, "has-config")

    -- fr_bad_durations is a persistent table initialized from BRC.BAD_DURATIONS
    T.true_(fr_bad_durations ~= nil, "fr-bad-durations-exists")
    T.true_(type(fr_bad_durations) == "table", "fr-bad-durations-is-table")
    T.true_(#fr_bad_durations > 0, "fr-bad-durations-nonempty")

    -- Count matches BRC.BAD_DURATIONS (no entries removed yet at game start)
    T.eq(#fr_bad_durations, #BRC.BAD_DURATIONS, "fr-bad-durations-count-matches")

    -- Spot-check: "berserk" is the first entry in BRC.BAD_DURATIONS
    local found_berserk = false
    for _, s in ipairs(fr_bad_durations) do
      if s == "berserk" then found_berserk = true; break end
    end
    T.true_(found_berserk, "fr-bad-durations-contains-berserk")

    -- Spot-check: "slowed" is in the list too
    local found_slowed = false
    for _, s in ipairs(fr_bad_durations) do
      if s == "slowed" then found_slowed = true; break end
    end
    T.true_(found_slowed, "fr-bad-durations-contains-slowed")

    -- Mummy starts at full HP — precondition for fully_recovered() returning true
    local hp, mhp = you.hp()
    T.true_(hp == mhp, "mummy-starts-at-full-hp")

    T.pass("fully-recover-state")
    T.done()
  end)
end
