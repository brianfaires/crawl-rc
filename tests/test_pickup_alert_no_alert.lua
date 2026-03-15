---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (no alert for irrelevant weapon)
-- Verifies that BRC.autopickup does NOT fire a pickup alert for a plain dagger —
-- a weapon type irrelevant to a Mummy Berserker (Maces & Flails, not Short Blades).
--
-- Complements test_pickup_alert.lua which tests the positive case.
-- Phase flow mirrors test_pickup_alert.lua but asserts the alert does NOT appear.
---------------------------------------------------------------------------------------------------

test_pickup_alert_no_alert = {}
test_pickup_alert_no_alert.BRC_FEATURE_NAME = "test-pickup-alert-no-alert"

local _phase = "give"

function test_pickup_alert_no_alert.ready()
  if T._done then return end

  T.run("pickup-alert-no-alert", function()
    if _phase == "give" then
      T.wizard_give("dagger")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Clear messages accumulated before this phase
      T.last_messages = {}
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)
      end
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- A plain dagger is not a weapon upgrade for a Maces & Flails Berserker.
      -- No pickup alert should have fired.
      T.false_(T.messages_contain("dagger"), "no-alert-for-plain-dagger")
      T.pass("pickup-alert-no-alert")
      T.done()
    end
  end)
end
