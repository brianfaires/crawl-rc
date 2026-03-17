---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (artefact weapon alert)
-- Verifies that an identified artefact weapon fires the "Artefact weapon" alert.
--
-- Character: Mummy Berserker, starts with a mace (Maces & Flails).
--
-- Item: "sword of Power" (unrand long sword, Long Blades skill).
-- Using a different weapon school than the starting mace ensures is_weapon_upgrade()
-- returns false for the strict check, so the code falls through to:
--   get_upgrade_alert(it, cur): if it.artefact then return make_alert(it, "Artefact weapon", ...)
--
-- Alert path:
--   f_pa_weapons.alert_weapon(it)
--     -> get_weapon_alert(it)
--     -> get_inventory_upgrade_alert(it)
--     -> get_upgrade_alert(sword_of_power, starting_mace, ...)
--        weapons_pure_upgrades_only=true, but is_weapon_upgrade(cross-skill, false) = false
--        -> it.artefact = true -> make_alert("Artefact weapon")
--
-- BRC.mpr.que_optmore queues messages; consume_queue() runs AFTER all ready() hooks.
-- So the "check" phase calls the alert (queues message) + CMD_WAIT, then
-- "verify" phase checks T.last_messages (captured after consume_queue fires).
--
-- Force_more: M.artefact=false; M.trained_artefacts disabled in check phase.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "sword of Power" (auto-identified) + CMD_WAIT -> turn 1
--   "check"  (turn 1): call f_pa_weapons.alert_weapon directly + CMD_WAIT -> turn 2
--   "verify" (turn 2): assert T.last_messages contains "Artefact weapon"
---------------------------------------------------------------------------------------------------

test_pickup_alert_artefact_weapon = {}
test_pickup_alert_artefact_weapon.BRC_FEATURE_NAME = "test-pickup-alert-artefact-weapon"

local _phase = "give"
local _floor_weap = nil

function test_pickup_alert_artefact_weapon.ready()
  if T._done then return end

  T.run("pickup-alert-artefact-weapon", function()

    -- ── Phase 1: place sword of Power on the floor ─────────────────────────────────────────
    if _phase == "give" then
      -- wizard_create_spec_object_by_name calls id_floor_items() internally,
      -- so the item is automatically identified when placed.
      T.wizard_give("sword of Power")
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    -- ── Phase 2: call the alert function (queues message) ──────────────────────────────────
    elseif _phase == "check" then

      -- Find sword of Power on the floor
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.artefact then
          _floor_weap = it
          break
        end
      end
      T.true_(_floor_weap ~= nil, "sword-of-power-on-floor")
      if not _floor_weap then T.done() return end

      T.true_(_floor_weap.artefact, "sword-of-power-is-artefact")
      T.true_(_floor_weap.is_identified, "sword-of-power-is-identified")

      -- Suppress artefact force_more to prevent headless hang
      local M = f_pickup_alert.Config.Alert.More
      local orig_artefact          = M.artefact
      local orig_trained_artefacts = M.trained_artefacts
      M.artefact          = false
      M.trained_artefacts = false

      -- Forget prior alert record so already_alerted() doesn't short-circuit
      f_pa_data.forget_alert(_floor_weap)

      -- Call the weapon alert function — queues "Artefact weapon" message
      local result = f_pa_weapons.alert_weapon(_floor_weap)

      M.artefact          = orig_artefact
      M.trained_artefacts = orig_trained_artefacts

      T.true_(result ~= nil and result ~= false, "artefact-weapon-alert-fires")

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- consume_queue() fires during BRC.ready() this turn

    -- ── Phase 3: verify message was output ─────────────────────────────────────────────────
    elseif _phase == "verify" then
      T.true_(T.messages_contain("Artefact weapon"), "artefact-weapon-message")
      T.pass("pickup-alert-artefact-weapon")
      T.done()
    end
  end)
end
