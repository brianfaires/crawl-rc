---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (First of skill alert path)
-- Verifies that f_pa_weapons.alert_weapon() fires the "First <Skill>" alert when a floor weapon
-- belongs to a skill class tracked in pa_lowest_hands_alerted and its hands count is below
-- the tracked threshold.
--
-- Character: Mummy Berserker with starting mace (Maces skill, 1-handed).
--
-- The get_first_of_skill_alert() function fires when:
--   pa_lowest_hands_alerted[skill] is not nil (only "Ranged Weapons" and "Polearms" are tracked)
--   AND pa_lowest_hands_alerted[skill] > hands
--
-- pa_lowest_hands_alerted["Ranged Weapons"] starts at 3 (meaning no ranged alert has fired yet).
-- A shortbow is a 1-handed ranged weapon: 3 > 1 -> alert fires ("First Ranged Weapon (1-handed)").
--
-- Test A (should alert):
--   shortbow on floor, pa_lowest_hands_alerted["Ranged Weapons"] = 3 (default)
--   -> 3 > 1 -> get_first_of_skill_alert fires
--
-- Test B (should NOT alert):
--   same shortbow, but pa_lowest_hands_alerted["Ranged Weapons"] set to 0
--   -> 0 > 1 is false -> get_first_of_skill_alert returns nil
--
-- Note: we must suppress other alert paths (early_weapon, high_score) to isolate this path.
-- The early-ranged alert (EarlyRanged.xl=14) would fire first for a shortbow; suppress it.
-- Also restore weapon_sensitivity=1.0 (Testing config sets it to 0.5).
--
-- Phase flow:
--   "give"   (turn 0): wizard_give shortbow + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): find shortbow on floor, call f_pa_weapons.alert_weapon(), assert results
---------------------------------------------------------------------------------------------------

test_pickup_alert_first_of_skill = {}
test_pickup_alert_first_of_skill.BRC_FEATURE_NAME = "test-pickup-alert-first-of-skill"

local _phase = "give"

function test_pickup_alert_first_of_skill.ready()
  if T._done then return end

  T.run("pickup-alert-first-of-skill", function()

    -- ── Phase 1: give a plain shortbow, it lands on the floor ────────────────────────────────
    if _phase == "give" then
      T.wizard_give("sling")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    -- ── Phase 2: verify the "First Ranged Weapon" alert fires ────────────────────────────────
    elseif _phase == "verify" then
      -- Find the shortbow on the floor
      local floor_weap = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("sling") then
          floor_weap = it
          break
        end
      end
      T.true_(floor_weap ~= nil, "hand-axe-on-floor")
      if not floor_weap then T.done() return end

      -- Sanity: confirm it is 1-handed
      T.eq(BRC.eq.get_hands(floor_weap), 1, "hand-axe-is-1-handed")

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

      -- Suppress early-weapon XL window (shortbow at XL 1 would otherwise fire "Ranged weapon"
      -- from get_early_weapon_alert before get_first_of_skill_alert is reached).
      local orig_early_xl        = f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl
      local orig_early_ranged_xl = f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl       = 0
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = 0

      -- Pre-fill pa_high_score so update_high_scores() returns nil (no "Highest damage" alert).
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      -- Restore weapon_sensitivity to 1.0 (Testing config sets it to 0.5).
      local orig_sensitivity = f_pickup_alert.Config.Alert.weapon_sensitivity
      f_pickup_alert.Config.Alert.weapon_sensitivity = 1.0

      -- Ensure pa_lowest_hands_alerted["Ranged Weapons"] is at its default (3) so 3 > 1 fires.
      local orig_ranged_threshold = pa_lowest_hands_alerted["Ranged Weapons"]
      pa_lowest_hands_alerted["Ranged Weapons"] = 3

      -- ── Test A: shortbow should trigger "First Ranged Weapon (1-handed)" alert ──────────────
      f_pa_data.forget_alert(floor_weap)  -- clear any deduplication
      local result_a = f_pa_weapons.alert_weapon(floor_weap)
      T.true_(result_a ~= nil and result_a ~= false, "first-of-skill-alert-fires")

      -- ── Test B: set threshold to 0 so 0 > 1 is false -> alert suppressed ────────────────────
      f_pa_data.forget_alert(floor_weap)
      -- Also reset pa_lowest_hands_alerted back to 3 in case Test A updated it to 1
      pa_lowest_hands_alerted["Ranged Weapons"] = 0  -- 0 > 1 is false -> no alert

      local result_b = f_pa_weapons.alert_weapon(floor_weap)
      T.false_(result_b, "first-of-skill-no-alert-when-threshold-999")

      -- ── Restore all settings ──────────────────────────────────────────────────────────────
      pa_lowest_hands_alerted["Ranged Weapons"]              = orig_ranged_threshold
      f_pickup_alert.Config.Alert.weapon_sensitivity         = orig_sensitivity
      pa_high_score.weapon                                   = orig_hs_weapon
      pa_high_score.plain_dmg                               = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl       = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-first-of-skill")
      T.done()
    end
  end)
end
