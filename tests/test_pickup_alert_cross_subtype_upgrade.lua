---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (cross-subtype upgrade logic)
-- Verifies that f_pa_weapons.alert_weapon() correctly handles the cross-subtype upgrade path
-- (check_upgrade_no_hand_loss) in get_upgrade_alert().
--
-- Character: Mummy Berserker with starting mace (1-handed, Maces & Flails skill).
--
-- The cross-subtype path is reached when:
--   cur.subtype() ~= it.subtype()  (different weapon subtypes)
--   AND BRC.eq.get_hands(it) <= cur.hands  (no extra hand needed)
--
-- A war axe is 1-handed and belongs to the Axes skill — a different subtype from Maces.
-- Because hands(war axe)=1 == cur.hands=1, get_upgrade_alert() routes to
-- check_upgrade_no_hand_loss(), NOT to the AddHand or lose-shield branches.
--
-- check_upgrade_no_hand_loss() logic:
--   ratio = penalty * get_score(it) / best_score * weapon_sensitivity
--     where penalty = (skill(it.weap_skill) + damp) / (skill(top_attack_skill) + damp)
--   1. If it has an ego (excluding Speed/Heavy): check gain_ego (0.8) or new_ego (0.8) thresholds.
--   2. If ratio > pure_dps (1.0): alert "DPS increase".
--
-- Test A (should alert):
--   A plain war axe on the floor.  weapon_sensitivity restored to 1.0 so the ratio can clear
--   pure_dps=1.0.  A war axe (11 base dmg) comfortably outscores a starting mace (8 base dmg)
--   even after the cross-skill penalty (Axes=0 skill at game start).
--   Expected: alert fires with "DPS increase".
--
-- Test B (should NOT alert):
--   Same war axe, but pure_dps threshold raised to 999.  The gain_ego/new_ego paths are also
--   blocked because the war axe is plain (no ego), so no ego branch fires either.
--   Expected: alert does not fire.
--
-- Note on weapon_sensitivity:
--   The Testing config sets weapon_sensitivity=0.5.  In check_upgrade_no_hand_loss the ratio
--   is multiplied by weapon_sensitivity (not divided), so 0.5 halves the effective ratio.
--   A war axe vs starting mace gives a pre-sensitivity ratio of roughly 0.9 (accounting for
--   the cross-skill penalty with damp=8, Axes=0, Maces~2), which * 0.5 = ~0.45 < 1.0.
--   Restoring sensitivity to 1.0 gives ~0.9, still marginal.  Because the exact DPS depends
--   on in-game calculations, we raise sensitivity to 2.0 for Test A to ensure the ratio
--   clears pure_dps=1.0 reliably, then confirm Test B blocks it at pure_dps=999.
--
-- Note on weapons_pure_upgrades_only:
--   With this flag true, get_upgrade_alert() checks is_weapon_upgrade(it, cur, false) first.
--   For cross-subtype weapons it checks weap_skill equality — war axe (Axes) != mace (Maces),
--   so that early-exit returns false and does NOT short-circuit to check_upgrade_no_hand_loss.
--   The flag is therefore left at its configured value; it does not affect this test.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give war axe + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): call f_pa_weapons.alert_weapon() directly, assert results, T.done()
--
-- Note: alert_weapon() is called directly (not via BRC.autopickup), bypassing the
-- already_alerted / OTA / turn-guard checks in check_and_trigger_alerts.  This matches
-- the pattern in test_pickup_alert_2h_weapon.lua.
---------------------------------------------------------------------------------------------------

test_pickup_alert_cross_subtype_upgrade = {}
test_pickup_alert_cross_subtype_upgrade.BRC_FEATURE_NAME = "test-pickup-alert-cross-subtype-upgrade"

local _phase = "give"

function test_pickup_alert_cross_subtype_upgrade.ready()
  if T._done then return end

  T.run("pickup-alert-cross-subtype-upgrade", function()
    if _phase == "give" then
      -- Place a plain war axe on the floor and identify it.
      -- War axe: 1-handed, Axes skill, 11 base damage — clearly stronger than the starting
      -- +0 mace (8 base damage), but belonging to a different weapon subtype.
      T.wizard_give("war axe")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    elseif _phase == "verify" then
      -- Find the war axe on the floor
      local floor_weap = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("war axe") then
          floor_weap = it
          break
        end
      end
      T.true_(floor_weap ~= nil, "war-axe-on-floor")
      if not floor_weap then T.done() return end

      -- Sanity checks: confirm 1-handed and cross-subtype preconditions
      T.eq(BRC.eq.get_hands(floor_weap), 1, "war-axe-is-1-handed")

      -- Find the inventory mace to confirm the subtype DIFFERS (cross-subtype path)
      local inv_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.name("base"):find("mace") then
          inv_mace = it
          break
        end
      end
      T.true_(inv_mace ~= nil, "inventory-mace-exists")
      if inv_mace then
        T.true_(floor_weap.subtype() ~= inv_mace.subtype(), "war-axe-and-mace-are-different-subtypes")
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
      -- an "Early weapon" alert and interfere with what we are testing).
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

      -- Set weapon_sensitivity to 2.0 for Test A.
      -- check_upgrade_no_hand_loss multiplies the ratio by weapon_sensitivity.
      -- The cross-skill penalty (Axes=0, damp=8) damps the ratio below 1.0 at sensitivity=1.0,
      -- so we use 2.0 to ensure the ratio reliably clears pure_dps=1.0 regardless of the
      -- exact in-game DPS values, while still exercising the check_upgrade_no_hand_loss path.
      local orig_sensitivity = f_pickup_alert.Config.Alert.weapon_sensitivity
      f_pickup_alert.Config.Alert.weapon_sensitivity = 2.0

      -- ── Test A: war axe should alert (cross-subtype, same hands, high DPS ratio) ──────────
      local result_a = f_pa_weapons.alert_weapon(floor_weap)
      T.true_(result_a ~= nil and result_a ~= false, "cross-subtype-upgrade-alert-fires")

      -- ── Test B: raise pure_dps threshold to 999, alert should NOT fire ───────────────────
      -- Reset already_alerted so the second call is not suppressed by deduplication.
      f_pa_data.forget_alert(floor_weap)

      -- pure_dps=999 makes the DPS ratio check in check_upgrade_no_hand_loss impossible to pass.
      -- The war axe is plain (no ego), so neither the gain_ego nor new_ego branch fires.
      -- Therefore no alert should be returned.
      local W_Alert = f_pickup_alert.Config.Tuning.Weap.Alert
      local orig_pure_dps  = W_Alert.pure_dps
      local orig_gain_ego  = W_Alert.gain_ego
      local orig_new_ego   = W_Alert.new_ego
      W_Alert.pure_dps  = 999
      W_Alert.gain_ego  = 999
      W_Alert.new_ego   = 999

      local result_b = f_pa_weapons.alert_weapon(floor_weap)
      T.false_(result_b, "cross-subtype-no-alert-when-threshold-999")

      -- ── Restore all settings ─────────────────────────────────────────────────────────────
      W_Alert.pure_dps  = orig_pure_dps
      W_Alert.gain_ego  = orig_gain_ego
      W_Alert.new_ego   = orig_new_ego
      f_pickup_alert.Config.Alert.weapon_sensitivity             = orig_sensitivity
      pa_high_score.weapon                                       = orig_hs_weapon
      pa_high_score.plain_dmg                                    = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl           = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl     = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-cross-subtype-upgrade")
      T.done()
    end
  end)
end
