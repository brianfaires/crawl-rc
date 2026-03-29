---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (artefact body armour alert)
-- Verifies that an identified artefact body armour fires the "Artefact armour" alert.
--
-- Character: Mummy Berserker, starts wearing a plain robe (body armour slot occupied).
--
-- Item: "robe of Night" (unrand artefact robe).
-- Since the character wears a plain robe, alert_body_armour() finds cur (equipped armour),
-- then hits the first artefact check:
--   if it.artefact then return send_armour_alert(it, ARMOUR_ALERT.artefact) end
--   -> send_armour_alert -> f_pickup_alert.do_alert(it, "Artefact armour", ...)
--
-- BRC.mpr.que_optmore queues messages; consume_queue() runs AFTER all ready() hooks.
-- So the "check" phase calls the alert (queues message) + CMD_WAIT, then
-- "verify" phase checks T.last_messages (captured after consume_queue fires).
--
-- Force_more suppression: M.artefact, M.trained_artefacts, M.body_armour, AND M.armour_ego
-- must all be set to false. has_configured_force_more() checks M.armour_ego last:
--   return M.armour_ego and BRC.it.is_armour(it) and BRC.eq.get_ego(it)
-- The robe of Night has an ego, so without M.armour_ego=false the message is queued with
-- more=true, consume_queue calls crawl.more(), which consumes the pending CMD_WAIT and
-- prevents the verify phase from running.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "robe of Night" (auto-identified) + CMD_WAIT -> turn 1
--   "check"  (turn 1): call f_pa_armour.alert_armour directly + CMD_WAIT -> turn 2
--   "verify" (turn 2): assert T.last_messages contains "Artefact armour"
---------------------------------------------------------------------------------------------------

test_pickup_alert_artefact_armour = {}
test_pickup_alert_artefact_armour.BRC_FEATURE_NAME = "test-pickup-alert-artefact-armour"

local _phase = "give"
local _floor_armour = nil

function test_pickup_alert_artefact_armour.ready()
  if T._done then return end

  T.run("pickup-alert-artefact-armour", function()

    -- ── Phase 1: place robe of Night on the floor ───────────────────────────────────────────
    if _phase == "give" then
      -- wizard_create_spec_object_by_name calls id_floor_items() internally,
      -- so the item is automatically identified when placed.
      T.wizard_give("robe of Night")
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    -- ── Phase 2: call the alert function (queues message) ──────────────────────────────────
    elseif _phase == "check" then

      -- Find the artefact body armour on the floor
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and it.artefact then
          _floor_armour = it
          break
        end
      end
      T.true_(_floor_armour ~= nil, "artefact-armour-on-floor")
      if not _floor_armour then T.done() return end

      T.true_(_floor_armour.artefact, "floor-armour-is-artefact")
      T.true_(_floor_armour.is_identified, "floor-armour-is-identified")

      -- Suppress force_more to prevent headless hang.
      -- Must suppress M.armour_ego: has_configured_force_more() checks it last and the
      -- robe of Night has an ego, which would otherwise queue the message with more=true.
      local M = f_pickup_alert.Config.Alert.More
      local orig_artefact          = M.artefact
      local orig_trained_artefacts = M.trained_artefacts
      local orig_body_armour       = M.body_armour
      local orig_armour_ego        = M.armour_ego
      M.artefact          = false
      M.trained_artefacts = false
      M.body_armour       = false
      M.armour_ego        = false

      -- Forget prior alert record
      f_pa_data.forget_alert(_floor_armour)

      -- Call the armour alert function — queues "Artefact armour" message
      local result = f_pa_armour.alert_armour(_floor_armour)

      M.artefact          = orig_artefact
      M.trained_artefacts = orig_trained_artefacts
      M.body_armour       = orig_body_armour
      M.armour_ego        = orig_armour_ego

      T.true_(result ~= nil and result ~= false, "artefact-armour-alert-fires")

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- consume_queue() fires during BRC.ready() this turn

    -- ── Phase 3: verify message was output ─────────────────────────────────────────────────
    elseif _phase == "verify" then
      T.true_(T.messages_contain("Artefact armour"), "artefact-armour-message")
      T.pass("pickup-alert-artefact-armour")
      T.done()
    end
  end)
end
