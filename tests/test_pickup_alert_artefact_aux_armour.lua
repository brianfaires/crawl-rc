---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (artefact aux armour alert)
-- Verifies that an identified artefact aux armour fires the "Artefact aux armour" alert.
--
-- Character: Mummy Berserker, starts with no cloak equipped.
--
-- Item: "cloak of the Thief" (unrand artefact cloak).
-- Since a cloak is aux armour (not body armour, not shield), alert_armour routes to
-- alert_aux_armour(), where the first check is:
--   if it.artefact then return do_alert(it, "Artefact aux armour", ...)
--
-- BRC.mpr.que_optmore queues messages; consume_queue() runs AFTER all ready() hooks.
-- So the "check" phase calls the alert (queues message) + CMD_WAIT, then
-- "verify" phase checks T.last_messages (captured after consume_queue fires).
--
-- Force_more: M.aux_armour, M.artefact, M.trained_artefacts, M.armour_ego all set false.
-- M.armour_ego must be suppressed: has_configured_force_more() checks it last and the
-- cloak of the Thief has an ego, which would otherwise queue the message with more=true.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "cloak of the Thief" (auto-identified) + CMD_WAIT -> turn 1
--   "check"  (turn 1): call f_pa_armour.alert_armour directly + CMD_WAIT -> turn 2
--   "verify" (turn 2): assert T.last_messages contains "Artefact aux armour"
---------------------------------------------------------------------------------------------------

test_pickup_alert_artefact_aux_armour = {}
test_pickup_alert_artefact_aux_armour.BRC_FEATURE_NAME = "test-pickup-alert-artefact-aux-armour"

local _phase = "give"
local _floor_aux = nil

function test_pickup_alert_artefact_aux_armour.ready()
  if T._done then return end

  T.run("pickup-alert-artefact-aux-armour", function()

    -- ── Phase 1: place cloak of the Thief on the floor ─────────────────────────────────────
    if _phase == "give" then
      -- wizard_create_spec_object_by_name calls id_floor_items() internally,
      -- so the item is automatically identified when placed.
      T.wizard_give("cloak of the Thief")
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    -- ── Phase 2: call the alert function (queues message) ──────────────────────────────────
    elseif _phase == "check" then

      -- Find the artefact aux armour on the floor
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_armour(it) and it.artefact
            and not BRC.it.is_body_armour(it) and not BRC.it.is_shield(it) then
          _floor_aux = it
          break
        end
      end
      T.true_(_floor_aux ~= nil, "artefact-aux-armour-on-floor")
      if not _floor_aux then T.done() return end

      T.true_(_floor_aux.artefact, "floor-aux-is-artefact")
      T.true_(_floor_aux.is_identified, "floor-aux-is-identified")

      -- Suppress force_more to prevent headless hang.
      -- Must suppress M.armour_ego: has_configured_force_more() checks it last and the
      -- cloak of the Thief has an ego, which would otherwise queue the message with more=true,
      -- causing consume_queue to call crawl.more() and consume the pending CMD_WAIT.
      local M = f_pickup_alert.Config.Alert.More
      local orig_artefact          = M.artefact
      local orig_trained_artefacts = M.trained_artefacts
      local orig_aux_armour        = M.aux_armour
      local orig_armour_ego        = M.armour_ego
      M.artefact          = false
      M.trained_artefacts = false
      M.aux_armour        = false
      M.armour_ego        = false

      -- Forget prior alert record
      f_pa_data.forget_alert(_floor_aux)

      -- Call the armour alert function — queues "Artefact aux armour" message
      local result = f_pa_armour.alert_armour(_floor_aux)

      M.artefact          = orig_artefact
      M.trained_artefacts = orig_trained_artefacts
      M.aux_armour        = orig_aux_armour
      M.armour_ego        = orig_armour_ego

      T.true_(result ~= nil and result ~= false, "artefact-aux-armour-alert-fires")

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- consume_queue() fires during BRC.ready() this turn

    -- ── Phase 3: verify message was output ─────────────────────────────────────────────────
    elseif _phase == "verify" then
      T.true_(T.messages_contain("Artefact aux armour"), "artefact-aux-armour-message")
      T.pass("pickup-alert-artefact-aux-armour")
      T.done()
    end
  end)
end
