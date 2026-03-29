---------------------------------------------------------------------------------------------------
-- BRC feature test: color-inscribe (idempotency)
-- Verifies that calling colorize() twice produces the same result as calling it once.
-- The colorize_subtext function strips existing color tags before re-adding them,
-- so repeated calls must not double-wrap or corrupt the inscription.
---------------------------------------------------------------------------------------------------

test_color_inscribe_idempotent = {}
test_color_inscribe_idempotent.BRC_FEATURE_NAME = "test-color-inscribe-idempotent"

function test_color_inscribe_idempotent.ready()
  if T._done then return end

  T.run("color-inscribe-idempotent", function()
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then weapon = it; break end
    end

    T.true_(weapon ~= nil, "has-weapon")
    if not weapon then T.done() return end

    -- Inscribe with patterns that colorize wraps (AC and EV both match COLORIZE_TAGS)
    weapon.inscribe("AC+2, EV-1", false)

    -- First colorize
    f_color_inscribe.colorize(weapon)
    local after_first = weapon.inscription

    -- Second colorize: stripping + re-adding must yield the same result
    f_color_inscribe.colorize(weapon)
    local after_second = weapon.inscription

    T.eq(after_second, after_first, "colorize-idempotent")

    T.pass("color-inscribe-idempotent")
    T.done()
  end)
end
