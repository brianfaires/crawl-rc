---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options
-- Verifies that f_dynamic_options loaded with sane Config: XL-based force-mores defined,
-- and the module initialized without errors.
---------------------------------------------------------------------------------------------------

test_dynamic_options = {}
test_dynamic_options.BRC_FEATURE_NAME = "test-dynamic-options"

function test_dynamic_options.ready()
  if T._done then return end

  T.run("dynamic-options", function()
    T.true_(f_dynamic_options ~= nil, "module-exists")

    -- XL-based force-mores should be non-empty
    T.true_(#f_dynamic_options.Config.xl_force_mores > 0, "has-xl-force-mores")

    -- Each entry has a pattern and xl threshold
    local first = f_dynamic_options.Config.xl_force_mores[1]
    T.true_(type(first.pattern) == "string" and #first.pattern > 0, "entry-has-pattern")
    T.true_(type(first.xl) == "number" and first.xl > 0, "entry-has-xl")

    T.pass("dynamic-options")
    T.done()
  end)
end
