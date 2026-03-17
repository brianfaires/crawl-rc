---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (MP loss scenario)
-- Verifies the MP LOSS path: when MP decreased by 2 since last turn, the MP meter fires.
-- With always_both=true, the HP meter also fires even though HP is unchanged.
--
-- Phase flow (one ready() call per phase):
--   "setup"  (turn 0): Set ad_prev.mp = mp + 2 to fake a 2-MP loss since last turn.
--                      ad_prev.hp = hp (no HP change) so hp_delta = 0.
--                      f_announce_hp_mp.ready() runs AFTER this (reverse-alpha hook order)
--                      in the same cycle. It sees:
--                        is_startup = false (ad_prev.hp != 0)
--                        mp_delta   = mp - (mp+2) = -2  → -2 <= -mp_loss_limit(-1) → do_mp=true
--                        hp_delta   = hp - hp = 0        → do_hp suppressed, but always_both=true
--                      always_both=true forces both HP and MP meters to fire.
--                      consume_queue fires after turn 0's cycle ends, populating T.last_messages.
--                      Then CMD_WAIT advances to turn 1.
--   "verify" (turn 1): Assert T.last_messages contains "MP[" (MP meter) and "HP[" (HP meter).
--
-- Hook call order (reverse alpha): test-announce-hp-mp-mp-loss sorts after f_announce_hp_mp,
-- so our ad_prev manipulation is visible when f_announce_hp_mp.ready() fires in the same cycle.
--
-- Config sanity: mp_loss_limit = 1 (from f_announce_hp_mp.Config.Announce), so a delta of -2
-- satisfies -2 <= -1, triggering the MP loss announcement.
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_mp_loss = {}
test_announce_hp_mp_mp_loss.BRC_FEATURE_NAME = "test-announce-hp-mp-mp-loss"

local _phase = "setup"

function test_announce_hp_mp_mp_loss.ready()
  if T._done then return end

  T.run("announce-hp-mp-mp-loss", function()
    if _phase == "setup" then
      -- Sanity-check the config value this test depends on.
      local mp_loss_limit = f_announce_hp_mp.Config.Announce.mp_loss_limit
      T.true_(mp_loss_limit > 0, "mp-loss-limit-positive")

      -- Fake a 2-MP loss: pretend MP was 2 HIGHER before this turn.
      -- mp_delta = you.mp() - (you.mp() + 2) = -2
      -- mp_loss_limit = 1, so -2 <= -1 → triggers MP loss message.
      -- ad_prev.hp = hp (no change) so hp_delta = 0; suppressed alone, but
      -- always_both=true forces the HP meter to appear alongside the MP meter.
      local hp, mhp = you.hp()
      local mp, mmp = you.mp()
      ad_prev.hp  = hp       -- hp_delta = 0
      ad_prev.mhp = mhp
      ad_prev.mp  = mp + 2   -- mp_delta = -2 → MP loss triggers
      ad_prev.mmp = mmp
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1; consume_queue fires after this returns

    elseif _phase == "verify" then
      -- T.last_messages was populated by turn 0's consume_queue.
      -- get_mp_message() produces " MP[..." and get_hp_message() produces " HP[...".
      T.true_(T.messages_contain("MP%["), "mp-loss-meter-fired")
      T.true_(T.messages_contain("HP%["), "always-both-shows-hp")
      T.pass("announce-hp-mp-mp-loss")
      T.done()
    end
  end)
end
