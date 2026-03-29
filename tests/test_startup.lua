---------------------------------------------------------------------------------------------------
-- test_startup: Smoke test — verifies BRC loads and initializes successfully.
-- This is the first test and the proof of concept for the testing framework.
---------------------------------------------------------------------------------------------------

test_startup = {}
test_startup.BRC_FEATURE_NAME = "test-startup"

function test_startup.ready()
  -- BRC.ready() sets BRC.active = true before calling feature hooks (even on turn 0),
  -- so we can run on the very first ready() call without waiting for a player turn.
  if T._done then return end

  -- T.run wraps logic in pcall so Lua errors produce [ERROR] lines instead of hanging crawl
  T.run("startup", function()

    -- BRC.active is true: BRC.ready() sets it before dispatching to feature hooks
    T.true_(BRC.active, "brc-active")

    -- Features table should exist and be non-empty
    local features = BRC.get_registered_features()
    T.true_(features ~= nil, "features-not-nil")

    local count = 0
    for _ in pairs(features) do count = count + 1 end
    T.true_(count > 0, "features-registered")

    -- Overall test pass
    T.pass("startup")
    T.done()

  end) -- T.run handles errors; caller must call T.done() on success path (done above)
end
