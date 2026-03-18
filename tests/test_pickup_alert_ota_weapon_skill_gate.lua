---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (OTA weapon skill gate — blocks when skill < threshold)
-- Verifies that alert_OTA returns nil for a weapon in the one_time list when the player's
-- skill in that weapon school is below OTA_require_skill.weapon (= 2).
--
-- "demon blade" is in Config.Alert.one_time (Long Blades).
-- Default Mummy Berserker has Long Blades skill 0 < 2 → OTA must not fire.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "demon blade" + identify → CMD_WAIT
--   "verify" (turn 1): assert skill precondition, call alert_OTA directly, assert no alert
---------------------------------------------------------------------------------------------------

test_pickup_alert_ota_weapon_skill_gate = {}
test_pickup_alert_ota_weapon_skill_gate.BRC_FEATURE_NAME = "test-pickup-alert-ota-weapon-skill-gate"

local _phase = "give"

function test_pickup_alert_ota_weapon_skill_gate.ready()
  if T._done then return end

  T.run("pickup-alert-ota-weapon-skill-gate", function()
    if _phase == "give" then
      T.wizard_give("demon blade")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      local A = f_pickup_alert.Config.Alert

      -- Explicit precondition: skill must be below threshold
      local lb_skill = you.skill("Long Blades")
      T.true_(lb_skill < A.OTA_require_skill.weapon, "long-blades-skill-below-ota-threshold")

      -- Find the demon blade
      local floor_blade = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("demon blade") then
          floor_blade = it
          break
        end
      end
      T.true_(floor_blade ~= nil, "demon-blade-on-floor")

      if floor_blade then
        local result = f_pa_misc.alert_OTA(floor_blade)
        T.true_(result == nil or result == false, "ota-weapon-skill-gate-blocks")
      end

      T.pass("pickup-alert-ota-weapon-skill-gate")
      T.done()
    end
  end)
end
