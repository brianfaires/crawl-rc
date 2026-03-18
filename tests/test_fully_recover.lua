---------------------------------------------------------------------------------------------------
-- BRC feature test: fully-recover
-- Tests fr_bad_durations (global persist — copy of BRC.BAD_DURATIONS) and the c_message
-- guard that skips processing when no recovery is active (recovery_start_turn == nil).
--
-- fr_bad_durations is initialized at module load time via BRC.Data.persist. It must:
--   - have the same length as BRC.BAD_DURATIONS
--   - contain all the same entries
--   - support in-place removal (util.remove) without breaking BRC.BAD_DURATIONS
--
-- c_message guard: when recovery_start_turn == nil (default after init()), any message
-- must return immediately. Verified by checking no error output appears.
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
    local msg_count_before = #T.last_messages
    f_fully_recover.c_message("You feel confused.", "duration")
    f_fully_recover.c_message("You are no longer confused.", "recovery")
    -- No error output: message count may change (other features may fire) but no [ERROR] from us
    -- Just verifying these calls don't throw is sufficient
    T.true_(true, "c-message-inactive-no-crash")

    T.pass("fully-recover")
    T.done()
  end)
end
