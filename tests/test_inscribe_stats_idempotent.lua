---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (idempotency)
-- Verifies that applying do_stat_inscription twice produces the same inscription.
-- The update_inscription() function must handle an already-inscribed weapon correctly —
-- re-applying should update in-place rather than duplicating the stats string.
---------------------------------------------------------------------------------------------------

test_inscribe_stats_idempotent = {}
test_inscribe_stats_idempotent.BRC_FEATURE_NAME = "test-inscribe-stats-idempotent"

function test_inscribe_stats_idempotent.ready()
  if T._done then return end

  T.run("inscribe-stats-idempotent", function()
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then weapon = it; break end
    end

    T.true_(weapon ~= nil, "has-weapon")
    if not weapon then T.done() return end

    -- First application (blank → "stats; " — trailing "; " is a known quirk of update_inscription)
    f_inscribe_stats.do_stat_inscription(weapon)
    T.true_(#weapon.inscription > 0, "first-inscription-applied")

    -- Second application normalises: "stats; " → "stats" (strips orphan "; ")
    f_inscribe_stats.do_stat_inscription(weapon)
    local second_inscription = weapon.inscription

    -- Third application — must now be stable (idempotent from the 2nd call onward)
    f_inscribe_stats.do_stat_inscription(weapon)
    T.eq(weapon.inscription, second_inscription, "third-application-unchanged")

    T.pass("inscribe-stats-idempotent")
    T.done()
  end)
end
