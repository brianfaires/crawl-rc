---------------------------------------------------------------------------------------------------
-- BRC feature test: drop-inferior
-- Verifies that f_drop_inferior loaded with sane Config defaults.
---------------------------------------------------------------------------------------------------

test_drop_inferior = {}
test_drop_inferior.BRC_FEATURE_NAME = "test-drop-inferior"

function test_drop_inferior.ready()
  if T._done then return end

  T.run("drop-inferior", function()
    T.true_(f_drop_inferior ~= nil, "module-exists")
    T.eq(f_drop_inferior.BRC_FEATURE_NAME, "drop-inferior", "feature-name")
    T.true_(f_drop_inferior.Config ~= nil, "has-config")

    T.pass("drop-inferior")
    T.done()
  end)
end
