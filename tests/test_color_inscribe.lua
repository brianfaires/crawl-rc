---------------------------------------------------------------------------------------------------
-- BRC feature test: color-inscribe
-- Verifies that f_color_inscribe.colorize() modifies the inscription of an item
-- that contains colorizable patterns (AC/EV stat strings).
--
-- color-inscribe.Config.disabled = true by default, but colorize() does not check
-- this flag and can be called directly for testing.
---------------------------------------------------------------------------------------------------

test_color_inscribe = {}
test_color_inscribe.BRC_FEATURE_NAME = "test-color-inscribe"

function test_color_inscribe.ready()
  if T._done then return end

  T.run("color-inscribe", function()
    -- Get starting weapon (Mummy Berserker starts with a mace)
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then
        weapon = it
        break
      end
    end

    T.true_(weapon ~= nil, "has-weapon")
    if not weapon then T.done() return end

    -- Manually inscribe with a pattern that colorize handles (AC+N triggers COLORIZE_TAGS)
    weapon.inscribe("AC+2, EV-1", false)
    T.eq(weapon.inscription, "AC+2, EV-1", "inscription-set")

    -- Colorize: wraps matching patterns in color tags
    f_color_inscribe.colorize(weapon)

    -- After colorizing, the inscription must differ from the plain input
    -- (AC+2 and EV-1 both match COLORIZE_TAGS entries and get wrapped)
    T.true_(weapon.inscription ~= "AC+2, EV-1", "inscription-changed")

    T.pass("color-inscribe")
    T.done()
  end)
end
