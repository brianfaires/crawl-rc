---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (OTA fires for artefact matching one_time list)
-- Verifies that alert_OTA fires "Found first" for an artefact item when its name matches
-- an entry in pa_OTA_items — and that this happens BEFORE the artefact weapon alert path.
--
-- "sword of Power" is a Long Blades unrand (auto-identified via wizard_give).
-- find_OTA uses it.name("qual"):find(v) — injecting "sword of Power" into pa_OTA_items makes it
-- match. With skill gate bypassed (Long Blades = 0 on default char), OTA fires "Found first".
--
-- The second assertion (artefact path would have fired otherwise) is verified by calling
-- f_pa_weapons.alert_weapon after OTA consumed + alert forgotten — it fires "Artefact weapon".
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "sword of Power" (auto-identified) → CMD_WAIT
--   "verify" (turn 1): inject OTA entry, call alert_OTA → assert "Found first";
--                      forget alert, call alert_weapon → assert "Artefact weapon"; T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_ota_artefact = {}
test_pickup_alert_ota_artefact.BRC_FEATURE_NAME = "test-pickup-alert-ota-artefact"

local _phase = "give"

function test_pickup_alert_ota_artefact.ready()
  if T._done then return end

  T.run("pickup-alert-ota-artefact", function()
    if _phase == "give" then
      T.wizard_give("sword of Power")
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Find sword of Power on floor
      local floor_weap = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.artefact then
          floor_weap = it
          break
        end
      end
      T.true_(floor_weap ~= nil, "sword-of-power-on-floor")
      T.true_(floor_weap ~= nil and floor_weap.artefact, "floor-weapon-is-artefact")
      if not floor_weap then T.done() return end

      local A = f_pickup_alert.Config.Alert
      local M = A.More

      -- Inject artefact name into OTA list so find_OTA matches it
      local qual_name = floor_weap.name("qual")
      T.true_(qual_name ~= nil and #qual_name > 0, "artefact-has-qual-name")
      local orig_OTA_items = {}
      for i, v in ipairs(pa_OTA_items) do orig_OTA_items[i] = v end
      pa_OTA_items[#pa_OTA_items + 1] = qual_name

      -- Bypass skill gate (Long Blades = 0 on default char) and force_more
      local orig_skill_weap     = A.OTA_require_skill.weapon
      local orig_fm_ota         = M.one_time_alerts
      local orig_fm_artefact    = M.artefact
      local orig_fm_trained     = M.trained_artefacts
      A.OTA_require_skill.weapon = 0
      M.one_time_alerts          = false
      M.artefact                 = false
      M.trained_artefacts        = false

      -- Assert: OTA fires "Found first" for the artefact
      local ota_result = f_pa_misc.alert_OTA(floor_weap)
      T.true_(ota_result ~= nil and ota_result ~= false, "ota-fires-for-artefact")

      -- Restore all settings
      A.OTA_require_skill.weapon = orig_skill_weap
      M.one_time_alerts          = orig_fm_ota
      M.artefact                 = orig_fm_artefact
      M.trained_artefacts        = orig_fm_trained

      -- Restore pa_OTA_items (OTA was consumed by alert_OTA → remove_OTA)
      for i = #pa_OTA_items, 1, -1 do pa_OTA_items[i] = nil end
      for i, v in ipairs(orig_OTA_items) do pa_OTA_items[i] = v end

      -- Assert: without OTA, the artefact weapon path fires "Artefact weapon"
      f_pa_data.forget_alert(floor_weap)
      M.artefact         = false
      M.trained_artefacts = false
      local wpn_result = f_pa_weapons.alert_weapon(floor_weap)
      M.artefact         = orig_fm_artefact
      M.trained_artefacts = orig_fm_trained
      T.true_(wpn_result ~= nil and wpn_result ~= false, "artefact-weapon-alert-fires-without-ota")

      T.pass("pickup-alert-ota-artefact")
      T.done()
    end
  end)
end
