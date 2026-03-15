---------------------------------------------------------------------------------------------------
-- BRC feature test: exclude-dropped
-- Verifies that f_exclude_dropped loaded with sane Config defaults.
---------------------------------------------------------------------------------------------------

test_exclude_dropped = {}
test_exclude_dropped.BRC_FEATURE_NAME = "test-exclude-dropped"

function test_exclude_dropped.ready()
  if T._done then return end

  T.run("exclude-dropped", function()
    T.true_(f_exclude_dropped ~= nil, "module-exists")
    T.eq(f_exclude_dropped.BRC_FEATURE_NAME, "exclude-dropped", "feature-name")
    T.true_(f_exclude_dropped.Config ~= nil, "has-config")

    T.pass("exclude-dropped")
    T.done()
  end)
end
