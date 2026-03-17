---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (pause_pa_system transitions)
-- Verifies that c_message correctly sets and clears pause_pa_system via the
-- "ou start " / "ou stop " / "ou finish " substrings in incoming messages.
--
-- f_pickup_alert.is_paused() reflects pause_pa_system OR hold_alerts_for_next_turn.
-- At turn 0, both are false. We drive transitions entirely with c_message calls.
--
-- Sub-test A: "You start removing your armour." sets pause; "You finish removing" clears it.
-- Sub-test B: "You start running." sets pause; "You stop running." clears it.
-- Sub-test C: Paused state is visible via is_paused() after a start message and before a stop.
--
-- No CMD_WAIT needed — all assertions are direct function calls at turn 0.
---------------------------------------------------------------------------------------------------

test_pickup_alert_pause_pa_system = {}
test_pickup_alert_pause_pa_system.BRC_FEATURE_NAME = "test-pickup-alert-pause-pa-system"

function test_pickup_alert_pause_pa_system.ready()
  if T._done then return end

  T.run("pickup-alert-pause-pa-system", function()

    -- ── Sub-test A: "ou start " sets pause; "ou finish " clears it ──────────────────────────
    -- Precondition: not paused at game start
    T.false_(f_pickup_alert.is_paused(), "starts-unpaused")

    f_pickup_alert.c_message("You start removing your armour.", "multiturn")
    T.true_(f_pickup_alert.is_paused(), "paused-after-start-removing")

    f_pickup_alert.c_message("You finish removing your armour.", "plain")
    T.false_(f_pickup_alert.is_paused(), "unpaused-after-finish-removing")

    -- ── Sub-test B: "ou start " + "ou stop " ────────────────────────────────────────────────
    f_pickup_alert.c_message("You start running.", "multiturn")
    T.true_(f_pickup_alert.is_paused(), "paused-after-start-running")

    f_pickup_alert.c_message("You stop running.", "plain")
    T.false_(f_pickup_alert.is_paused(), "unpaused-after-stop-running")

    -- ── Sub-test C: non-multiturn start message has no effect ───────────────────────────────
    -- The code only sets pause when channel == "multiturn"; a plain-channel message should not.
    f_pickup_alert.c_message("You start something.", "plain")
    T.false_(f_pickup_alert.is_paused(), "plain-start-message-no-effect")

    -- ── Sub-test D: stop/finish on non-plain channel has no effect ──────────────────────────
    -- First pause via multiturn, then send stop via multiturn — should stay paused.
    f_pickup_alert.c_message("You start equipping your armour.", "multiturn")
    T.true_(f_pickup_alert.is_paused(), "paused-before-wrong-channel-stop")
    f_pickup_alert.c_message("You stop equipping.", "multiturn")
    T.true_(f_pickup_alert.is_paused(), "still-paused-after-wrong-channel-stop")
    -- Clean up: send the real plain stop so we don't leave the system paused
    f_pickup_alert.c_message("You stop equipping.", "plain")
    T.false_(f_pickup_alert.is_paused(), "cleanup-unpaused")

    T.pass("pickup-alert-pause-pa-system")
    T.done()
  end)
end
