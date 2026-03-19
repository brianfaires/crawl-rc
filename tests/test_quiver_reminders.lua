---------------------------------------------------------------------------------------------------
-- BRC feature test: quiver-reminders
-- Tests c_message state tracking via exposed module fields (last_queued, last_thrown, etc.).
--
-- Scenarios tested:
--   1. "Throw: N <plurals>" → last_queued stripped and depluralized (e.g., "darts" → "dart")
--   2. "You throw ..." → last_thrown = last_queued, last_thrown_turn = last_queued_turn
--   3. "Throw: N <plurals> (<ego>)" → last_queued depluralized with ego preserved
--   4. Unrelated message → no state change
--
-- State is reset by direct field assignment (init() re-registers macros; avoid that side effect).
---------------------------------------------------------------------------------------------------

test_quiver_reminders = {}
test_quiver_reminders.BRC_FEATURE_NAME = "test-quiver-reminders"

function test_quiver_reminders.ready()
  if T._done then return end

  T.run("quiver-reminders", function()
    T.true_(f_quiver_reminders ~= nil, "module-exists")
    T.eq(f_quiver_reminders.BRC_FEATURE_NAME, "quiver-reminders", "feature-name")
    T.true_(f_quiver_reminders.Config ~= nil, "has-config")

    -- Test 1: "Throw: 5 darts" → last_queued = "dart", last_queued_turn = you.turns()
    f_quiver_reminders.last_queued = nil
    f_quiver_reminders.last_queued_turn = nil
    f_quiver_reminders.last_thrown = nil
    f_quiver_reminders.last_thrown_turn = nil
    f_quiver_reminders.c_message("Throw: 5 darts", "plain")
    T.eq(f_quiver_reminders.last_queued, "dart", "throw-sets-last-queued")
    T.eq(f_quiver_reminders.last_queued_turn, you.turns(), "throw-sets-queued-turn")

    -- Test 2: "You throw ..." → last_thrown promoted from last_queued
    f_quiver_reminders.c_message("You throw 5 darts.", "plain")
    T.eq(f_quiver_reminders.last_thrown, "dart", "you-throw-promotes-to-thrown")
    T.eq(f_quiver_reminders.last_thrown_turn, f_quiver_reminders.last_queued_turn, "thrown-turn-matches-queued-turn")

    -- Test 3: "Throw: 3 darts (curare)" → "dart (curare)" (pluralization before ego paren)
    f_quiver_reminders.last_queued = nil
    f_quiver_reminders.c_message("Throw: 3 darts (curare)", "plain")
    T.eq(f_quiver_reminders.last_queued, "dart (curare)", "throw-ego-depluralized")

    -- Test 4: unrelated message → no state change
    f_quiver_reminders.last_queued = nil
    f_quiver_reminders.c_message("You feel confused.", "plain")
    T.eq(f_quiver_reminders.last_queued, nil, "unrelated-message-no-change")

    T.pass("quiver-reminders")
    T.done()
  end)
end
