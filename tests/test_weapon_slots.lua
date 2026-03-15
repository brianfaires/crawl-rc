---------------------------------------------------------------------------------------------------
-- BRC feature test: weapon-slots
-- Verifies that f_weapon_slots loaded and initialized without errors.
-- weapon-slots has no Config table, but has clear init state.
---------------------------------------------------------------------------------------------------

test_weapon_slots = {}
test_weapon_slots.BRC_FEATURE_NAME = "test-weapon-slots"

function test_weapon_slots.ready()
  if T._done then return end

  T.run("weapon-slots", function()
    T.true_(f_weapon_slots ~= nil, "module-exists")
    T.eq(f_weapon_slots.BRC_FEATURE_NAME, "weapon-slots", "feature-name")

    -- The starting weapon should be in inventory
    local has_weapon = false
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then has_weapon = true; break end
    end
    T.true_(has_weapon, "has-starting-weapon")

    T.pass("weapon-slots")
    T.done()
  end)
end
