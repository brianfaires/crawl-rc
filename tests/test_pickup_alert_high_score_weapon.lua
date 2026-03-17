---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (high-score weapon alert path)
-- Verifies that f_pa_weapons.alert_weapon() fires via get_weap_high_score_alert() when a floor
-- weapon has higher DPS than pa_high_score.weapon.
--
-- Character: Mummy Berserker with starting mace (1-handed) and no shield.
--
-- Background:
--   get_weap_high_score_alert(it) is the last alert path in get_weapon_alert(). It fires when:
--     1. _weapon_cache is NOT empty (character is using weapons)
--     2. f_pa_data.update_high_scores(it) returns a non-nil category string
--        (i.e., the floor weapon has higher branded or plain DPS than pa_high_score.weapon /
--         pa_high_score.plain_dmg)
--
--   pa_high_score.weapon is seeded at init by f_pa_weapons.init() scanning inventory weapons.
--   By the time "verify" runs it equals the starting mace's branded DPS (~11.004).
--   A great mace (2H, ~23 DPS) clearly exceeds this, but to make the test deterministic we
--   reset pa_high_score.weapon = 0 before Test A.
--
-- Test A (should alert):
--   Reset pa_high_score.weapon = 0, pa_high_score.plain_dmg = 0.
--   Call f_pa_weapons.alert_weapon(floor_great_mace).
--   With all other alert paths suppressed (upgrade, early, ego) and the high score reset,
--   get_weap_high_score_alert fires and returns "Highest damage".
--   -> result_a should be truthy.
--
-- Test B (should NOT alert):
--   Set pa_high_score.weapon = 999, pa_high_score.plain_dmg = 999.
--   Call f_pa_weapons.alert_weapon(floor_great_mace).
--   update_high_scores() returns nil because great mace DPS < 999.
--   -> result_b should be false/nil.
--
-- Preconditions enforced in "verify":
--   - All force_more flags disabled (upgrade_weap, early_weap, high_score_weap, weap_ego)
--   - Early weapon XL window suppressed (Early.xl = 0, EarlyRanged.xl = 0)
--   - weapon_sensitivity restored to 1.0 (Testing config sets it to 0.5)
--   - upgrade alert paths suppressed by pre-filling pa_high_score to 999 for Test B,
--     and by raising all upgrade thresholds so only high_score path can fire for Test A
--
-- To isolate get_weap_high_score_alert and prevent other paths from firing in Test A, we
-- raise the upgrade thresholds (pure_dps, gain_ego, new_ego, AddHand.not_using) to 999.
-- This ensures that even though great mace is a better weapon, only the high-score path fires.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give great mace + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): find great mace on floor, run Test A + B, restore settings, T.done()
---------------------------------------------------------------------------------------------------

test_pickup_alert_high_score_weapon = {}
test_pickup_alert_high_score_weapon.BRC_FEATURE_NAME = "test-pickup-alert-high-score-weapon"

local _phase = "give"

function test_pickup_alert_high_score_weapon.ready()
  if T._done then return end

  T.run("pickup-alert-high-score-weapon", function()

    -- ── Phase 1: place a plain great mace on the floor ─────────────────────────────────────
    if _phase == "give" then
      T.wizard_give("great mace")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    -- ── Phase 2: verify the high-score alert path ───────────────────────────────────────────
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

      -- Sanity check: no shield, so 2H weapon is usable
      T.true_(BRC.you.free_offhand(), "has-free-offhand")

      -- ── Disable force_more for all weapon alert types ─────────────────────────────────────
      local M = f_pickup_alert.Config.Alert.More
      local orig_upgrade   = M.upgrade_weap
      local orig_early     = M.early_weap
      local orig_hs        = M.high_score_weap
      local orig_ego       = M.weap_ego
      M.upgrade_weap    = false
      M.early_weap      = false
      M.high_score_weap = false
      M.weap_ego        = false

      -- ── Suppress early-weapon XL window ───────────────────────────────────────────────────
      -- XL 1 is within Early.xl=7; without suppression the "Early weapon" path would fire
      -- before get_weap_high_score_alert gets a chance.
      local W_Alert = f_pickup_alert.Config.Tuning.Weap.Alert
      local orig_early_xl        = W_Alert.Early.xl
      local orig_early_ranged_xl = W_Alert.EarlyRanged.xl
      W_Alert.Early.xl       = 0
      W_Alert.EarlyRanged.xl = 0

      -- ── Restore weapon_sensitivity to 1.0 ─────────────────────────────────────────────────
      -- Testing config sets weapon_sensitivity=0.5. Restore to 1.0 so DPS comparisons use
      -- unadjusted values, matching the real-game intent of the high-score check.
      local orig_sensitivity = f_pickup_alert.Config.Alert.weapon_sensitivity
      f_pickup_alert.Config.Alert.weapon_sensitivity = 1.0

      -- ── Raise upgrade thresholds to 999 to isolate get_weap_high_score_alert ──────────────
      -- Without this, get_inventory_upgrade_alert (the first path in get_weapon_alert) would
      -- also fire for the great mace (much higher DPS than starting mace), making it
      -- impossible to test the high-score path specifically.
      local orig_pure_dps      = W_Alert.pure_dps
      local orig_gain_ego      = W_Alert.gain_ego
      local orig_new_ego       = W_Alert.new_ego
      local orig_not_using     = W_Alert.AddHand.not_using
      local orig_add_ego_lose  = W_Alert.AddHand.add_ego_lose_sh
      W_Alert.pure_dps              = 999
      W_Alert.gain_ego              = 999
      W_Alert.new_ego               = 999
      W_Alert.AddHand.not_using     = 999
      W_Alert.AddHand.add_ego_lose_sh = 999

      -- ── Test A: pa_high_score reset to 0, great mace should trigger high-score alert ──────
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 0
      pa_high_score.plain_dmg = 0

      crawl.stderr("DEBUG Test A: pa_high_score.weapon=" .. tostring(pa_high_score.weapon))
      local result_a = f_pa_weapons.alert_weapon(floor_weap)
      crawl.stderr("DEBUG Test A: result_a=" .. tostring(result_a))
      T.true_(result_a ~= nil and result_a ~= false, "high-score-weapon-alert-fires")

      -- ── Test B: pa_high_score set to 999, great mace should NOT alert ─────────────────────
      -- Reset already_alerted so deduplication does not suppress the call.
      f_pa_data.forget_alert(floor_weap)

      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      crawl.stderr("DEBUG Test B: pa_high_score.weapon=" .. tostring(pa_high_score.weapon))
      local result_b = f_pa_weapons.alert_weapon(floor_weap)
      crawl.stderr("DEBUG Test B: result_b=" .. tostring(result_b))
      T.true_(result_b == nil or result_b == false, "high-score-weapon-no-alert-when-already-999")

      -- ── Restore all settings ──────────────────────────────────────────────────────────────
      pa_high_score.weapon                             = orig_hs_weapon
      pa_high_score.plain_dmg                          = orig_hs_plain
      W_Alert.pure_dps                                 = orig_pure_dps
      W_Alert.gain_ego                                 = orig_gain_ego
      W_Alert.new_ego                                  = orig_new_ego
      W_Alert.AddHand.not_using                        = orig_not_using
      W_Alert.AddHand.add_ego_lose_sh                  = orig_add_ego_lose
      f_pickup_alert.Config.Alert.weapon_sensitivity   = orig_sensitivity
      W_Alert.Early.xl                                 = orig_early_xl
      W_Alert.EarlyRanged.xl                           = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-high-score-weapon")
      T.done()
    end
  end)
end
