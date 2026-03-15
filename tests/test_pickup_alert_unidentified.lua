---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (unidentified item skipped)
-- Verifies the is_identified guard: when a branded weapon is NOT identified,
-- f_pickup_alert.autopickup must skip it (no alert should fire).
--
-- Guard in f_pickup_alert.autopickup:
--   skip_it = not it.is_identified and (it.branded or it.artefact or ...)
--
-- Phase flow: give unidentified short sword of flaming → check → verify no message.
---------------------------------------------------------------------------------------------------

test_pickup_alert_unidentified = {}
test_pickup_alert_unidentified.BRC_FEATURE_NAME = "test-pickup-alert-unidentified"

local _phase = "give"

function test_pickup_alert_unidentified.ready()
  if T._done then return end

  T.run("pickup-alert-unidentified", function()
    if _phase == "give" then
      -- Give item WITHOUT calling wizard_identify_all → remains unidentified
      T.wizard_give("short sword of flaming")
      -- Deliberately no T.wizard_identify_all() here
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      T.last_messages = {}
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)
      end
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Item is branded but not identified → alert guard fires → no alert
      T.false_(T.messages_contain("flaming"), "no-alert-unidentified-brand")
      T.pass("pickup-alert-unidentified")
      T.done()
    end
  end)
end
