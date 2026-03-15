---------------------------------------------------------------------------------------------------
-- BRC feature test: bread-swinger
-- Verifies that f_bread_swinger loaded and initialized without errors.
-- This is a smoke test — bread-swinger is the most complex feature and requires
-- combat/monster interaction to test fully.
---------------------------------------------------------------------------------------------------

test_bread_swinger = {}
test_bread_swinger.BRC_FEATURE_NAME = "test-bread-swinger"

function test_bread_swinger.ready()
  if T._done then return end

  T.run("bread-swinger", function()
    T.true_(f_bread_swinger ~= nil, "module-exists")
    T.eq(f_bread_swinger.BRC_FEATURE_NAME, "bread-swinger", "feature-name")
    T.true_(f_bread_swinger.Config ~= nil, "has-config")

    T.pass("bread-swinger")
    T.done()
  end)
end
