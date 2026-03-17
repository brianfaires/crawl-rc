---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (DAMAGE alert fires with fixed formula)
-- Verifies that the FIXED damage formula actually triggers "BIG DAMAGE" / "MASSIVE DAMAGE"
-- when the player takes significant HP loss.
--
-- THE FIX (lua/features/announce-hp-mp.lua line 194):
--   local expected_hp = ad_prev.mhp > 0 and mhp * (ad_prev.hp / ad_prev.mhp) or hp
--   local damage_taken = expected_hp - hp
--
-- With the fixed formula, setting ad_prev.hp above current HP produces a positive
-- damage_taken that crosses the dmg_flash_threshold, causing the damage alert to fire.
--
-- Phase flow:
--   "setup"  (turn 0): Set ad_prev.hp = mhp + ceil(mhp * 0.25) to simulate the player
--                      having been at 125% of max HP on the previous turn (hypothetical,
--                      but valid for testing the formula).  Also raise dmg_fm_threshold to
--                      1.0 to prevent force_more from hanging headless mode.
--                      f_announce_hp_mp.ready() runs AFTER ours (reverse-alpha hook order)
--                      and computes:
--                        expected_hp  = mhp * ((mhp + N) / mhp) = mhp + N
--                        damage_taken = (mhp + N) - hp
--                                     >= N (since hp <= mhp)
--                                     >= ceil(mhp * 0.25)  > mhp * 0.20 (flash threshold)
--                      => BIG DAMAGE message queued, flushed via consume_queue after CMD_WAIT.
--   "verify" (turn 1): Assert T.last_messages contains "BIG DAMAGE" or "MASSIVE DAMAGE".
--                      Also assert the synthetic damage_taken is positive and above threshold.
--                      Restore dmg_fm_threshold.
--
-- Hook call order (reverse-alpha): "test-announce-hp-mp-damage-alert" sorts AFTER
-- "announce-hp-mp", so our ready() runs BEFORE f_announce_hp_mp.ready() in the same cycle.
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_damage_alert = {}
test_announce_hp_mp_damage_alert.BRC_FEATURE_NAME = "test-announce-hp-mp-damage-alert"

local _phase = "setup"
local _saved_fm_threshold = nil
local _syn_damage_taken    = 0
local _syn_mhp             = 0

function test_announce_hp_mp_damage_alert.ready()
  if T._done then return end

  T.run("announce-hp-mp-damage-alert", function()

    if _phase == "setup" then
      local hp, mhp = you.hp()
      local mp, mmp = you.mp()

      -- Save and disable force_more threshold so headless mode never hangs.
      _saved_fm_threshold = f_announce_hp_mp.Config.dmg_fm_threshold
      f_announce_hp_mp.Config.dmg_fm_threshold = 1.0  -- unreachable: prevents MASSIVE DAMAGE path

      -- Compute synthetic damage: 25% of max HP (crosses 20% flash threshold, not 100% fm).
      local damage_amount = math.ceil(mhp * 0.25)

      -- Set ad_prev to represent "player was at mhp + damage_amount last turn".
      -- With the FIXED formula:
      --   expected_hp  = mhp * ((mhp + N) / mhp) = mhp + N
      --   damage_taken = (mhp + N) - hp  >= N  (since hp <= mhp)
      --   N = damage_amount >= mhp * 0.25 > mhp * 0.20  => BIG DAMAGE fires
      ad_prev.hp  = mhp + damage_amount
      ad_prev.mhp = mhp
      ad_prev.mp  = mp
      ad_prev.mmp = mmp

      -- Record expected synthetic values for assertions in verify phase.
      _syn_mhp          = mhp
      _syn_damage_taken = (mhp * (ad_prev.hp / ad_prev.mhp)) - hp  -- = mhp + N - hp

      crawl.stderr("[INFO] mhp=" .. tostring(mhp) .. " hp=" .. tostring(hp))
      crawl.stderr("[INFO] ad_prev.hp set to " .. tostring(ad_prev.hp))
      crawl.stderr("[INFO] expected damage_taken (synthetic) = " .. tostring(_syn_damage_taken))

      -- Clear message buffer so we see only messages from this turn.
      T.last_messages = {}

      _phase = "verify"
      -- CMD_WAIT advances to turn 1; f_announce_hp_mp.ready() fires in this cycle AFTER us,
      -- then consume_queue flushes queued messages into T.last_messages before we return.
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Restore dmg_fm_threshold.
      if _saved_fm_threshold ~= nil then
        f_announce_hp_mp.Config.dmg_fm_threshold = _saved_fm_threshold
      end

      -- Dump captured messages for diagnosis.
      crawl.stderr("[INFO] captured " .. tostring(#T.last_messages) .. " messages")
      for i, msg in ipairs(T.last_messages) do
        crawl.stderr("[INFO] msg[" .. tostring(i) .. "] = " .. tostring(msg.text))
      end

      -- ── 1. Synthetic damage_taken is positive ──────────────────────────────
      T.true_(_syn_damage_taken > 0, "synthetic-damage-taken-positive")

      -- ── 2. Synthetic damage_taken exceeds dmg_flash_threshold ─────────────
      local threshold = f_announce_hp_mp.Config.dmg_flash_threshold
      crawl.stderr("[INFO] dmg_flash_threshold = " .. tostring(threshold))
      crawl.stderr("[INFO] threshold value = " .. tostring(_syn_mhp * threshold))
      T.true_(_syn_damage_taken >= _syn_mhp * threshold, "synthetic-damage-exceeds-threshold")

      -- ── 3. Damage alert message fired ─────────────────────────────────────
      -- f_announce_hp_mp.ready() queues either "BIG DAMAGE" or "MASSIVE DAMAGE".
      local big_fired     = T.messages_contain("BIG DAMAGE")
      local massive_fired = T.messages_contain("MASSIVE DAMAGE")
      crawl.stderr("[INFO] BIG DAMAGE fired = "     .. tostring(big_fired))
      crawl.stderr("[INFO] MASSIVE DAMAGE fired = " .. tostring(massive_fired))
      T.true_(big_fired or massive_fired, "damage-alert-fired")

      T.pass("announce-hp-mp-damage-alert")
      T.done()
    end
  end)
end
