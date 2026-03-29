---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (staff alerts, Mummy species)
-- Verifies species-specific staff alert behavior.
--
-- f_pa_misc.alert_staff() checks player resistances before alerting:
--   staff of chemistry: returns false when you.res_poison() > 0
--   staff of fire:      returns false when you.res_fire() > 0
--
-- Mummies have rPois (in BRC.POIS_RES_RACES) but NOT rFire.
-- So:
--   - staff of chemistry: NO alert for Mummy (already has rPois)
--   - staff of fire:      alert DOES fire for Mummy (no rFire)
--
-- Phase flow for each sub-test:
--   "give"  : wizard_give + identify → CMD_WAIT
--   "check" : BRC.autopickup on floor → CMD_WAIT
--   "verify": check T.last_messages
---------------------------------------------------------------------------------------------------

test_pickup_alert_staff_mummy = {}
test_pickup_alert_staff_mummy.BRC_FEATURE_NAME = "test-pickup-alert-staff-mummy"

local _phase = "give_chemistry"

function test_pickup_alert_staff_mummy.ready()
  if T._done then return end

  T.run("pickup-alert-staff-mummy", function()
    if _phase == "give_chemistry" then
      T.wizard_give("staff of chemistry")
      T.wizard_identify_all()
      _phase = "check_chemistry"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check_chemistry" then
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)
      end
      T.last_messages = {}  -- clear before advancing, so only chemistry-related messages captured
      _phase = "verify_chemistry"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify_chemistry" then
      -- Mummy has rPois: staff of chemistry rPois alert must NOT fire
      T.true_(you.res_poison() > 0, "mummy-has-rpois-prereq")
      T.false_(T.messages_contain("chemistry"), "no-chemistry-alert-for-mummy")

      -- Now test staff of fire (Mummy has no rFire → alert should fire)
      T.wizard_give("staff of fire")
      T.wizard_identify_all()
      _phase = "check_fire"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check_fire" then
      T.last_messages = {}
      for _, it in ipairs(you.floor_items()) do
        if it.name("base") == "staff of fire" then
          BRC.autopickup(it)
        end
      end
      _phase = "verify_fire"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify_fire" then
      -- Mummy has no rFire: staff of fire rF+ alert SHOULD fire
      T.false_(you.res_fire() > 0, "mummy-no-rfire-prereq")
      T.true_(T.messages_contain("fire") or T.messages_contain("rF"), "fire-alert-for-mummy")

      T.pass("pickup-alert-staff-mummy")
      T.done()
    end
  end)
end
