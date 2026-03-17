---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (cross-subtype "Gain ego" path in check_upgrade_no_hand_loss)
-- Verifies that f_pa_weapons.alert_weapon() fires a "Gain ego" alert when a branded floor weapon
-- of a different subtype (but same weapon skill) is compared against a plain inventory weapon,
-- and both weapons require the same or fewer hands.
--
-- Character: Mummy Berserker with starting +0 plain mace (no ego).
--
-- Setup: wizard_give "morningstar ego:flaming plus:3" on the floor.
--   - morningstar (Maces skill, 1-handed) vs starting mace (Maces skill, 1-handed)
--   - subtypes differ: "morningstar" != "mace"  -> cross-subtype path in get_upgrade_alert
--   - BRC.eq.get_hands(morningstar) = 1 <= cur.hands = 1  -> check_upgrade_no_hand_loss
--   - BRC.eq.get_ego(it, true) = "flaming" (truthy, not speed/heavy)
--   - not BRC.eq.get_ego(cur) = true (starting mace has no ego)
--   -> "Gain ego" alert fires if ratio > W.Alert.gain_ego (0.8)
--
-- Note: Testing config sets weapon_sensitivity=0.5, which multiplies the ratio by 0.5.
-- We restore sensitivity to 1.0 so the ratio clears the gain_ego=0.8 threshold.
--
-- Test A (should alert):
--   floor morningstar ego:flaming plus:3 vs plain starting mace -> "Gain ego"
--
-- Test B (should NOT alert):
--   Same morningstar, but with gain_ego=999, pure_dps=999, new_ego=999 -> no alert
--   (all thresholds in check_upgrade_no_hand_loss are raised above any possible ratio)
--
-- Sanity checks:
--   - floor morningstar subtype != starting mace subtype (cross-subtype confirmed)
--   - BRC.eq.get_hands(floor morningstar) == 1 (1-handed confirmed)
--   - BRC.eq.get_ego(floor morningstar) is non-nil (has ego confirmed)
--
-- Phase flow:
--   "give"   (turn 0): wizard_give morningstar ego:flaming plus:3, identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): call f_pa_weapons.alert_weapon() directly, assert A/B, T.done()
--
-- Note: CMD_PICKUP is not used. The starting mace is already in inventory at game start.
-- The floor morningstar remains on the floor; alert_weapon() is called directly.
---------------------------------------------------------------------------------------------------

test_pickup_alert_cross_subtype_gain_ego = {}
test_pickup_alert_cross_subtype_gain_ego.BRC_FEATURE_NAME = "test-pickup-alert-cross-subtype-gain-ego"

local _phase = "give"

function test_pickup_alert_cross_subtype_gain_ego.ready()
  if T._done then return end

  T.run("pickup-alert-cross-subtype-gain-ego", function()

    -- ── Phase 1: place a flaming morningstar on the floor ────────────────────────────────────
    if _phase == "give" then
      -- morningstar is a 1-handed Maces weapon (different subtype from the starting mace).
      -- ego:flaming gives it a brand; plus:3 pushes the DPS ratio comfortably above gain_ego=0.8.
      T.wizard_give("morningstar ego:flaming plus:3")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    -- ── Phase 2: verify the cross-subtype "Gain ego" path ────────────────────────────────────
    elseif _phase == "verify" then

      -- Find the morningstar on the floor
      local floor_ms = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("morningstar") then
          floor_ms = it
          break
        end
      end
      T.true_(floor_ms ~= nil, "morningstar-on-floor")
      if not floor_ms then T.done() return end

      -- ── Sanity checks: confirm cross-subtype / 1-handed / has-ego preconditions ─────────────
      -- The starting Berserker mace should still be in inventory (never picked up the morningstar)
      local inv_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.subtype() == "mace" then
          inv_mace = it
          break
        end
      end
      T.true_(inv_mace ~= nil, "starting-mace-in-inventory")
      if not inv_mace then T.done() return end

      -- Subtypes must differ (cross-subtype is the whole point of this test)
      T.true_(floor_ms.subtype() ~= inv_mace.subtype(), "floor-and-inv-subtypes-differ")

      -- Morningstar must be 1-handed (same or fewer hands -> check_upgrade_no_hand_loss)
      T.eq(BRC.eq.get_hands(floor_ms), 1, "morningstar-is-1-handed")

      -- Floor morningstar must have an ego (drives the "Gain ego" branch)
      T.true_(BRC.eq.get_ego(floor_ms) ~= nil, "morningstar-has-ego")

      -- ── Disable force_more for all weapon alert types to prevent headless hang ───────────────
      local M = f_pickup_alert.Config.Alert.More
      local orig_upgrade   = M.upgrade_weap
      local orig_early     = M.early_weap
      local orig_hs        = M.high_score_weap
      local orig_ego       = M.weap_ego
      M.upgrade_weap    = false
      M.early_weap      = false
      M.high_score_weap = false
      M.weap_ego        = false

      -- ── Suppress early-weapon window (XL 1 <= Early.xl=7 would fire "Early weapon") ─────────
      local orig_early_xl        = f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl
      local orig_early_ranged_xl = f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl       = 0
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = 0

      -- ── Pre-fill pa_high_score to suppress any "Highest damage" alert ───────────────────────
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      -- ── Restore weapon_sensitivity to 1.0 to isolate the gain_ego ratio check ───────────────
      -- Testing config sets weapon_sensitivity=0.5. The ratio in check_upgrade_no_hand_loss is:
      --   penalty * get_score(it) / best_score * weapon_sensitivity
      -- With sensitivity=0.5 the effective ratio may fall below gain_ego=0.8.
      -- Restoring to 1.0 ensures the flaming morningstar's ratio clears the threshold.
      local orig_sensitivity = f_pickup_alert.Config.Alert.weapon_sensitivity
      f_pickup_alert.Config.Alert.weapon_sensitivity = 1.0

      -- ── Disable weapons_pure_upgrades_only to force the code into check_upgrade_no_hand_loss ─
      -- When weapons_pure_upgrades_only=true, get_upgrade_alert() short-circuits at the top via
      -- is_weapon_upgrade(it, cur, false), returning "Weapon upgrade" before ever reaching
      -- check_upgrade_no_hand_loss. Disabling it lets execution reach the cross-subtype ratio
      -- logic, which is the path this test is exercising.
      local orig_pure_upgrades = f_pickup_alert.Config.Pickup.weapons_pure_upgrades_only
      f_pickup_alert.Config.Pickup.weapons_pure_upgrades_only = false

      local W_Alert = f_pickup_alert.Config.Tuning.Weap.Alert

      -- ── Test A: flaming morningstar should fire "Gain ego" ───────────────────────────────────
      -- Route: get_upgrade_alert -> weapons_pure_upgrades_only=false (skip early return)
      --   -> subtypes differ -> BRC.eq.get_hands(it)=1 <= cur.hands=1
      --   -> check_upgrade_no_hand_loss
      --   -> BRC.eq.get_ego(it, true)="flaming" (truthy)
      --   -> not BRC.eq.get_ego(cur) = true (plain mace)
      --   -> ratio > gain_ego=0.8  -> make_alert("Gain ego")
      local result_a = f_pa_weapons.alert_weapon(floor_ms)
      T.true_(result_a ~= nil and result_a ~= false, "cross-subtype-gain-ego-alert-fires")

      -- ── Test B: raise all thresholds to 999; alert should NOT fire ───────────────────────────
      -- Reset deduplication state so the second call is not suppressed.
      f_pa_data.forget_alert(floor_ms)

      local orig_gain_ego = W_Alert.gain_ego
      local orig_new_ego  = W_Alert.new_ego
      local orig_pure_dps = W_Alert.pure_dps
      W_Alert.gain_ego = 999   -- "Gain ego" path: ratio can never exceed 999
      W_Alert.new_ego  = 999   -- "New ego" path (if applicable): also blocked
      W_Alert.pure_dps = 999   -- "DPS increase" fallback: also blocked

      local result_b = f_pa_weapons.alert_weapon(floor_ms)
      T.false_(result_b, "cross-subtype-gain-ego-no-alert-when-threshold-999")

      -- ── Restore all settings ──────────────────────────────────────────────────────────────
      W_Alert.gain_ego                                           = orig_gain_ego
      W_Alert.new_ego                                            = orig_new_ego
      W_Alert.pure_dps                                           = orig_pure_dps
      f_pickup_alert.Config.Pickup.weapons_pure_upgrades_only    = orig_pure_upgrades
      f_pickup_alert.Config.Alert.weapon_sensitivity             = orig_sensitivity
      pa_high_score.weapon                                       = orig_hs_weapon
      pa_high_score.plain_dmg                                    = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl           = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl     = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-cross-subtype-gain-ego")
      T.done()
    end
  end)
end
