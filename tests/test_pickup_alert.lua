---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert
-- Wizard-gives a branded weapon and verifies that pickup-alert fires an alert message.
--
-- Phase flow (one ready() call per phase):
--   "give"   (turn 0): wizard-give + identify, then CMD_WAIT to advance to turn 1
--   "check"  (turn 1): BRC.autopickup on floor items queues the alert,
--                       then CMD_WAIT to advance to turn 2;
--                       turn 1's consume_queue fires AFTER this ready() returns,
--                       populating T.last_messages before turn 2's ready() fires.
--   "verify" (turn 2): assert T.messages_contain("flaming"), T.done
--
-- crawl.do_commands({"CMD_WAIT"}) returns synchronously to Lua (without triggering the
-- next ready() cycle). The next turn's ready() fires in the subsequent game loop iteration.
---------------------------------------------------------------------------------------------------

test_pickup_alert = {}
test_pickup_alert.BRC_FEATURE_NAME = "test-pickup-alert"

local _phase = "give"

function test_pickup_alert.ready()
  if T._done then return end

  T.run("pickup-alert", function()
    if _phase == "give" then
      -- Place item on floor and identify it.
      -- wizard_identify_all ensures it.is_identified = true so f_pickup_alert.autopickup
      -- does not skip it (guard: not it.is_identified and it.branded -> skip).
      T.wizard_give("short sword of flaming")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1; returns immediately

    elseif _phase == "check" then
      -- test_pickup_alert.ready() runs before f_pickup_alert.ready() (reverse alphabetical
      -- order: "test-pickup-alert" > "pickup-alert"). So pa_last_ready_turn is still 0
      -- here (set by f_pickup_alert.ready() on turn 0), while you.turns() = 1.
      -- 1 != 0 -> the alert guard in f_pickup_alert.autopickup passes.
      for _, it in ipairs(you.floor_items()) do
        BRC.autopickup(it)  -- -> f_pickup_alert.autopickup(it) -> queues alert
      end
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 2; returns immediately
      -- After this ready() returns, turn 1's consume_queue fires, flushing the
      -- queued alert into T.last_messages before turn 2's ready() fires.

    elseif _phase == "verify" then
      -- T.last_messages was populated by turn 1's consume_queue.
      T.true_(T.messages_contain("flaming"), "alert-fired")
      T.pass("pickup-alert")
      T.done()
    end
  end)
end
