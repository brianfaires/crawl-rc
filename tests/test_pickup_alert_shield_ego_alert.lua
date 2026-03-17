---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (artefact shield alert)
-- Verifies that an identified artefact shield fires the "Artefact shield" alert via
-- the fast-path in alert_shield() that does NOT require an equipped shield:
--   if it.artefact then
--     return f_pickup_alert.do_alert(it, "Artefact shield", E.ARTEFACT, M.shields)
--   end
--
-- Item: "shield of Resistance" (unrand artefact kite shield).
-- This path fires before the equipped-shield check, so no shield needs to be worn.
--
-- Character: Mummy Berserker (default — no shield equipped at game start).
--
-- Force_more suppression: M.shields=true by default; also M.artefact, M.trained_artefacts,
-- and M.armour_ego must all be false to prevent crawl.more() blocking the headless run.
-- has_configured_force_more() checks M.artefact, M.trained_artefacts, and M.armour_ego;
-- do_alert() also passes M.shields directly as force_more for shield alerts.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "shield of Resistance" (auto-identified) + CMD_WAIT -> turn 1
--   "check"  (turn 1): call f_pa_armour.alert_armour directly (queues message) + CMD_WAIT -> turn 2
--   "verify" (turn 2): assert T.last_messages contains "Artefact shield"
---------------------------------------------------------------------------------------------------

test_pickup_alert_shield_ego_alert = {}
test_pickup_alert_shield_ego_alert.BRC_FEATURE_NAME = "test-pickup-alert-shield-ego-alert"

local _phase = "give"
local _floor_shield = nil

function test_pickup_alert_shield_ego_alert.ready()
  if T._done then return end

  T.run("pickup-alert-shield-ego-alert", function()

    -- ── Phase 1: place shield of Resistance on the floor ────────────────────────────────────
    if _phase == "give" then
      -- wizard_give calls wizard_create_spec_object_by_name, which auto-identifies the item.
      T.wizard_give("shield of Resistance")
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    -- ── Phase 2: call the alert function (queues message) ───────────────────────────────────
    elseif _phase == "check" then

      -- Find the artefact shield on the floor
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_shield(it) and it.artefact then
          _floor_shield = it
          break
        end
      end
      T.true_(_floor_shield ~= nil, "artefact-shield-on-floor")
      if not _floor_shield then T.done() return end

      T.true_(_floor_shield.artefact,       "floor-shield-is-artefact")
      T.true_(_floor_shield.is_identified,  "floor-shield-is-identified")

      -- Suppress force_more flags to prevent headless hang.
      -- M.shields: passed directly as force_more arg to do_alert() in alert_shield().
      -- M.artefact / M.trained_artefacts: checked by has_configured_force_more().
      -- M.armour_ego: has_configured_force_more() checks this last; shield of Resistance has ego.
      local M = f_pickup_alert.Config.Alert.More
      local orig_shields           = M.shields
      local orig_artefact          = M.artefact
      local orig_trained_artefacts = M.trained_artefacts
      local orig_armour_ego        = M.armour_ego
      M.shields           = false
      M.artefact          = false
      M.trained_artefacts = false
      M.armour_ego        = false

      -- Forget any prior alert record so already_alerted() doesn't short-circuit
      f_pa_data.forget_alert(_floor_shield)

      -- alert_armour routes to alert_shield for shields; artefact path fires without equipped shield
      local result = f_pa_armour.alert_armour(_floor_shield)

      -- Restore flags before CMD_WAIT
      M.shields           = orig_shields
      M.artefact          = orig_artefact
      M.trained_artefacts = orig_trained_artefacts
      M.armour_ego        = orig_armour_ego

      T.true_(result ~= nil and result ~= false, "artefact-shield-alert-fires")

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- consume_queue() fires during BRC.ready() this turn

    -- ── Phase 3: verify message was output ──────────────────────────────────────────────────
    elseif _phase == "verify" then
      T.true_(T.messages_contain("Artefact shield"), "artefact-shield-message")
      T.pass("pickup-alert-shield-ego-alert")
      T.done()
    end
  end)
end
