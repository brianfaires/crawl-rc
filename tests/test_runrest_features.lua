---------------------------------------------------------------------------------------------------
-- BRC feature test: runrest-features
-- Verifies that f_runrest_features loaded with sane Config defaults.
---------------------------------------------------------------------------------------------------

test_runrest_features = {}
test_runrest_features.BRC_FEATURE_NAME = "test-runrest-features"

function test_runrest_features.ready()
  if T._done then return end

  T.run("runrest-features", function()
    T.true_(f_runrest_features ~= nil, "module-exists")
    T.eq(f_runrest_features.BRC_FEATURE_NAME, "runrest-features", "feature-name")
    T.true_(f_runrest_features.Config ~= nil, "has-config")

    T.pass("runrest-features")
    T.done()
  end)
end
