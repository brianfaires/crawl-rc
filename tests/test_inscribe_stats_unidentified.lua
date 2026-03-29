---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (unidentified weapon)
-- Verifies the behavior of do_stat_inscription when called on an unidentified weapon.
--
-- BRC.eq.wpn_stats() only checks it.is_weapon — there is no identification guard.
-- Weapon properties (it.accuracy, it.plus, it.delay, it.damage) are available regardless of
-- identification state, so an inscription WILL be written even for unidentified items.
-- This test documents and verifies that current behavior.
--
-- Phase flow:
--   "give"   : wizard_give("mace plus:3") WITHOUT wizard_identify_all -> CMD_WAIT
--   "verify" : find mace on floor, call do_stat_inscription, verify inscription is written
---------------------------------------------------------------------------------------------------

test_inscribe_stats_unidentified = {}
test_inscribe_stats_unidentified.BRC_FEATURE_NAME = "test-inscribe-stats-unidentified"

local _phase = "give"

function test_inscribe_stats_unidentified.ready()
  if T._done then return end

  T.run("inscribe-stats-unidentified", function()

    if _phase == "give" then
      -- Give a mace WITHOUT calling wizard_identify_all
      T.wizard_give("mace plus:3")
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Find any weapon on the floor (the unidentified mace)
      local weap = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon then
          weap = it
          break
        end
      end

      T.true_(weap ~= nil, "mace-on-floor")
      if not weap then T.done() return end

      crawl.stderr("[INFO] unidentified weapon name=" .. tostring(weap.name()))
      crawl.stderr("[INFO] unidentified weapon identified=" .. tostring(weap.identified))

      -- Apply stat inscription — no identification check exists in do_stat_inscription
      f_inscribe_stats.do_stat_inscription(weap)

      local insc = weap.inscription or ""
      crawl.stderr("[INFO] unidentified weapon inscription: " .. insc)

      -- The function should still produce a stat inscription (no id guard)
      T.true_(#insc > 0, "inscription-written-for-unidentified-weapon")

      -- Must contain DPS= or Dmg=
      local has_stat = insc:find("DPS=") or insc:find("Dmg=")
      T.true_(has_stat ~= nil and has_stat ~= false, "inscription-has-dps-or-dmg")

      T.pass("inscribe-stats-unidentified")
      T.done()
    end
  end)
end
