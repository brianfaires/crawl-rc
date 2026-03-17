---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (MP-only change scenario)
-- Verifies that when only MP changes (hp_delta=0, mp_delta>0 >= mp_gain_limit), the MP meter
-- fires. With always_both=true, both HP and MP meters should appear.
--
-- Logic under test (announce-hp-mp.lua ready()):
--   1. hp_delta == 0, mp_delta == 3 -> does NOT hit the early-return guard
--      (which requires BOTH to be 0)
--   2. mp_delta >= mp_gain_limit (3 >= 2) -> do_mp stays true
--   3. hp_delta == 0, so normally do_hp = false (both gain checks fail for 0)
--   4. C.Announce.always_both = true -> forces do_hp = true, do_mp = true
--   => Both HP[ and MP[ appear in the message.
--
-- Phase flow:
--   "setup"  (turn 0): Hook order (reverse-alpha by Lua var name): test_announce_hp_mp_mp_only
--                      sorts after f_announce_hp_mp, so our ready() fires BEFORE
--                      f_announce_hp_mp.ready() in the same turn-0 cycle.
--                      We set ad_prev so that f_announce_hp_mp sees hp_delta=0, mp_delta=+3.
--                      f_announce_hp_mp queues HP+MP meter. consume_queue delivers them to
--                      T.last_messages before BRC.ready() returns. CMD_WAIT advances the turn.
--   "verify" (turn 1): T.last_messages has the turn-0 meter messages. Assert "MP[" and "HP[".
--                      (Same pattern as test_announce_hp_mp.lua and test_announce_hp_mp_gain.lua.)
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_mp_only = {}
test_announce_hp_mp_mp_only.BRC_FEATURE_NAME = "test-announce-hp-mp-mp-only"

local _phase = "setup"

function test_announce_hp_mp_mp_only.ready()
  if T._done then return end

  T.run("announce-hp-mp-mp-only", function()

    if _phase == "setup" then
      -- ── Static config assertions (run once, no game state needed) ──────────
      T.true_(f_announce_hp_mp.Config.Announce.mp_gain_limit > 0, "mp-gain-limit-positive")
      T.true_(f_announce_hp_mp.Config.Announce.mp_loss_limit > 0, "mp-loss-limit-positive")
      T.true_(f_announce_hp_mp.Config.Announce.always_both == true, "always-both-true")

      -- ── you.mp() is accessible ─────────────────────────────────────────────
      local mp, mmp = you.mp()
      T.true_(mmp > 0, "you-mp-accessible")

      -- ── Synthetic MP-only delta setup ──────────────────────────────────────
      -- Set ad_prev so that when f_announce_hp_mp.ready() fires (after ours this cycle):
      --   is_startup = false  (ad_prev.hp != 0)
      --   hp_delta   = 0      (ad_prev.hp == current hp -> no HP change)
      --   mp_delta   = +3     (mp_gain_limit is 2, so 3 >= 2 -> triggers MP meter)
      -- always_both = true forces do_hp = true even though hp_delta = 0.
      local hp, mhp = you.hp()
      ad_prev.hp  = hp
      ad_prev.mhp = mhp
      ad_prev.mmp = mmp
      ad_prev.mp  = mp - 3  -- mp_delta = mp - (mp-3) = +3 >= mp_gain_limit (2)

      -- Do NOT clear T.last_messages here. Messages from f_announce_hp_mp on turn 0
      -- are delivered by consume_queue at the end of this BRC.ready() cycle and
      -- are in T.last_messages when verify fires on turn 1. No startup messages
      -- contain "MP[" or "HP[" from the meter format, so there is no false-positive risk.
      -- (Clearing T.last_messages before CMD_WAIT creates a timing hazard; see the
      -- test_announce_hp_mp_damage_alert.lua pattern for when clearing is needed.)

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    elseif _phase == "verify" then
      -- Dump captured messages for diagnosis if assertions fail.
      crawl.stderr("[INFO] captured " .. tostring(#T.last_messages) .. " messages in T.last_messages")
      for i, msg in ipairs(T.last_messages) do
        crawl.stderr("[INFO] msg[" .. tostring(i) .. "] = " .. tostring(msg.text))
      end

      -- MP meter must have fired (mp_delta == +3 >= mp_gain_limit == 2)
      T.true_(T.messages_contain("MP%["), "mp-only-meter-fired")
      -- always_both = true: HP meter must appear alongside MP meter
      T.true_(T.messages_contain("HP%["), "always-both-hp-also-fired")

      T.pass("announce-hp-mp-mp-only")
      T.done()
    end

  end)
end
