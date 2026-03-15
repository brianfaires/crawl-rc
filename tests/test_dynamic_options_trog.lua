---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Trog god options)
-- Verifies that god-specific options are applied after the first ready() cycle.
--
-- Mummy Berserker starts worshipping Trog. f_dynamic_options.init() sets cur_god="No God",
-- so the first set_god_options() in ready() detects the change and calls Trog's handler.
-- Trog's handler removes "antimagic" from RISKY_EGOS and "-Cast" from ARTPROPS_BAD.
-- set_skill_options() also removes these (Berserker has 0 spellcasting/spells).
--
-- Our hook (test-dynamic-options-trog) fires BEFORE dynamic-options.ready() in reverse-alpha
-- order, so we must wait one full turn before the options are observable.
--
-- Phase flow:
--   "wait"  (turn 0): CMD_WAIT — dynamic-options.ready() fires AFTER our hook
--   "check" (turn 1): verify Trog god active, antimagic/cast options removed
---------------------------------------------------------------------------------------------------

test_dynamic_options_trog = {}
test_dynamic_options_trog.BRC_FEATURE_NAME = "test-dynamic-options-trog"

local _phase = "wait"

function test_dynamic_options_trog.ready()
  if T._done then return end

  T.run("dynamic-options-trog", function()
    if _phase == "wait" then
      -- Our hook fires before dynamic-options.ready() at turn 0.
      -- After CMD_WAIT, turn 0's cycle completes and Trog options are applied.
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Mummy Berserker starts worshipping Trog
      T.eq(you.god(), "Trog", "char-worships-trog")

      -- Trog joined: removes "antimagic" from RISKY_EGOS (Trog users wield antimagic freely)
      T.false_(util.contains(BRC.RISKY_EGOS, "antimagic"), "antimagic-not-risky-for-trog")

      -- Trog joined + no spellcasting: removes "-Cast" from ARTPROPS_BAD
      T.false_(util.contains(BRC.ARTPROPS_BAD, "-Cast"), "cast-not-bad-for-trog")

      T.pass("dynamic-options-trog")
      T.done()
    end
  end)
end
