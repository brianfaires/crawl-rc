---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables
-- Verifies that f_manage_consumables.ready() adds !q to potions that need it.
--
-- Berserkers start with a potion of berserk rage. "berserk rage" is not in
-- NO_INSCRIPTION_NEEDED, so maintain_inscriptions() should add "!q" to it.
-- We call f_manage_consumables.ready() directly and verify the result.
---------------------------------------------------------------------------------------------------

test_manage_consumables = {}
test_manage_consumables.BRC_FEATURE_NAME = "test-manage-consumables"

function test_manage_consumables.ready()
  if T._done then return end

  T.run("manage-consumables", function()
    -- Trigger maintain_inscriptions via ready()
    f_manage_consumables.ready()

    -- Find a potion in inventory and verify it received !q inscription
    local found_potion = nil
    for _, it in ipairs(items.inventory()) do
      if it.class(true) == "potion" then
        found_potion = it
        break
      end
    end

    if found_potion then
      -- Potion should have been inscribed with !q by maintain_inscriptions
      T.true_(found_potion.inscription:contains("!q"), "potion-has-safe-inscription")
    else
      -- No potion in starting inventory — just verify ready() ran without error
      T.pass("no-potion-found-skipping")
    end

    T.pass("manage-consumables")
    T.done()
  end)
end
