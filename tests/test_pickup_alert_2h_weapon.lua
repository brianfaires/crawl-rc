---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (2-handed weapon AddHand logic)
-- Verifies that f_pa_weapons.alert_weapon() correctly handles the 1h -> 2h upgrade path
-- (the "AddHand" path in get_upgrade_alert) for a character with a free offhand.
--
-- Character: Mummy Berserker with starting mace (1-handed) and no shield.
--
-- Test A (should alert):
--   A great mace (2H, same Maces skill, much higher DPS) should trigger a "2-handed weapon"
--   alert. Conditions:
--     - BRC.eq.get_hands(great_mace) = 2 > cur.hands = 1  -> not a "same or fewer hands" case
--     - BRC.you.free_offhand() = true (no shield)          -> can_use_2h_without_losing_shield()
--     - DPS ratio >> AddHand.not_using (1.0)               -> check_upgrade_free_offhand fires
--
-- Test B (should NOT alert):
--   Same great mace, but with the AddHand.not_using threshold temporarily raised to 999,
--   so the DPS ratio check fails. Confirms that the alert is gated on the ratio threshold,
--   not some other condition.
--
-- Note: The Testing config sets weapon_sensitivity=0.5, which halves the effective DPS ratio.
-- The pre-sensitivity ratio is ~1.48, so the effective ratio is ~0.74 < 1.0 (threshold).
-- To isolate the AddHand logic, we restore sensitivity to 1.0 for the duration of the test.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give great mace + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): call f_pa_weapons.alert_weapon() directly, assert results, T.done()
--
-- Note: alert_weapon() is called directly (not via BRC.autopickup), bypassing the
-- already_alerted / OTA / turn-guard checks in check_and_trigger_alerts. This matches
-- the pattern in test_pickup_alert_weapon_no_upgrade.lua.
---------------------------------------------------------------------------------------------------

test_pickup_alert_2h_weapon = {}
test_pickup_alert_2h_weapon.BRC_FEATURE_NAME = "test-pickup-alert-2h-weapon"

local _phase = "give"

function test_pickup_alert_2h_weapon.ready()
  if T._done then return end

  T.run("pickup-alert-2h-weapon", function()
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

      -- Sanity checks: confirm the 2H / free-offhand preconditions
      T.eq(BRC.eq.get_hands(floor_weap), 2, "great-mace-is-2-handed")
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

      -- Restore weapon_sensitivity to 1.0 to isolate the AddHand ratio logic.
      -- The Testing config sets weapon_sensitivity=0.5, which halves the effective ratio.
      -- The pre-sensitivity ratio for great mace vs starting mace is ~1.48 (well above 1.0),
      -- but 1.48 * 0.5 = 0.74 falls below not_using=1.0.  Restoring to 1.0 lets the ratio
      -- pass the threshold, which is the intended test.
      local orig_sensitivity = f_pickup_alert.Config.Alert.weapon_sensitivity
      f_pickup_alert.Config.Alert.weapon_sensitivity = 1.0

      -- ── Test A: great mace should alert (free offhand, DPS ratio >> 1.0) ──────────────────
      local result_a = f_pa_weapons.alert_weapon(floor_weap)
      T.true_(result_a ~= nil and result_a ~= false, "2h-weapon-alerts-with-free-offhand")

      -- ── Test B: raise not_using threshold to 999, same weapon should NOT alert ────────────
      -- Reset already_alerted so the second call is not suppressed by deduplication.
      f_pa_data.forget_alert(floor_weap)

      local AddHand = f_pickup_alert.Config.Tuning.Weap.Alert.AddHand
      local orig_not_using  = AddHand.not_using
      local orig_new_ego_th = f_pickup_alert.Config.Tuning.Weap.Alert.new_ego
      AddHand.not_using = 999   -- DPS ratio can never exceed this -> alert should not fire
      -- Also raise new_ego threshold so the new-ego path (if any branded ego) can't fire either
      f_pickup_alert.Config.Tuning.Weap.Alert.new_ego = 999

      local result_b = f_pa_weapons.alert_weapon(floor_weap)
      T.false_(result_b, "2h-weapon-no-alert-when-threshold-999")

      -- ── Restore all settings ──────────────────────────────────────────────────────────────
      AddHand.not_using = orig_not_using
      f_pickup_alert.Config.Tuning.Weap.Alert.new_ego           = orig_new_ego_th
      f_pickup_alert.Config.Alert.weapon_sensitivity             = orig_sensitivity
      pa_high_score.weapon                                       = orig_hs_weapon
      pa_high_score.plain_dmg                                    = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl           = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl     = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-2h-weapon")
      T.done()
    end
  end)
end
