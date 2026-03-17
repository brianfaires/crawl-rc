---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (2-handed weapon blocked by shield)
-- Verifies that f_pa_weapons.alert_weapon() returns nil/false for a 2-handed weapon when
-- BRC.you.free_offhand() returns false (shield equipped), and does alert when free_offhand()
-- returns true (no shield / offhand is free).
--
-- Character: Mummy Berserker with starting mace (1-handed).
--
-- Test A (should NOT alert):
--   Mock BRC.you.free_offhand to return false (simulating shield equipped).
--   A great mace (2H) on the floor should NOT alert because the code path returns nil:
--     BRC.eq.get_hands(great_mace) = 2 > cur.hands = 1  -> 2H branch
--     can_use_2h_without_losing_shield() -> free_offhand()=false AND shield_skill=0 < ignore_sh_lvl
--     Wait -- ignore_sh_lvl=4.0, and skill=0 < 4.0, so can_use_2h_without_losing_shield() is TRUE
--     even without free_offhand().  To properly simulate "has shield with trained shields",
--     we also temporarily raise ignore_sh_lvl above any skill value (e.g. 999 -> no, we need
--     it to be low so the shield-skill bypass doesn't kick in).
--     Strategy: mock free_offhand=false AND raise ignore_sh_lvl to -1 (< 0, always false).
--   Result: can_use_2h_without_losing_shield() = false -> falls through to check_upgrade_lose_shield
--   check_upgrade_lose_shield: great mace is unbranded -> returns false -> no alert.
--
-- Test B (should alert):
--   Restore free_offhand (unmocked) and restore ignore_sh_lvl.
--   Same great mace should fire an alert via the free-offhand path.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give great mace + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): call f_pa_weapons.alert_weapon() directly, assert results, T.done()
--
-- Note: alert_weapon() is called directly (not via BRC.autopickup), bypassing the
-- already_alerted / OTA / turn-guard checks in check_and_trigger_alerts. This matches
-- the pattern in test_pickup_alert_2h_weapon.lua.
---------------------------------------------------------------------------------------------------

test_pickup_alert_2h_with_shield = {}
test_pickup_alert_2h_with_shield.BRC_FEATURE_NAME = "test-pickup-alert-2h-with-shield"

local _phase = "give"

function test_pickup_alert_2h_with_shield.ready()
  if T._done then return end

  T.run("pickup-alert-2h-with-shield", function()
    if _phase == "give" then
      -- Place a plain great mace on the floor and identify it.
      -- "great mace" is the 2-handed Maces weapon in DCSS (17 damage, -4 accuracy, ~14.8 DPS).
      T.wizard_give("great mace")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    elseif _phase == "verify" then
      -- Find the great mace on the floor
      local floor_weap = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("great mace") then
          floor_weap = it
          break
        end
      end
      T.true_(floor_weap ~= nil, "great-mace-on-floor")
      if not floor_weap then T.done() return end

      -- Sanity check: great mace requires 2 hands
      T.eq(BRC.eq.get_hands(floor_weap), 2, "great-mace-is-2-handed")

      -- Disable force_more for all weapon alert types to prevent headless hang.
      local M = f_pickup_alert.Config.Alert.More
      local orig_upgrade   = M.upgrade_weap
      local orig_early     = M.early_weap
      local orig_hs        = M.high_score_weap
      local orig_ego       = M.weap_ego
      M.upgrade_weap    = false
      M.early_weap      = false
      M.high_score_weap = false
      M.weap_ego        = false

      -- Suppress the early-weapon XL window (XL 1 <= Early.xl=7 would otherwise fire
      -- an "Early weapon" alert and interfere with what we're testing).
      local W = f_pickup_alert.Config.Tuning.Weap
      local orig_early_xl        = W.Alert.Early.xl
      local orig_early_ranged_xl = W.Alert.EarlyRanged.xl
      W.Alert.Early.xl       = 0
      W.Alert.EarlyRanged.xl = 0

      -- Pre-fill pa_high_score to a very high value so update_high_scores() returns nil,
      -- suppressing any "Highest damage" alert from get_weap_high_score_alert().
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      -- Restore weapon_sensitivity to 1.0 to isolate the AddHand ratio logic.
      -- The Testing config sets weapon_sensitivity=0.5, which halves the effective ratio.
      local orig_sensitivity = f_pickup_alert.Config.Alert.weapon_sensitivity
      f_pickup_alert.Config.Alert.weapon_sensitivity = 1.0

      -- ── Test A: mock free_offhand=false AND disable shield-skill bypass ──────────────────
      -- can_use_2h_without_losing_shield() = free_offhand() OR (shield_skill < ignore_sh_lvl)
      -- At XL1, shield_skill=0 which is < ignore_sh_lvl=4.0 by default, so we must also
      -- set ignore_sh_lvl to a negative sentinel to disable the skill-based bypass.
      local orig_ignore_sh = W.Alert.AddHand.ignore_sh_lvl
      W.Alert.AddHand.ignore_sh_lvl = -1  -- skill can never be < -1, so bypass never fires

      local orig_free_offhand = BRC.you.free_offhand
      BRC.you.free_offhand = function() return false end

      local result_a = f_pa_weapons.alert_weapon(floor_weap)
      T.false_(result_a, "no-alert-with-no-free-offhand")

      -- ── Test B: restore free_offhand and ignore_sh_lvl; great mace should alert ──────────
      BRC.you.free_offhand = orig_free_offhand
      W.Alert.AddHand.ignore_sh_lvl = orig_ignore_sh

      -- Reset already_alerted so the second call is not suppressed by deduplication.
      f_pa_data.forget_alert(floor_weap)

      local result_b = f_pa_weapons.alert_weapon(floor_weap)
      T.true_(result_b ~= nil and result_b ~= false, "alert-fires-with-free-offhand")

      -- ── Restore all settings ──────────────────────────────────────────────────────────────
      f_pickup_alert.Config.Alert.weapon_sensitivity = orig_sensitivity
      pa_high_score.weapon    = orig_hs_weapon
      pa_high_score.plain_dmg = orig_hs_plain
      W.Alert.Early.xl        = orig_early_xl
      W.Alert.EarlyRanged.xl  = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-2h-with-shield")
      T.done()
    end
  end)
end
