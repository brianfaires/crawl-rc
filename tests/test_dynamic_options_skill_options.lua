---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (set_skill_options)
-- Verifies that set_skill_options() correctly removes "antimagic" from BRC.RISKY_EGOS and
-- "-Cast" from BRC.ARTPROPS_BAD for a Mummy Berserker (0 Spellcasting, 0 spells known).
--
-- Logic in set_skill_options():
--   no_spells = spellcasting_skill == 0 or #you.spells() == 0
--   When no_spells=true:
--     add_or_remove(BRC.ARTPROPS_BAD, "-Cast",   not no_spells)  -> removes "-Cast"
--     add_or_remove(BRC.RISKY_EGOS,   "antimagic", not no_spells) -> removes "antimagic"
--
-- set_skill_options() fires in ready(), not init(). Our hook runs BEFORE
-- f_dynamic_options.ready() (reverse-alpha: test_ > f_dynamic), so we issue CMD_WAIT at
-- turn 0 to let ready() run, then check results at turn 1.
--
-- Phase flow:
--   "wait"  (turn 0): CMD_WAIT so f_dynamic_options.ready() runs set_skill_options()
--   "check" (turn 1): assert Spellcasting==0, spells==0, antimagic removed, -Cast removed
---------------------------------------------------------------------------------------------------

test_dynamic_options_skill_options = {}
test_dynamic_options_skill_options.BRC_FEATURE_NAME = "test-dynamic-options-skill-options"

local _phase = "wait"

function test_dynamic_options_skill_options.ready()
  if T._done then return end

  T.run("dynamic-options-skill-options", function()
    if _phase == "wait" then
      -- Our hook fires before f_dynamic_options.ready() at turn 0 (reverse-alpha order).
      -- CMD_WAIT completes this cycle; f_dynamic_options.ready() runs set_skill_options()
      -- for the first time. We check results on turn 1.
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Confirm the character has zero Spellcasting skill
      T.true_(you.skill("Spellcasting") == 0, "mummy-zero-spellcasting")

      -- Confirm the character knows zero spells
      T.true_(#you.spells() == 0, "mummy-zero-spells")

      -- When no_spells=true, "antimagic" must NOT be in BRC.RISKY_EGOS
      -- (set_skill_options removes it so antimagic weapons/armour are not flagged as risky)
      T.false_(
        util.contains(BRC.RISKY_EGOS, "antimagic"),
        "antimagic-not-risky-for-no-spells"
      )

      -- When no_spells=true, "-Cast" must NOT be in BRC.ARTPROPS_BAD
      -- (-Cast artefact property is not bad when you can't cast anyway)
      T.false_(
        util.contains(BRC.ARTPROPS_BAD, "-Cast"),
        "cast-not-bad-for-no-spells"
      )

      T.pass("dynamic-options-skill-options")
      T.done()
    end
  end)
end
