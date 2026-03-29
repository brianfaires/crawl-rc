---------------------------------------------------------------------------------------------------
-- BRC feature test: go-up-macro
-- Verifies that f_go_up_macro loaded and initialized without errors.
---------------------------------------------------------------------------------------------------

test_go_up_macro = {}
test_go_up_macro.BRC_FEATURE_NAME = "test-go-up-macro"

function test_go_up_macro.ready()
  if T._done then return end

  T.run("go-up-macro", function()
    T.true_(f_go_up_macro ~= nil, "module-exists")
    T.eq(f_go_up_macro.BRC_FEATURE_NAME, "go-up-macro", "feature-name")

    T.pass("go-up-macro")
    T.done()
  end)
end
