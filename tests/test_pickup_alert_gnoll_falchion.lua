-- @species Gn
-- @background Be
-- @weapon falchion
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Gnoll cross-skill UPGRADE_SKILL_FACTOR bypass)
-- Verifies f_pa_weapons.alert_weapon() fires an alert for a cross-skill floor weapon
-- (flaming mace vs starting falchion) for Gnoll, where the UPGRADE_SKILL_FACTOR gate at
-- pa-weapons.lua:65 is bypassed.
--
-- For non-Gnoll, is_upgradable_weapon() returns false at line 65 when the floor weapon's
-- skill is untrained: skill(M&F=0) >= 0.5 * skill(LongBlades=3) → 0 >= 1.5 → false.
-- Gnoll skips this gate, so the flaming mace reaches get_upgrade_alert() and the ego
-- comparison in check_upgrade_cross_subtype, where it fires "Gain ego".
--
-- gain_ego=0 makes the assertion config-independent (any non-zero ratio fires).
-- All other alert paths (early_weap, high_score) are suppressed to isolate the upgrade path.
--
-- Phase flow:
--   "give"   (turn 0): wizard-give flaming mace, identify, CMD_WAIT → turn 1
--   "verify" (turn 1): find floor mace, suppress other alerts, set gain_ego=0,
--                      call alert_weapon, assert fires, restore, T.pass, T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_gnoll_falchion = {}
test_pickup_alert_gnoll_falchion.BRC_FEATURE_NAME = "test-pickup-alert-gnoll-falchion"

local _phase = "give"

function test_pickup_alert_gnoll_falchion.ready()
  if T._done then return end

  T.run("pickup-alert-gnoll-falchion", function()

    if _phase == "give" then
      T.wizard_give("mace ego:flaming plus:3")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.eq(you.race(), "Gnoll", "char-is-gnoll")

      local floor_mace = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name():find("flaming") and it.subtype() == "mace" then
          floor_mace = it
          break
        end
      end
      T.true_(floor_mace ~= nil, "flaming-mace-on-floor")
      if not floor_mace then T.done() return end

      -- Disable force_more for all weapon alert types to prevent headless hang
      local M = f_pickup_alert.Config.Alert.More
      local orig_upgrade   = M.upgrade_weap
      local orig_early     = M.early_weap
      local orig_hs        = M.high_score_weap
      local orig_ego       = M.weap_ego
      M.upgrade_weap    = false
      M.early_weap      = false
      M.high_score_weap = false
      M.weap_ego        = false

      -- Suppress early-weapon window (XL 1 <= Early.xl=7 would fire before upgrade path)
      local orig_early_xl        = f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl
      local orig_early_ranged_xl = f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl       = 0
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = 0

      -- Pre-fill pa_high_score so the floor mace never triggers a high-score alert
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      -- Set gain_ego=0: any non-zero ego ratio fires (config-independent assertion)
      local W_Alert = f_pickup_alert.Config.Tuning.Weap.Alert
      local orig_gain_ego = W_Alert.gain_ego
      W_Alert.gain_ego = 0

      -- Core assertion: Gnoll bypasses UPGRADE_SKILL_FACTOR → cross-skill ego alert fires
      local result = f_pa_weapons.alert_weapon(floor_mace)
      T.true_(result ~= nil and result ~= false, "gnoll-cross-skill-upgrade-fires")

      -- Restore all settings
      W_Alert.gain_ego                                          = orig_gain_ego
      pa_high_score.weapon                                      = orig_hs_weapon
      pa_high_score.plain_dmg                                   = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl          = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl    = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-gnoll-falchion")
      T.done()
    end
  end)
end
