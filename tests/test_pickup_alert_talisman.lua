---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (talisman alert)
-- Verifies that alert_talisman() fires for a protean talisman with a Mummy Berserker.
--
-- Key logic in alert_talisman() (pa-misc.lua):
--   if not it.is_identified then return false end
--   if it.artefact then return do_alert(it, "Artefact talisman", ...) end
--   local required_skill = BRC.it.get_talisman_min_level(it) - A.talisman_lvl_diff
--   if required_skill > BRC.you.shapeshifting_skill() then return false end
--   return do_alert(it, "New talisman", ...)
--
-- protean talisman: get_talisman_min_level returns 6 (hardcoded).
-- talisman_lvl_diff = 6 for non-Shapeshifter → required_skill = 6 - 6 = 0.
-- Mummy Berserker shapeshifting_skill() = 0 → 0 <= 0 → alert fires.
--
-- M.talismans = false for non-Shapeshifter (pa-config.lua), so no force_more hangup.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("protean talisman") + identify → CMD_WAIT
--   "check"  (turn 1): forget_alert, call alert_talisman → queues message → CMD_WAIT
--   "verify" (turn 2): assert "New talisman" message was captured
---------------------------------------------------------------------------------------------------

test_pickup_alert_talisman = {}
test_pickup_alert_talisman.BRC_FEATURE_NAME = "test-pickup-alert-talisman"

local _phase = "give"

function test_pickup_alert_talisman.ready()
  if T._done then return end

  T.run("pickup-alert-talisman", function()
    if _phase == "give" then
      T.wizard_give("protean talisman")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Find the protean talisman on the floor
      local talisman = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_talisman(it) then
          talisman = it
          break
        end
      end

      T.true_(talisman ~= nil, "talisman-on-floor")
      if not talisman then T.done() return end

      crawl.stderr("[INFO] talisman name=" .. tostring(talisman.name()))
      crawl.stderr("[INFO] talisman identified=" .. tostring(talisman.is_identified))

      -- Ensure the alert hasn't fired already (forget any prior alert record)
      f_pa_data.forget_alert(talisman)

      -- Call alert_talisman directly — it is a public function in f_pa_misc.
      -- M.talismans = false for non-Shapeshifter, so no force_more hangup in headless mode.
      -- do_alert() queues the message; BRC.mpr.consume_queue() fires it at end of ready().
      local result = f_pa_misc.alert_talisman(talisman)

      crawl.stderr("[INFO] alert_talisman result=" .. tostring(result))
      T.true_(result == true, "talisman-alert-fires")

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Message was queued on turn 1 and displayed by consume_queue() at end of that ready().
      -- T.c_message captured it. Check for the alert type string.
      T.true_(
        T.messages_contain("New talisman") or T.messages_contain("talisman"),
        "talisman-message-captured"
      )

      T.pass("pickup-alert-talisman")
      T.done()
    end
  end)
end
