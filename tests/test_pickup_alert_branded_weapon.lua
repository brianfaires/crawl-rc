---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (ego alert paths for branded floor weapons)
-- Verifies that f_pa_weapons.alert_weapon() fires ego alerts when a branded floor weapon
-- appears and the inventory has no weapon of that ego.
--
-- Character: Mummy Berserker with starting mace (+0 mace, no ego).
--
-- Two code paths are exercised:
--
--   Path 1 – check_upgrade_same_subtype (1H flaming mace vs plain inventory mace):
--     Both floor and inventory weapon are subtype "mace" -> get_upgrade_alert branches to
--     check_upgrade_same_subtype. When floor has an ego and cur does not, that function fires
--     "Gain ego" unconditionally (no ratio threshold). This is the correct path for a 1H
--     branded floor weapon of the same subtype as the starting weapon.
--     NOTE: the "New ego" branch in check_upgrade_no_hand_loss requires a cross-subtype
--     comparison AND an ego'd inventory weapon; it is not reachable with a plain starting mace
--     + same-subtype floor weapon. The "Gain ego" label is the correct alert name here.
--
--   Path 2 – check_upgrade_free_offhand (2H flaming great mace vs plain inventory, free offhand):
--     Floor weapon is 2H, inv is 1H, character has free offhand -> can_use_2h_without_losing_shield.
--     check_upgrade_free_offhand checks: it_ego not in _weapon_cache.egos AND ratio > new_ego.
--     With a plain inventory mace (_weapon_cache.egos = {}), "flaming" is not in egos.
--     With weapon_sensitivity=1.0 the ratio passes new_ego=0.8, firing "New ego (2-handed)".
--     This is the "new ego" path in check_upgrade_free_offhand described in the task.
--
-- Test A (should alert):   1H flaming mace on floor -> "Gain ego" (same-subtype path)
-- Test B (should ALSO alert): all ratio thresholds=999 -> "Gain ego" still fires
--                             (same-subtype "Gain ego" is unconditional; confirms no ratio gate)
-- Test C (should alert):   2H flaming great mace on floor -> "New ego (2-handed)" (free offhand)
-- Test D (should NOT alert): new_ego=999 + AddHand.not_using=999 -> alert suppressed
--
-- Note: buehler.rc Testing config sets weapon_sensitivity=0.5. Restored to 1.0 to ensure
-- the ratio in check_upgrade_free_offhand passes the new_ego threshold.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give flaming mace + flaming great mace, identify, CMD_WAIT -> 1
--   "verify" (turn 1): call f_pa_weapons.alert_weapon() for each, assert A/B/C/D, T.done()
--
-- CMD_PICKUP is not used (cannot be dispatched from inside ready()). Both items remain on
-- the floor; the starting mace stays in inventory as the sole inventory weapon.
---------------------------------------------------------------------------------------------------

test_pickup_alert_branded_weapon = {}
test_pickup_alert_branded_weapon.BRC_FEATURE_NAME = "test-pickup-alert-branded-weapon"

local _phase = "give"

function test_pickup_alert_branded_weapon.ready()
  if T._done then return end

  T.run("pickup-alert-branded-weapon", function()

    -- ── Phase 1: place a flaming mace (1H) and a flaming great mace (2H) on the floor ────────
    if _phase == "give" then
      T.wizard_give("mace ego:flaming plus:3")
      T.wizard_give("great mace ego:flaming plus:3")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    -- ── Phase 2: verify all alert paths ──────────────────────────────────────────────────────
    elseif _phase == "verify" then

      -- Find both floor items
      local floor_mace_1h = nil
      local floor_mace_2h = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name():find("flaming") then
          if BRC.eq.get_hands(it) == 1 then
            floor_mace_1h = it
          elseif BRC.eq.get_hands(it) == 2 then
            floor_mace_2h = it
          end
        end
      end
      T.true_(floor_mace_1h ~= nil, "flaming-mace-1h-on-floor")
      T.true_(floor_mace_2h ~= nil, "flaming-great-mace-2h-on-floor")
      if not floor_mace_1h or not floor_mace_2h then T.done() return end

      -- Confirm same-subtype condition: floor mace and starting inv mace are both "mace"
      local inv_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.subtype() == "mace" then
          inv_mace = it
          break
        end
      end
      T.true_(inv_mace ~= nil, "starting-mace-in-inventory")
      if not inv_mace then T.done() return end
      T.eq(floor_mace_1h.subtype(), inv_mace.subtype(), "floor-and-inv-same-subtype")

      -- Confirm free offhand so 2H path fires via can_use_2h_without_losing_shield()
      T.true_(BRC.you.free_offhand(), "mummy-has-free-offhand")

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

      -- Suppress early-weapon window (XL 1 <= Early.xl=7; +3 branded mace would fire
      -- "Early weapon" before the upgrade path runs).
      local orig_early_xl        = f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl
      local orig_early_ranged_xl = f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl       = 0
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = 0

      -- Pre-fill pa_high_score so neither floor mace triggers a high-score alert.
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      -- Restore weapon_sensitivity to 1.0 to isolate the ego ratio thresholds.
      -- Testing config sets it to 0.5; the 2H path ratio would drop below new_ego=0.8 at 0.5.
      local orig_sensitivity = f_pickup_alert.Config.Alert.weapon_sensitivity
      f_pickup_alert.Config.Alert.weapon_sensitivity = 1.0

      local W_Alert = f_pickup_alert.Config.Tuning.Weap.Alert

      -- ── Test A: 1H flaming mace vs plain starting mace (same subtype) ────────────────────
      -- check_upgrade_same_subtype: it_ego="flaming", cur_ego=nil -> fires "Gain ego"
      -- unconditionally (no ratio check for this branch).
      local result_a = f_pa_weapons.alert_weapon(floor_mace_1h)
      T.true_(result_a ~= nil and result_a ~= false, "gain-ego-alert-fires-same-subtype")

      -- ── Test B: same weapon, all ratio thresholds=999; ego path still fires ───────────────
      -- "Gain ego" in check_upgrade_same_subtype has no ratio gate, so raising thresholds
      -- does NOT suppress it. This confirms the ego path is unconditional for same-subtype.
      f_pa_data.forget_alert(floor_mace_1h)

      local orig_gain_ego = W_Alert.gain_ego
      local orig_new_ego  = W_Alert.new_ego
      local orig_pure_dps = W_Alert.pure_dps
      W_Alert.gain_ego = 999
      W_Alert.new_ego  = 999
      W_Alert.pure_dps = 999

      local result_b = f_pa_weapons.alert_weapon(floor_mace_1h)
      T.true_(result_b ~= nil and result_b ~= false, "gain-ego-same-subtype-unconditional")

      W_Alert.gain_ego = orig_gain_ego
      W_Alert.new_ego  = orig_new_ego
      W_Alert.pure_dps = orig_pure_dps
      f_pa_data.forget_alert(floor_mace_1h)

      -- ── Test C: 2H flaming great mace vs plain starting mace (free offhand) ───────────────
      -- Route: get_upgrade_alert -> can_use_2h_without_losing_shield() -> check_upgrade_free_offhand
      -- check_upgrade_free_offhand: it_ego="flaming", _weapon_cache.egos={}, "flaming" not in egos
      -- ratio > W.Alert.new_ego=0.8 (at sensitivity=1.0) -> fires "New ego (2-handed)"
      local result_c = f_pa_weapons.alert_weapon(floor_mace_2h)
      T.true_(result_c ~= nil and result_c ~= false, "new-ego-2h-alert-fires")

      -- ── Test D: new_ego=999 + AddHand.not_using=999 -> no alert ─────────────────────────
      -- With new_ego=999 the ego path in check_upgrade_free_offhand cannot fire.
      -- With not_using=999 the fallback "2-handed weapon" alert also cannot fire.
      f_pa_data.forget_alert(floor_mace_2h)

      local orig_new_ego_th = W_Alert.new_ego
      local AddHand         = W_Alert.AddHand
      local orig_not_using  = AddHand.not_using
      W_Alert.new_ego       = 999
      AddHand.not_using     = 999

      local result_d = f_pa_weapons.alert_weapon(floor_mace_2h)
      T.false_(result_d, "new-ego-2h-no-alert-when-threshold-999")

      -- ── Restore all settings ──────────────────────────────────────────────────────────────
      W_Alert.new_ego                                          = orig_new_ego_th
      AddHand.not_using                                        = orig_not_using
      f_pickup_alert.Config.Alert.weapon_sensitivity           = orig_sensitivity
      pa_high_score.weapon                                     = orig_hs_weapon
      pa_high_score.plain_dmg                                  = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl         = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl   = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-branded-weapon")
      T.done()
    end
  end)
end
