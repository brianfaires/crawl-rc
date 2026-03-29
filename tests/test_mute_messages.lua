---------------------------------------------------------------------------------------------------
-- BRC feature test: mute-messages
-- Verifies that f_mute_messages loaded with sane Config defaults and message lists.
---------------------------------------------------------------------------------------------------

test_mute_messages = {}
test_mute_messages.BRC_FEATURE_NAME = "test-mute-messages"

function test_mute_messages.ready()
  if T._done then return end

  T.run("mute-messages", function()
    T.true_(f_mute_messages ~= nil, "module-exists")

    -- Default mute level
    T.eq(f_mute_messages.Config.mute_level, 2, "default-mute-level")

    -- explore_only and level [1] message lists should be non-empty
    T.true_(#f_mute_messages.Config.messages.explore_only > 0, "has-explore-only-messages")
    T.true_(#f_mute_messages.Config.messages[1] > 0, "has-level-1-messages")

    T.pass("mute-messages")
    T.done()
  end)
end
