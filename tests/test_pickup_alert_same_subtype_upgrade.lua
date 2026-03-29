---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (same-subtype upgrade logic)
-- Verifies that f_pa_weapons.alert_weapon() correctly handles the same-subtype upgrade path
-- (check_upgrade_same_subtype) in get_upgrade_alert().
--
-- Character: Mummy Berserker with starting +0 mace (no shield).
--
-- Test A (should alert):
--   A +5 mace (same subtype, much higher DPS/score) should trigger a "Weapon upgrade" alert.
--   Conditions:
--     - floor mace subtype == inventory mace subtype  -> routes to check_upgrade_same_subtype
--     - both weapons are plain (no ego)               -> no ego diff/gain branch
--     - get_score(+5 mace) > best_score / 1.0         -> score check passes
--
-- Test B (should NOT alert):
--   Same +5 mace, but with weapon_sensitivity set to 0.001, making the threshold
--   best_score / 0.001 = 1000 * best_score, which the +5 mace can never exceed.
--   Confirms that the alert is gated on the score/DPS threshold, not some other condition.
--
-- Note: The Testing config sets weapon_sensitivity=0.5. We restore it to 1.0 for Test A
-- to ensure the +5 mace's score improvement clears the threshold cleanly.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give mace plus:5 + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): call f_pa_weapons.alert_weapon() directly, assert results, T.done()
--
-- Note: alert_weapon() is called directly (not via BRC.autopickup), bypassing the
-- already_alerted / OTA / turn-guard checks in check_and_trigger_alerts. This matches
-- the pattern in test_pickup_alert_2h_weapon.lua.
---------------------------------------------------------------------------------------------------

test_pickup_alert_same_subtype_upgrade = {}
test_pickup_alert_same_subtype_upgrade.BRC_FEATURE_NAME = "test-pickup-alert-same-subtype-upgrade"

local _phase = "give"

function test_pickup_alert_same_subtype_upgrade.ready()
  if T._done then return end

  T.run("pickup-alert-same-subtype-upgrade", function()
    if _phase == "give" then
      -- Place a +5 mace on the floor and identify it.
      -- The starting Berserker mace is +0, so a +5 mace is a clear same-subtype DPS upgrade.
      T.wizard_give("mace plus:5")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    elseif _phase == "verify" then
      -- Find the +5 mace on the floor
      local floor_mace = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("mace") and (it.plus or 0) == 5 then
          floor_mace = it
          break
        end
      end
      T.true_(floor_mace ~= nil, "mace-plus5-on-floor")
      if not floor_mace then T.done() return end

      -- Sanity checks: confirm same-subtype and 1-handed preconditions
      T.eq(BRC.eq.get_hands(floor_mace), 1, "mace-is-1-handed")

      -- Find the inventory mace to confirm subtype match
      local inv_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.name("base"):find("mace") then
          inv_mace = it
          break
        end
      end
      T.true_(inv_mace ~= nil, "inventory-mace-exists")
      if inv_mace then
        T.eq(floor_mace.subtype(), inv_mace.subtype(), "floor-and-inv-mace-same-subtype")
      end

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
      local orig_early_xl        = f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl
      local orig_early_ranged_xl = f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl       = 0
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = 0

      -- Pre-fill pa_high_score to a very high value so update_high_scores() returns nil,
      -- suppressing any "Highest damage" alert from get_weap_high_score_alert().
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      -- Restore weapon_sensitivity to 1.0 to isolate the same-subtype score logic.
      -- The Testing config sets weapon_sensitivity=0.5.
      -- check_upgrade_same_subtype checks: get_score(it) > best_score / s
      -- With s=0.5, the threshold is 2x the inventory score, which a +5 mace won't clear.
      -- With s=1.0, the threshold equals the inventory score, which the +5 mace easily beats.
      local orig_sensitivity = f_pickup_alert.Config.Alert.weapon_sensitivity
      f_pickup_alert.Config.Alert.weapon_sensitivity = 1.0

      -- Disable weapons_pure_upgrades_only so get_upgrade_alert() does NOT short-circuit
      -- via the is_weapon_upgrade(it, cur, false) early return before reaching
      -- check_upgrade_same_subtype(). With weapons_pure_upgrades_only=true, a plain +5 vs
      -- plain +0 same-subtype weapon returns an alert immediately (score-insensitive), which
      -- would bypass the score/DPS threshold check we are trying to exercise.
      local orig_pure_upgrades = f_pickup_alert.Config.Pickup.weapons_pure_upgrades_only
      f_pickup_alert.Config.Pickup.weapons_pure_upgrades_only = false

      -- ── Test A: +5 mace should alert (same subtype, higher score/DPS) ────────────────────
      local result_a = f_pa_weapons.alert_weapon(floor_mace)
      T.true_(result_a ~= nil and result_a ~= false, "same-subtype-upgrade-alert-fires")

      -- ── Test B: set sensitivity to 0.001 -> threshold is 1000x score, alert should fail ──
      -- Reset already_alerted so the second call is not suppressed by deduplication.
      f_pa_data.forget_alert(floor_mace)

      -- Setting weapon_sensitivity to near-zero makes threshold best_score / s enormous,
      -- so no score or DPS check can pass.  Also confirm the ego path won't fire
      -- (both weapons are plain, so it_ego == nil -> no ego alert).
      f_pickup_alert.Config.Alert.weapon_sensitivity = 0.001

      local result_b = f_pa_weapons.alert_weapon(floor_mace)
      T.false_(result_b, "same-subtype-no-alert-when-threshold-999")

      -- ── Restore all settings ─────────────────────────────────────────────────────────────
      f_pickup_alert.Config.Pickup.weapons_pure_upgrades_only   = orig_pure_upgrades
      f_pickup_alert.Config.Alert.weapon_sensitivity             = orig_sensitivity
      pa_high_score.weapon                                       = orig_hs_weapon
      pa_high_score.plain_dmg                                    = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl           = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl     = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-same-subtype-upgrade")
      T.done()
    end
  end)
end
