---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats
-- Verifies that f_inscribe_stats.do_stat_inscription adds a stat inscription to a weapon.
--
-- Uses the Mummy Berserker's starting mace (always in inventory at turn 0).
-- Calls do_stat_inscription directly rather than waiting for the ready() cycle to avoid
-- timing complexity.
---------------------------------------------------------------------------------------------------

test_inscribe_stats = {}
test_inscribe_stats.BRC_FEATURE_NAME = "test-inscribe-stats"

function test_inscribe_stats.ready()
  if T._done then return end

  T.run("inscribe-stats", function()
    -- Find first weapon in inventory (Mummy Berserker starts with a mace)
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then
        weapon = it
        break
      end
    end

    T.true_(weapon ~= nil, "has-weapon")
    if not weapon then T.done() return end

    -- Apply stat inscription directly
    f_inscribe_stats.do_stat_inscription(weapon)

    -- Inscription should now be non-empty (DPS/dmg/accuracy stats were added)
    T.true_(weapon.inscription ~= nil and #weapon.inscription > 0, "inscription-applied")
    T.pass("inscribe-stats")
    T.done()
  end)
end
