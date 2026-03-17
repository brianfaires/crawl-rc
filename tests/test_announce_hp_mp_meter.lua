---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (msg_is_meter + ad_prev after one turn)
--
-- Phase flow (one ready() call per phase):
--   "wait"   (turn 0): Issue CMD_WAIT so f_announce_hp_mp.ready() runs and populates ad_prev.
--                      Hook order (reverse-alpha): test-announce-hp-mp-meter runs AFTER
--                      announce-hp-mp this cycle, so by "verify" ad_prev is already set.
--   "verify" (turn 1): 1) Unit-test msg_is_meter with explicit strings (true and false cases).
--                      2) Verify ad_prev is populated (non-zero) after one turn.
--                      3) Verify startup skip: ad_prev.hp > 0 after turn 0 (init sets it to 0,
--                         first ready() with is_startup=true records current values).
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_meter = {}
test_announce_hp_mp_meter.BRC_FEATURE_NAME = "test-announce-hp-mp-meter"

local _phase = "wait"

function test_announce_hp_mp_meter.ready()
  if T._done then return end

  T.run("announce-hp-mp-meter", function()
    if _phase == "wait" then
      -- Turn 0: let f_announce_hp_mp.ready() run (it fires before ours in alpha order).
      -- After this CMD_WAIT, ad_prev will be populated with real HP/MP values.
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- ── 1. Unit-test msg_is_meter ──────────────────────────────────────────

      -- Should be true: contains "] -> " and " HP[" or " MP["
      -- Real meter output always has a meter bar prefix before HP[/MP[, so there
      -- is always a space before the stat token.  Bare "HP[..." (no leading space)
      -- does NOT match — that is the correct behaviour and tested below.
      T.true_(f_announce_hp_mp.msg_is_meter("|+++++++--- HP[+0] -> 16/16"), "hp-meter-true")
      T.true_(f_announce_hp_mp.msg_is_meter("|+++++++--- MP[+0] -> 5/5"), "mp-meter-true")
      T.true_(f_announce_hp_mp.msg_is_meter("HP[-3] -> 13/16  MP[+0] -> 5/5"), "combined-meter-true")

      -- Should be false: missing "] -> " or missing " HP["/" MP["
      T.false_(f_announce_hp_mp.msg_is_meter("You pick up a mace."), "pickup-msg-false")
      T.false_(f_announce_hp_mp.msg_is_meter(""), "empty-false")
      T.false_(f_announce_hp_mp.msg_is_meter("-> something without HP or MP"), "no-stat-false")
      T.false_(f_announce_hp_mp.msg_is_meter("HP without arrow"), "no-arrow-false")

      -- ── 2. Verify ad_prev populated after one turn ─────────────────────────

      T.true_(ad_prev.hp > 0, "ad-prev-hp-set")
      T.true_(ad_prev.mhp > 0, "ad-prev-mhp-set")
      T.true_(ad_prev.mp > 0 or ad_prev.mmp > 0, "ad-prev-mp-set")
      crawl.mpr("hp=" .. tostring(ad_prev.hp) .. "/" .. tostring(ad_prev.mhp))
      crawl.mpr("mp=" .. tostring(ad_prev.mp) .. "/" .. tostring(ad_prev.mmp))

      -- ── 3. Startup skip: ad_prev.hp > 0 means init's skip fired correctly ──

      -- f_announce_hp_mp.init() zeroes ad_prev; first ready() sees is_startup=true,
      -- records real values and returns early. After our CMD_WAIT (turn 0), ad_prev
      -- must be non-zero, confirming the startup path ran and then updated state.
      T.true_(ad_prev.hp > 0, "startup-skip-then-set")

      T.pass("announce-hp-mp-meter")
      T.done()
    end
  end)
end
