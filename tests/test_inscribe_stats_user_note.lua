---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (user annotation preservation)
-- Verifies that update_inscription() preserves a user-added suffix when updating weapon stats.
--
-- update_inscription(orig, cur) finds the existing stats in orig by matching the first 4 chars
-- of cur ("DPS="). It preserves any content before (prefix) and after (suffix) the stats block.
-- When user content appears after the stats ("DPS=...; userkeep"), the suffix "userkeep" must
-- survive subsequent stat updates as the weapon stats change.
---------------------------------------------------------------------------------------------------

test_inscribe_stats_user_note = {}
test_inscribe_stats_user_note.BRC_FEATURE_NAME = "test-inscribe-stats-user-note"

function test_inscribe_stats_user_note.ready()
  if T._done then return end

  T.run("inscribe-stats-user-note", function()
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then weapon = it; break end
    end

    T.true_(weapon ~= nil, "has-weapon")
    if not weapon then T.done() return end

    -- First inscription pass: establishes "DPS=... A+N" in the inscription
    f_inscribe_stats.do_stat_inscription(weapon)
    T.true_(weapon.inscription:contains("DPS="), "first-pass-has-dps")

    -- Simulate user adding a note after the stats
    -- update_inscription should detect the suffix and preserve it
    weapon.inscribe(weapon.inscription .. "; userkeep", false)
    T.true_(weapon.inscription:contains("userkeep"), "user-note-added")

    -- Second inscription pass: update stats (same values — idempotent from 2nd call on)
    f_inscribe_stats.do_stat_inscription(weapon)

    -- Stats should still be present and user note must be preserved
    T.true_(weapon.inscription:contains("DPS="), "second-pass-still-has-dps")
    T.true_(weapon.inscription:contains("userkeep"), "user-note-preserved-after-update")

    T.pass("inscribe-stats-user-note")
    T.done()
  end)
end
