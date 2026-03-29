---------------------------------------------------------------------------------------------------
-- BRC feature test: misc-alerts low-HP alert
-- Exercises the alert_low_hp() hysteresis path in f_misc_alerts.
--
-- The hysteresis flag `below_hp_threshold` (a file-local upvalue) has this contract:
--   - When HP first drops to/below the threshold, the alert fires and below_hp_threshold = true.
--   - While below_hp_threshold == true the alert does NOT fire again. Instead, on each
--     subsequent ready(): below_hp_threshold = (hp ~= mhp).
--   - The flag resets to false only when HP == max HP (hp ~= mhp becomes false).
--   - Once reset, the alert can fire again on the next sub-threshold ready() call.
--
-- Bug risk: the reset condition is `hp ~= mhp`, not "above threshold". A character who heals to
-- just above the threshold (but not to full HP) stays silently stuck with below_hp_threshold ==
-- true indefinitely — no re-alert fires on a later dip below the threshold. This untested
-- asymmetry is the motivation for this test.
--
-- What this test verifies (threshold set to 100% so full HP triggers the condition):
--   1. Positive case: alert fires when alert_low_hp_threshold is 100% and HP == max HP.
--   2. Re-arm path: after the first fire, below_hp_threshold is reset on the next ready() call
--      (because hp == mhp → hp ~= mhp is false). A subsequent ready() fires the alert again.
--      A second occurrence of the alert message in T.last_messages confirms the re-arm worked.
--
-- Phase flow:
--   "setup"   (turn 0): Set threshold = 100. f_misc_alerts.ready() fires after our ready()
--                       returns (reverse-alpha hook order). Alert is queued, consume_queue
--                       populates T.last_messages after CMD_WAIT. Snapshot count_after_turn0.
--   "verify1" (turn 1): Confirm first alert appears. Snapshot count for this phase.
--                       CMD_WAIT advances to turn 2 (below_hp_threshold resets this cycle;
--                       second alert fires on turn 2).
--   "verify2" (turn 2): Confirm total occurrence count increased, proving re-arm path.
--
-- Hook order (reverse alpha by Lua variable name):
--   test_misc_alerts_low_hp ("t...") is registered after f_misc_alerts ("f..."),
--   so it runs FIRST in the reverse-order dispatch. Our setup is visible when
--   f_misc_alerts.ready() fires in the same cycle.
---------------------------------------------------------------------------------------------------

test_misc_alerts_low_hp = {}
test_misc_alerts_low_hp.BRC_FEATURE_NAME = "test-misc-alerts-low-hp"

local _phase = "setup"
local _orig_threshold
local _count_at_verify1 = 0

local function count_low_hp_messages()
  local n = 0
  for _, msg in ipairs(T.last_messages) do
    if string.find(msg.text, "Dropped below 100%%") then n = n + 1 end
  end
  return n
end

function test_misc_alerts_low_hp.ready()
  if T._done then return end

  T.run("misc-alerts-low-hp", function()

    if _phase == "setup" then
      -- Confirm module loaded with documented default
      T.true_(f_misc_alerts ~= nil, "module-exists")
      T.eq(f_misc_alerts.Config.alert_low_hp_threshold, 35, "default-threshold-is-35")

      -- Set threshold to 100% so the condition triggers at full HP:
      --   hp <= mhp * 100/100 → hp <= mhp → true when hp == mhp.
      -- f_misc_alerts.ready() will run after our ready() in the same cycle and queue the alert.
      _orig_threshold = f_misc_alerts.Config.alert_low_hp_threshold
      f_misc_alerts.Config.alert_low_hp_threshold = 100

      -- consume_queue fires after CMD_WAIT, putting the message into T.last_messages.
      _phase = "verify1"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify1" then
      -- At least one "Dropped below 100%" message should now be in T.last_messages.
      T.true_(T.messages_contain("Dropped below 100%%"), "alert-fired-first-time")

      -- Snapshot the current count before advancing. We need to confirm the count grows
      -- by at least one more after the re-arm cycle (turn 1 resets, turn 2 re-fires).
      _count_at_verify1 = count_low_hp_messages()
      T.true_(_count_at_verify1 >= 1, "count-at-verify1-at-least-1")

      -- Advance to verify2. below_hp_threshold resets during the cycles between here and
      -- verify2 (hp == mhp → hp ~= mhp is false), then fires again.
      _phase = "verify2"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify2" then
      -- T.last_messages has accumulated additional turns. The re-arm cycle should have
      -- produced at least one more "Dropped below 100%" message than at verify1.
      local count_now = count_low_hp_messages()
      T.true_(count_now > _count_at_verify1, "alert-refired-after-full-hp-reset")

      -- Restore original threshold.
      f_misc_alerts.Config.alert_low_hp_threshold = _orig_threshold

      T.pass("misc-alerts-low-hp")
      T.done()
    end

  end)
end
