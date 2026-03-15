---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (robe — body armour with AC and EV)
-- Verifies that body armour inscriptions include BOTH AC and EV components.
--
-- BRC.eq.arm_stats(robe) for an unequipped body armour returns (ac_str, ev_str).
-- inscribe_armour_stats appends ", ev_str" when ev is non-nil and non-empty.
-- For a robe (encumbrance=0), EV delta is +0.0 — no penalty.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("robe") + identify → robe on floor → CMD_WAIT
--   "verify" (turn 1): find robe in floor_items(), call do_stat_inscription, check AC and EV
---------------------------------------------------------------------------------------------------

test_inscribe_stats_robe_ev = {}
test_inscribe_stats_robe_ev.BRC_FEATURE_NAME = "test-inscribe-stats-robe-ev"

local _phase = "give"

function test_inscribe_stats_robe_ev.ready()
  if T._done then return end

  T.run("inscribe-stats-robe-ev", function()
    if _phase == "give" then
      T.wizard_give("robe")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      local robe = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) then
          robe = it
          break
        end
      end

      T.true_(robe ~= nil, "robe-on-floor")
      if robe then
        f_inscribe_stats.do_stat_inscription(robe)
        -- Body armour (robe) should have both AC and EV in inscription
        T.true_(robe.inscription:contains("AC"), "robe-has-ac-inscription")
        T.true_(robe.inscription:contains("EV"), "robe-has-ev-inscription")
        -- Robe has 0 encumbrance → EV delta is 0 (no penalty/bonus)
        T.true_(robe.inscription:contains("EV+0"), "robe-ev-is-zero-delta")
      end
      T.pass("inscribe-stats-robe-ev")
      T.done()
    end
  end)
end
