---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (!u inscription suppresses upgrade alert)
-- Verifies that f_pa_weapons.alert_weapon() returns false/nil when the only
-- inventory weapon has a !u inscription, even if a clearly better weapon is on the floor.
--
-- Also verifies the inverse (sanity check): removing !u causes the alert to fire.
--
-- Character: Mummy Berserker with starting mace (seed 1).
---------------------------------------------------------------------------------------------------

test_pickup_alert_weapon_no_upgrade = {}
test_pickup_alert_weapon_no_upgrade.BRC_FEATURE_NAME = "test-pickup-alert-weapon-no-upgrade"

local _phase = "inscribe"

function test_pickup_alert_weapon_no_upgrade.ready()
  if T._done then return end

  T.run("pickup-alert-weapon-no-upgrade", function()
    if _phase == "inscribe" then
      local starting_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.subtype() == "mace" then
          starting_mace = it
          break
        end
      end
      T.true_(starting_mace ~= nil, "starting-mace-found-in-inscribe-phase")
      if not starting_mace then T.done() return end

      starting_mace.inscribe("!u", false)
      T.true_(starting_mace.inscription:contains("!u"), "mace-has-!u-after-inscribe")
      if not starting_mace.inscription:contains("!u") then T.done() return end

      _phase = "give"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "give" then
      T.wizard_give("mace plus:5")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Confirm starting mace still in inventory
      local starting_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.subtype() == "mace" and (it.plus or 0) < 5 then
          starting_mace = it
          break
        end
      end
      T.true_(starting_mace ~= nil, "starting-mace-found")
      if not starting_mace then T.done() return end
      T.true_(starting_mace.inscription:contains("!u"), "mace-still-has-!u")

      -- Find the +5 mace on the floor
      local floor_mace = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.subtype() == "mace" and (it.plus or 0) >= 5 then
          floor_mace = it
          break
        end
      end
      T.true_(floor_mace ~= nil, "plus5-mace-on-floor")
      if not floor_mace then T.done() return end

      -- Debug: What would get_weapon_alert return for the floor mace?
      crawl.stderr("DEBUG floor_mace.plus=" .. tostring(floor_mace.plus))
      crawl.stderr("DEBUG starting_mace.inscription='" .. starting_mace.inscription .. "'")
      crawl.stderr("DEBUG you.xl()=" .. tostring(you.xl()))

      -- Disable force_more for all weapon alert types
      local orig_upgrade = f_pickup_alert.Config.Alert.More.upgrade_weap
      local orig_early   = f_pickup_alert.Config.Alert.More.early_weap
      local orig_hs      = f_pickup_alert.Config.Alert.More.high_score_weap
      local orig_ego     = f_pickup_alert.Config.Alert.More.weap_ego
      f_pickup_alert.Config.Alert.More.upgrade_weap    = false
      f_pickup_alert.Config.Alert.More.early_weap      = false
      f_pickup_alert.Config.Alert.More.high_score_weap = false
      f_pickup_alert.Config.Alert.More.weap_ego        = false

      -- Also disable early weapon XL window so that path doesn't interfere.
      -- The character is XL 1, which is within the Early.xl=7 window.
      -- A +5 mace would trigger early weapon alert: it_plus(5) >= branded_min_plus/sens(4/1=4).
      -- Suppressing the early path ensures only the upgrade path fires.
      local orig_early_xl = f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl
      local orig_ranged_xl = f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl = 0
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = 0

      -- Also pre-set the high score so the +5 mace is not "highest damage"
      -- (pre-fill pa_high_score.weapon to a very high value so update_high_scores returns nil)
      local orig_hs_weapon = pa_high_score.weapon
      local orig_hs_plain = pa_high_score.plain_dmg
      pa_high_score.weapon = 999
      pa_high_score.plain_dmg = 999

      crawl.stderr("DEBUG: calling alert_weapon WITH !u ...")
      local result_with_u = f_pa_weapons.alert_weapon(floor_mace)
      crawl.stderr("DEBUG result_with_u=" .. tostring(result_with_u))
      T.false_(result_with_u, "no-upgrade-alert-with-!u")

      -- Restore high score and clear !u, then call again
      pa_high_score.weapon = orig_hs_weapon
      pa_high_score.plain_dmg = orig_hs_plain

      starting_mace.inscribe("", false)  -- clear !u
      crawl.stderr("DEBUG: calling alert_weapon WITHOUT !u ...")
      local result_without_u = f_pa_weapons.alert_weapon(floor_mace)
      crawl.stderr("DEBUG result_without_u=" .. tostring(result_without_u))
      T.true_(result_without_u ~= nil and result_without_u ~= false, "upgrade-alert-without-!u")

      -- Restore all settings
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = orig_ranged_xl
      f_pickup_alert.Config.Alert.More.upgrade_weap    = orig_upgrade
      f_pickup_alert.Config.Alert.More.early_weap      = orig_early
      f_pickup_alert.Config.Alert.More.high_score_weap = orig_hs
      f_pickup_alert.Config.Alert.More.weap_ego        = orig_ego

      T.pass("pickup-alert-weapon-no-upgrade")
      T.done()
    end
  end)
end
