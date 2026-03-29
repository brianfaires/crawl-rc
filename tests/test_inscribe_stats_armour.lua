---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (armour)
-- Verifies that inscribe_armour_stats produces an "AC" inscription for body armour.
--
-- Calls do_stat_inscription directly on a wizard-given robe (floor item at turn 1).
-- In DCSS Lua, it.inscribe() operates on the item object in-place regardless of location.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("robe") + identify → CMD_WAIT
--   "verify" (turn 1): find robe in floor_items(), call do_stat_inscription, check "AC"
---------------------------------------------------------------------------------------------------

test_inscribe_stats_armour = {}
test_inscribe_stats_armour.BRC_FEATURE_NAME = "test-inscribe-stats-armour"

local _phase = "give"

function test_inscribe_stats_armour.ready()
  if T._done then return end

  T.run("inscribe-stats-armour", function()
    if _phase == "give" then
      T.wizard_give("robe")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Find the robe among floor items
      local armour = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_armour(it) then
          armour = it
          break
        end
      end

      T.true_(armour ~= nil, "robe-on-floor")
      if armour then
        f_inscribe_stats.do_stat_inscription(armour)
        -- inscribe_armour_stats builds "AC+N" or "AC+N, EV+M"
        T.true_(armour.inscription:contains("AC"), "armour-has-ac-inscription")
      end
      T.pass("inscribe-stats-armour")
      T.done()
    end
  end)
end
