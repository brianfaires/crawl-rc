---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (skip_dps format change)
-- Verifies that update_inscription() handles format migration when skip_dps changes.
--
-- Default: skip_dps=false → "DPS=X.X (X.X/X.X) A+N"
-- With skip_dps=true      → "Dmg=X.X/X.X A+N"
--
-- update_inscription(orig, cur) finds the old stats by matching orig:find(cur:sub(1,4)).
-- When format changes (DPS= → Dmg=), cur:sub(1,4) = "Dmg=" is NOT found in the old
-- "DPS=..." inscription, so update_inscription FALLS THROUGH to prepend instead of update.
-- This results in "Dmg=...; DPS=..." — duplicated stats in the inscription.
--
-- This test verifies the EXPECTED behavior: after the format change, re-inscribing should
-- produce a clean inscription with the NEW format only (no leftover DPS= prefix).
--
-- If this test FAILS it reveals a bug in update_inscription: the format migration path
-- is not handled, leaving stale DPS= content in the inscription.
---------------------------------------------------------------------------------------------------

test_inscribe_stats_skip_dps = {}
test_inscribe_stats_skip_dps.BRC_FEATURE_NAME = "test-inscribe-stats-skip-dps"

function test_inscribe_stats_skip_dps.ready()
  if T._done then return end

  T.run("inscribe-stats-skip-dps", function()
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then weapon = it; break end
    end

    T.true_(weapon ~= nil, "has-weapon")
    if not weapon then T.done() return end

    -- Step 1: Apply inscription with default skip_dps=false → "DPS=..."
    f_inscribe_stats.Config.skip_dps = false
    f_inscribe_stats.do_stat_inscription(weapon)
    T.true_(weapon.inscription:contains("DPS="), "dps-format-applied")

    -- Step 2: Switch to skip_dps=true → re-inscribe should produce "Dmg=..." only
    f_inscribe_stats.Config.skip_dps = true
    f_inscribe_stats.do_stat_inscription(weapon)

    -- After format change: inscription should use the new format
    T.true_(weapon.inscription:contains("Dmg="), "new-format-dmg-present")

    -- And must NOT still contain the old "DPS=" prefix — that would be a stale duplicate
    T.false_(weapon.inscription:contains("DPS="), "old-format-dps-gone")

    -- Restore config
    f_inscribe_stats.Config.skip_dps = false

    T.pass("inscribe-stats-skip-dps")
    T.done()
  end)
end
