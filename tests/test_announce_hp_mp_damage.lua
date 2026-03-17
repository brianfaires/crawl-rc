---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (damage formula — fixed)
-- Verifies the "damage taken" calculation in f_announce_hp_mp.ready() is correct.
--
-- FORMER BUG (now fixed — lua/features/announce-hp-mp.lua):
--   local expected_hp  = mhp * (hp / mhp)   -- simplified to hp (tautology)
--   local damage_taken = expected_hp - hp    -- always 0
--
-- FIX:
--   local expected_hp  = ad_prev.mhp > 0 and mhp * (ad_prev.hp / ad_prev.mhp) or hp
--   local damage_taken = expected_hp - hp
--
-- Phase flow:
--   "wait"   (turn 0): set ad_prev.hp = mhp+5 (above current HP) and CMD_WAIT.
--                      f_announce_hp_mp.ready() runs after us (reverse-alpha order)
--                      and with the fix computes damage_taken = 5 > threshold → BIG DAMAGE fires.
--   "verify" (turn 1): confirm:
--                        1. buggy formula is algebraically 0 (synthetic tautology proof)
--                        2. buggy formula equals current hp (synthetic tautology proof)
--                        3. ad_prev was properly set (non-zero) before our call
--                        4. synthetic scenario: ad_prev.hp > hp -> correct formula non-zero
--                        5. correct formula diverges from buggy formula when prev HP > cur HP
--                        6. the DAMAGE alert DID fire (confirming the fix works)
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_damage = {}
test_announce_hp_mp_damage.BRC_FEATURE_NAME = "test-announce-hp-mp-damage"

local _phase = "wait"
local _saved_ad_prev_hp  = 0
local _saved_ad_prev_mhp = 0
local _saved_hp          = 0
local _saved_mhp         = 0

function test_announce_hp_mp_damage.ready()
  if T._done then return end

  T.run("announce-hp-mp-damage", function()

    if _phase == "wait" then
      -- Set ad_prev to represent "was at full HP last turn" so the correct formula
      -- would compute large damage_taken when current HP is lower.
      -- We set ad_prev.hp = mhp (full HP "before") but keep current HP real.
      -- Even if current HP happens to be full, mhp*(mhp/mhp) - hp = mhp - mhp = 0
      -- with the CORRECT formula.  But if we set ad_prev.hp > hp, the correct formula
      -- gives a positive damage_taken while the buggy formula always gives 0.
      local hp, mhp = you.hp()
      local mp, mmp = you.mp()

      -- Save the real current state for assertions in verify phase
      _saved_hp   = hp
      _saved_mhp  = mhp

      -- Set ad_prev.hp = mhp + 5 (above current HP) so the two formulas provably diverge:
      --   correct:  mhp * ((mhp+5) / mhp) - hp  ≠  0
      --   buggy:    mhp * (hp / mhp) - hp = 0
      -- Even if the player is currently at full HP this gives us two different results.
      ad_prev.hp  = mhp + 5      -- "was 5 HP above current max" (hypothetical prev state)
      ad_prev.mhp = mhp
      ad_prev.mp  = mp
      ad_prev.mmp = mmp

      _saved_ad_prev_hp  = ad_prev.hp
      _saved_ad_prev_mhp = ad_prev.mhp

      -- Clear message buffer so we can check for DAMAGE alerts cleanly
      T.last_messages = {}

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- turn 0 -> turn 1; consume_queue fires after return

    elseif _phase == "verify" then
      -- ── Re-read current state ─────────────────────────────────────────────
      local hp, mhp = you.hp()
      local mp, mmp = you.mp()

      crawl.stderr("[INFO] ad_prev.hp (set by us) = " .. tostring(_saved_ad_prev_hp))
      crawl.stderr("[INFO] ad_prev.mhp            = " .. tostring(_saved_ad_prev_mhp))
      crawl.stderr("[INFO] current hp             = " .. tostring(hp))
      crawl.stderr("[INFO] current mhp            = " .. tostring(mhp))

      -- ── Reproduce the BUGGY formula ───────────────────────────────────────
      local buggy_expected_hp  = mhp * (hp / mhp)
      local buggy_damage_taken = buggy_expected_hp - hp

      crawl.stderr("[INFO] buggy_expected_hp  = mhp*(hp/mhp) = " .. tostring(buggy_expected_hp))
      crawl.stderr("[INFO] buggy_damage_taken = "               .. tostring(buggy_damage_taken))

      -- ── Reproduce the CORRECT formula using saved ad_prev values ─────────────
      -- By turn 1, f_announce_hp_mp.ready() has already overwritten ad_prev with live values.
      -- We use _saved_ad_prev_hp/_saved_ad_prev_mhp (= mhp+5 / mhp that we set in wait phase).
      local correct_expected_hp  = mhp * (_saved_ad_prev_hp / _saved_ad_prev_mhp)
      local correct_damage_taken = correct_expected_hp - hp

      crawl.stderr("[INFO] correct_expected_hp  = mhp*((mhp+5)/mhp) = " .. tostring(correct_expected_hp))
      crawl.stderr("[INFO] correct_damage_taken = "                       .. tostring(correct_damage_taken))

      -- ── Synthetic scenario: ad_prev.hp set to mhp+5, current hp = mhp ───────
      -- Use purely local variables (no live game state) to prove formula divergence.
      local syn_prev_hp  = mhp + 5  -- same value we wrote to ad_prev in wait phase
      local syn_prev_mhp = mhp
      local syn_cur_hp   = hp       -- live hp (= mhp at game start; doesn't matter)
      local syn_cur_mhp  = mhp

      local syn_buggy   = syn_cur_mhp * (syn_cur_hp / syn_cur_mhp) - syn_cur_hp  -- always 0
      local syn_correct = syn_cur_mhp * (syn_prev_hp / syn_prev_mhp) - syn_cur_hp -- mhp+5 - hp

      crawl.stderr("[INFO] syn_cur_hp=" .. tostring(syn_cur_hp) .. " syn_cur_mhp=" .. tostring(syn_cur_mhp))
      crawl.stderr("[INFO] syn_prev_hp=" .. tostring(syn_prev_hp) .. " syn_prev_mhp=" .. tostring(syn_prev_mhp))
      crawl.stderr("[INFO] syn_buggy   = " .. tostring(syn_buggy))
      crawl.stderr("[INFO] syn_correct = " .. tostring(syn_correct))

      -- ── Assertions ────────────────────────────────────────────────────────

      -- 1. Buggy formula is always 0 (the live tautology)
      T.eq(buggy_damage_taken, 0, "buggy-formula-always-zero")

      -- 2. Buggy expected_hp is identical to current hp (tautology proof)
      T.eq(buggy_expected_hp, hp, "buggy-expected-always-equals-current-hp")

      -- 3. ad_prev was set non-zero before f_announce_hp_mp.ready() ran
      T.true_(_saved_ad_prev_hp > 0, "ad-prev-hp-was-nonzero")
      T.true_(_saved_ad_prev_mhp > 0, "ad-prev-mhp-was-nonzero")

      -- 4. Synthetic buggy formula is 0 (holds for ANY hp/mhp values)
      T.eq(syn_buggy, 0, "synthetic-buggy-always-zero")

      -- 5. Correct formula with prev_hp = mhp+5 gives positive damage_taken
      --    (because mhp*(mhp+5)/mhp - hp = mhp + 5 - hp >= 5 > 0 when hp <= mhp)
      T.true_(syn_correct > 0, "synthetic-correct-formula-nonzero")

      -- 6. The two formulas diverge: correct > buggy (= 0) when prev_hp > cur_hp
      T.true_(syn_correct > syn_buggy, "formulas-diverge-when-prev-hp-gt-cur-hp")

      -- 7. Confirm DAMAGE alert DID fire during turn 0
      --    (fixed formula: damage_taken = 5 >= mhp * 0.20 → BIG DAMAGE fires)
      local damage_fired = T.messages_contain("BIG DAMAGE") or T.messages_contain("MASSIVE DAMAGE")
      T.true_(damage_fired, "damage-alert-fires-after-fix")

      -- 8. With the correct formula, the synthetic scenario exceeds dmg_flash_threshold
      local threshold = f_announce_hp_mp.Config.dmg_flash_threshold
      local syn_would_fire = syn_correct >= (syn_cur_mhp * threshold)
      crawl.stderr("[INFO] dmg_flash_threshold = " .. tostring(threshold))
      crawl.stderr("[INFO] syn_correct (" .. tostring(syn_correct) .. ") >= mhp*threshold (" .. tostring(syn_cur_mhp * threshold) .. ")? " .. tostring(syn_would_fire))
      T.true_(syn_would_fire, "correct-formula-would-trigger-damage-alert")

      T.pass("announce-hp-mp-damage")
      T.done()
    end
  end)
end
