-- @species Ds
-- @background Be
-- @weapon mace
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Demonspawn holy wrath ego — no alert for undead)
-- Verifies that f_pa_weapons.alert_weapon() returns nil/false for a holy wrath weapon when the
-- character is Demonspawn, because BRC.eq.is_useless_ego("holy") returns true for undead races.
--
-- BRC.UNDEAD_RACES = { "Demonspawn", "Mummy", "Poltergeist", "Revenant" }
-- is_useless_ego checks: ego == "holy" and util.contains(BRC.UNDEAD_RACES, race)
-- get_ego() lowercases the ego string before calling is_useless_ego: it.ego(true) returns "Holy",
-- lowercased = "holy", so is_useless_ego("holy") returns true and get_ego() returns nil.
--
-- The floor weapon is given plus:0 so it has the same DPS as the starting +0 mace in inventory.
-- This prevents a "Weapon upgrade" alert from the score-comparison path in
-- check_upgrade_same_subtype (which fires when floor score > inventory score). With both weapons
-- at +0, the scores are equal and only the ego path could fire — but since get_ego() returns nil
-- for a useless ego, no ego alert fires either.
--
-- Assertions:
--   1. BRC.eq.is_useless_ego("holy") is true for Demonspawn (direct unit test)
--   2. alert_weapon() on a +0 mace of holy wrath returns nil/false (no pickup alert fired)
--
-- Phase flow:
--   "give"   (turn 0): wizard-give +0 holy wrath mace, identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): direct is_useless_ego assertion, find floor weapon,
--                      suppress all force_more and early/high-score paths,
--                      call alert_weapon, assert no alert
---------------------------------------------------------------------------------------------------

test_pickup_alert_demonspawn_holy = {}
test_pickup_alert_demonspawn_holy.BRC_FEATURE_NAME = "test-pickup-alert-demonspawn-holy"

local _phase = "give"

function test_pickup_alert_demonspawn_holy.ready()
  if T._done then return end

  T.run("pickup-alert-demonspawn-holy", function()

    if _phase == "give" then
      -- plus:0 matches the starting inventory mace; equal scores prevent "Weapon upgrade" alert
      T.wizard_give("mace ego:holy_wrath plus:0")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.eq(you.race(), "Demonspawn", "char-is-demonspawn")

      -- Direct unit assertion: holy is useless for Demonspawn
      T.true_(BRC.eq.is_useless_ego("holy"), "demonspawn-holy-is-useless")

      -- Find the holy wrath mace on the floor
      local floor_weapon = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name():lower():find("holy") then
          floor_weapon = it
          break
        end
      end
      T.true_(floor_weapon ~= nil, "holy-wrath-mace-on-floor")
      if not floor_weapon then T.done() return end

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

      -- Suppress early-weapon window (XL 1 <= Early.xl=7 would fire before the ego check)
      local orig_early_xl        = f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl
      local orig_early_ranged_xl = f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl       = 0
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = 0

      -- Pre-fill pa_high_score so the floor weapon never triggers a high-score alert
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      -- Core assertion: holy wrath is useless for Demonspawn -> no alert
      -- get_ego() returns nil for this weapon; equal +0 scores mean no "Weapon upgrade" fires
      local result = f_pa_weapons.alert_weapon(floor_weapon)
      T.false_(result, "no-alert-for-demonspawn-holy-wrath")

      -- Restore all settings
      pa_high_score.weapon                                      = orig_hs_weapon
      pa_high_score.plain_dmg                                   = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl          = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl    = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-demonspawn-holy")
      T.done()
    end
  end)
end
