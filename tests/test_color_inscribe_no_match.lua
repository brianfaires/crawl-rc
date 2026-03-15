---------------------------------------------------------------------------------------------------
-- BRC feature test: color-inscribe (no-match case)
-- Verifies that colorize() leaves an inscription unchanged when none of the COLORIZE_TAGS
-- patterns match (e.g. a plain text note has no AC/EV/resistances to colorize).
---------------------------------------------------------------------------------------------------

test_color_inscribe_no_match = {}
test_color_inscribe_no_match.BRC_FEATURE_NAME = "test-color-inscribe-no-match"

function test_color_inscribe_no_match.ready()
  if T._done then return end

  T.run("color-inscribe-no-match", function()
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then weapon = it; break end
    end

    T.true_(weapon ~= nil, "has-weapon")
    if not weapon then T.done() return end

    -- Inscribe with text that matches no COLORIZE_TAGS pattern
    local original = "keep me"
    weapon.inscribe(original, false)

    -- After colorize, inscription must be unchanged
    f_color_inscribe.colorize(weapon)
    T.eq(weapon.inscription, original, "no-match-unchanged")

    T.pass("color-inscribe-no-match")
    T.done()
  end)
end
