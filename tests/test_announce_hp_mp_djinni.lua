-- @species Dj
-- @background Be
-- @weapon handaxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (Djinni mmp=0 regression guard)
-- Djinni has MUT_HP_CASTING: get_real_mp() returns 0. Both you.mp() values are 0.
-- f_announce_hp_mp must not crash on the first turn when mmp=0.
--
-- Phase flow:
--   "check" (turn 0): assert you.mp() == (0, 0), verify race tables, CMD_WAIT → turn 1
--   "done"  (turn 1): T.pass — no crash occurred during turn 1's announce_hp_mp call
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_djinni = {}
test_announce_hp_mp_djinni.BRC_FEATURE_NAME = "test-announce-hp-mp-djinni"

local _phase = "check"

function test_announce_hp_mp_djinni.ready()
  if T._done then return end

  T.run("announce-hp-mp-djinni", function()

    if _phase == "check" then
      T.eq(you.race(), "Djinni", "char-is-djinni")

      local mp, mmp = you.mp()
      T.eq(mp,  0, "djinni-mp-zero")
      T.eq(mmp, 0, "djinni-mmp-zero")

      local race = you.race()
      T.true_(util.contains(BRC.NONLIVING_RACES, race), "djinni-nonliving")
      T.true_(util.contains(BRC.POIS_RES_RACES, race), "djinni-pois-res")
      T.false_(util.contains(BRC.UNDEAD_RACES, race), "djinni-not-undead")

      _phase = "done"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "done" then
      -- Reaching here means announce_hp_mp did not crash with mmp=0
      T.pass("announce-hp-mp-djinni")
      T.done()
    end
  end)
end
