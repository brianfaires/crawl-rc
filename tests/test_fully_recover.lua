---------------------------------------------------------------------------------------------------
-- BRC feature test: fully-recover
-- Verifies that f_fully_recover loaded with sane Config defaults.
---------------------------------------------------------------------------------------------------

test_fully_recover = {}
test_fully_recover.BRC_FEATURE_NAME = "test-fully-recover"

function test_fully_recover.ready()
  if T._done then return end

  T.run("fully-recover", function()
    T.true_(f_fully_recover ~= nil, "module-exists")
    T.eq(f_fully_recover.BRC_FEATURE_NAME, "fully-recover", "feature-name")
    T.true_(f_fully_recover.Config ~= nil, "has-config")

    T.pass("fully-recover")
    T.done()
  end)
end
