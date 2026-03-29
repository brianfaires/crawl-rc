---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (shield)
-- Verifies that inscribe_armour_stats uses "SH" (not "AC") for shields.
--
-- BRC.it.is_shield(it) calls it.is_shield() — a buckler is a shield in DCSS.
-- inscribe_armour_stats branches on is_shield: shields use abbr="SH", armour uses abbr="AC".
-- BRC.eq.arm_stats(buckler) returns ("SH+X.X", "EV-Y.Y").
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("buckler") + identify → buckler on floor → CMD_WAIT
--   "verify" (turn 1): find buckler in floor_items(), call do_stat_inscription, check "SH"
---------------------------------------------------------------------------------------------------

test_inscribe_stats_shield = {}
test_inscribe_stats_shield.BRC_FEATURE_NAME = "test-inscribe-stats-shield"

local _phase = "give"

function test_inscribe_stats_shield.ready()
  if T._done then return end

  T.run("inscribe-stats-shield", function()
    if _phase == "give" then
      T.wizard_give("buckler")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      local shield = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_shield(it) then
          shield = it
          break
        end
      end

      T.true_(shield ~= nil, "buckler-on-floor")
      if shield then
        f_inscribe_stats.do_stat_inscription(shield)
        -- Shields use "SH" abbreviation, not "AC"
        T.true_(shield.inscription:contains("SH"), "shield-has-sh-inscription")
        T.false_(shield.inscription:contains("AC"), "shield-has-no-ac-inscription")
      end
      T.pass("inscribe-stats-shield")
      T.done()
    end
  end)
end
