---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (non-body armour — helmet)
-- Verifies that non-body armour gets only an "AC" inscription with no "EV" component.
--
-- BRC.eq.arm_stats(it) for non-body-armour returns (ac_str, nil).
-- inscribe_armour_stats only appends EV when ev is non-nil and non-empty.
-- Therefore helmet/gloves/boots should show "AC+N.N" without any "EV" part.
--
-- Also verifies that BRC.it.is_body_armour returns false for a helmet.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("helmet") + identify → helmet on floor → CMD_WAIT
--   "verify" (turn 1): find helmet in floor_items(), call do_stat_inscription, check AC/no-EV
---------------------------------------------------------------------------------------------------

test_inscribe_stats_helmet = {}
test_inscribe_stats_helmet.BRC_FEATURE_NAME = "test-inscribe-stats-helmet"

local _phase = "give"

function test_inscribe_stats_helmet.ready()
  if T._done then return end

  T.run("inscribe-stats-helmet", function()
    if _phase == "give" then
      T.wizard_give("helmet")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      local helmet = nil
      for _, it in ipairs(you.floor_items()) do
        -- Helmet is armour but not a shield and not body armour
        if BRC.it.is_armour(it) and not BRC.it.is_shield(it) and not BRC.it.is_body_armour(it) then
          helmet = it
          break
        end
      end

      T.true_(helmet ~= nil, "helmet-on-floor")
      if helmet then
        f_inscribe_stats.do_stat_inscription(helmet)
        -- Non-body armour: should have AC but no EV
        T.true_(helmet.inscription:contains("AC"), "helmet-has-ac-inscription")
        T.false_(helmet.inscription:contains("EV"), "helmet-has-no-ev-inscription")
      end
      T.pass("inscribe-stats-helmet")
      T.done()
    end
  end)
end
