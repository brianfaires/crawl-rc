---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (OTA armour skill gate — blocks when skill < threshold)
-- Verifies that alert_OTA returns nil for an armour item in the one_time list when the player's
-- Armour skill is below OTA_require_skill.armour (= 2.5).
--
-- "crystal plate armour" is in Config.Alert.one_time.
-- Default Mummy Berserker has Armour skill 0 < 2.5 → OTA must not fire.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "crystal plate armour" + identify → CMD_WAIT
--   "verify" (turn 1): assert skill precondition, call alert_OTA directly, assert no alert
---------------------------------------------------------------------------------------------------

test_pickup_alert_ota_armour_skill_gate = {}
test_pickup_alert_ota_armour_skill_gate.BRC_FEATURE_NAME = "test-pickup-alert-ota-armour-skill-gate"

local _phase = "give"

function test_pickup_alert_ota_armour_skill_gate.ready()
  if T._done then return end

  T.run("pickup-alert-ota-armour-skill-gate", function()
    if _phase == "give" then
      T.wizard_give("crystal plate armour")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      local A = f_pickup_alert.Config.Alert

      -- Explicit precondition: Armour skill must be below threshold
      local armour_skill = you.skill("Armour")
      T.true_(armour_skill < A.OTA_require_skill.armour, "armour-skill-below-ota-threshold")

      -- Find crystal plate on floor
      local floor_cpa = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_armour(it) and it.name("base"):find("crystal plate") then
          floor_cpa = it
          break
        end
      end
      T.true_(floor_cpa ~= nil, "crystal-plate-on-floor")

      if floor_cpa then
        local result = f_pa_misc.alert_OTA(floor_cpa)
        T.true_(result == nil or result == false, "ota-armour-skill-gate-blocks")
      end

      T.pass("pickup-alert-ota-armour-skill-gate")
      T.done()
    end
  end)
end
