---------------------------------------------------------------------------------------------------
-- BRC feature test: fm-messages
-- Verifies that f_fm_messages loaded correctly with a non-empty message list and
-- sane threshold defaults.
---------------------------------------------------------------------------------------------------

test_fm_messages = {}
test_fm_messages.BRC_FEATURE_NAME = "test-fm-messages"

function test_fm_messages.ready()
  if T._done then return end

  T.run("fm-messages", function()
    T.true_(f_fm_messages ~= nil, "module-exists")

    -- Message list should be non-empty (feature provides many patterns)
    T.true_(#f_fm_messages.Config.messages > 0, "has-messages")

    -- Default thresholds are meaningful (not zero, not out of range)
    local fmt = f_fm_messages.Config.force_more_threshold
    T.true_(fmt >= 1 and fmt <= 10, "force-more-threshold-in-range")

    local fst = f_fm_messages.Config.flash_screen_threshold
    T.true_(fst >= 1 and fst <= 10, "flash-screen-threshold-in-range")

    T.pass("fm-messages")
    T.done()
  end)
end
