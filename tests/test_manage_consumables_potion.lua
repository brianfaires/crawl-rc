---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (potion gets !q)
-- Verifies that potions NOT in NO_INSCRIPTION_NEEDED receive a "!q" inscription.
--
-- potion_needs_inscription(st) = not util.contains(NO_INSCRIPTION_NEEDED, st)
-- "haste" is not in NO_INSCRIPTION_NEEDED, so potion of haste SHOULD get "!q".
-- Note: Mummies cannot drink potions, but the code has no species check —
-- potions are inscribed for safety regardless of whether the species can use them.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → potion on floor → CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP → potion in inventory
--   "verify" (turn 2): assert inscription contains "!q"
---------------------------------------------------------------------------------------------------

test_manage_consumables_potion = {}
test_manage_consumables_potion.BRC_FEATURE_NAME = "test-manage-consumables-potion"

local _phase = "give"

function test_manage_consumables_potion.ready()
  if T._done then return end

  T.run("manage-consumables-potion", function()
    if _phase == "give" then
      T.wizard_give("potion of haste")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local potion = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "potion" and it.subtype() == "haste" then
          potion = it
          break
        end
      end

      T.true_(potion ~= nil, "potion-of-haste-in-inventory")
      if potion then
        -- potion of haste not in NO_INSCRIPTION_NEEDED; should get !q
        T.true_(potion.inscription:contains("!q"), "potion-of-haste-has-safe-inscription")
      end
      T.pass("manage-consumables-potion")
      T.done()
    end
  end)
end
