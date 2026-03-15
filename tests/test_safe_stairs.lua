---------------------------------------------------------------------------------------------------
-- BRC feature test: safe-stairs
-- Verifies that f_safe_stairs loaded with sane Config defaults.
---------------------------------------------------------------------------------------------------

test_safe_stairs = {}
test_safe_stairs.BRC_FEATURE_NAME = "test-safe-stairs"

function test_safe_stairs.ready()
  if T._done then return end

  T.run("safe-stairs", function()
    T.true_(f_safe_stairs ~= nil, "module-exists")
    T.eq(f_safe_stairs.BRC_FEATURE_NAME, "safe-stairs", "feature-name")
    T.true_(f_safe_stairs.Config ~= nil, "has-config")

    T.pass("safe-stairs")
    T.done()
  end)
end
