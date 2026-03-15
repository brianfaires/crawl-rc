---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp
-- Verifies that f_announce_hp_mp fires an HP meter message when HP decreases.
--
-- Phase flow (one ready() call per phase):
--   "setup"  (turn 0): Inflate ad_prev.hp by 5 to fake a 5-HP loss since last turn.
--                      f_announce_hp_mp.ready() runs AFTER this (reverse-alpha hook order)
--                      in the same cycle. It sees is_startup=false (ad_prev.hp != 0) and
--                      hp_delta = -5, triggering the HP meter message. consume_queue fires
--                      after turn 0's cycle ends, populating T.last_messages.
--                      Then CMD_WAIT advances to turn 1.
--   "verify" (turn 1): Assert T.last_messages contains the HP meter pattern "HP[".
--
-- Hook call order (reverse alpha): test-announce-hp-mp runs before announce-hp-mp, so
-- our ad_prev manipulation is visible when f_announce_hp_mp.ready() fires in the same cycle.
---------------------------------------------------------------------------------------------------

test_announce_hp_mp = {}
test_announce_hp_mp.BRC_FEATURE_NAME = "test-announce-hp-mp"

local _phase = "setup"

function test_announce_hp_mp.ready()
  if T._done then return end

  T.run("announce-hp-mp", function()
    if _phase == "setup" then
      -- Fake a 5-HP loss by inflating ad_prev.hp above the current HP.
      -- f_announce_hp_mp.ready() (runs after ours this cycle) will see:
      --   is_startup = false (ad_prev.hp != 0)
      --   hp_delta   = you.hp() - (you.hp() + 5) = -5  → triggers HP meter message
      local hp, mhp = you.hp()
      local mp, mmp = you.mp()
      ad_prev.hp  = hp + 5
      ad_prev.mhp = mhp
      ad_prev.mp  = mp
      ad_prev.mmp = mmp
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1; consume_queue fires after this returns

    elseif _phase == "verify" then
      -- T.last_messages was populated by turn 0's consume_queue.
      -- The HP meter message format includes " HP[" (from get_hp_message).
      T.true_(T.messages_contain("HP%["), "hp-meter-fired")
      T.pass("announce-hp-mp")
      T.done()
    end
  end)
end
