---------------------------------------------------------------------------------------------------
-- BRC feature test: color-inscribe (tag output)
-- Verifies that colorize() actually wraps matched patterns in color tags (not just any change).
-- After colorizing "AC+2", the inscription must contain "<" indicating a color tag was inserted.
---------------------------------------------------------------------------------------------------

test_color_inscribe_tag_output = {}
test_color_inscribe_tag_output.BRC_FEATURE_NAME = "test-color-inscribe-tag-output"

function test_color_inscribe_tag_output.ready()
  if T._done then return end

  T.run("color-inscribe-tag-output", function()
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then weapon = it; break end
    end

    T.true_(weapon ~= nil, "has-weapon")
    if not weapon then T.done() return end

    weapon.inscribe("AC+2", false)
    f_color_inscribe.colorize(weapon)

    -- The inscription must now contain a color tag opener
    T.true_(weapon.inscription:find("<") ~= nil, "inscription-has-color-tag")

    T.pass("color-inscribe-tag-output")
    T.done()
  end)
end
