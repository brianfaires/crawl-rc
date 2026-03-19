---------------------------------------------------------------------------------------------------
-- BRC feature test: fully-recover
-- Tests fr_bad_durations (global persist — copy of BRC.BAD_DURATIONS), the c_message
-- guard when recovery is inactive, and c_message channel behavior when active.
--
-- fr_bad_durations:
--   - same length as BRC.BAD_DURATIONS
--   - contains known entries
--   - copy isolation: removing from it must not affect BRC.BAD_DURATIONS
--
-- c_message with recovery_start_turn == nil → returns immediately (no crash)
-- c_message with recovery active + "duration" channel → recovery_start_turn preserved
-- c_message with recovery active + "warn" channel → recovery_start_turn cleared
---------------------------------------------------------------------------------------------------

test_fully_recover = {}
test_fully_recover.BRC_FEATURE_NAME = "test-fully-recover"

function test_fully_recover.ready()
  if T._done then return end

  T.run("fully-recover", function()
    T.true_(f_fully_recover ~= nil, "module-exists")

    -- fr_bad_durations is a copy of BRC.BAD_DURATIONS, same length
    T.eq(#fr_bad_durations, #BRC.BAD_DURATIONS, "bad-durations-same-length")

    -- Key entries present
    T.true_(util.contains(fr_bad_durations, "slowed"),   "has-slowed")
    T.true_(util.contains(fr_bad_durations, "confused"), "has-confused")
    T.true_(util.contains(fr_bad_durations, "berserk"),  "has-berserk")

    -- It is a COPY — modifying fr_bad_durations must not affect BRC.BAD_DURATIONS
    local orig_count = #fr_bad_durations
    util.remove(fr_bad_durations, "slowed")
    T.eq(#fr_bad_durations, orig_count - 1, "removal-shrinks-copy")
    T.true_(util.contains(BRC.BAD_DURATIONS, "slowed"), "original-unaffected")
    -- Restore
    table.insert(fr_bad_durations, "slowed")

    -- c_message with recovery inactive (recovery_start_turn == nil after init):
    -- must return without producing an error message.
    f_fully_recover.init()
    f_fully_recover.c_message("You feel confused.", "duration")
    f_fully_recover.c_message("You are no longer confused.", "recovery")
    T.true_(true, "c-message-inactive-no-crash")

    -- c_message with recovery active + duration channel: recovery_start_turn preserved
    f_fully_recover.init()
    f_fully_recover.recovery_start_turn = you.turns()
    f_fully_recover.c_message("You feel slow.", "duration")
    T.true_(f_fully_recover.recovery_start_turn ~= nil, "duration-channel-preserves-recovery")

    -- c_message with recovery active + warn channel: recovery_start_turn cleared
    f_fully_recover.init()
    f_fully_recover.recovery_start_turn = you.turns()
    f_fully_recover.c_message("Something scary happens.", "warn")
    T.eq(f_fully_recover.recovery_start_turn, nil, "warn-channel-clears-recovery")

    T.pass("fully-recover")
    T.done()
  end)
end
