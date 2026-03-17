---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (potion mutation / lignification NO_INSCRIPTION_NEEDED)
-- Verifies that potions IN NO_INSCRIPTION_NEEDED do NOT receive "!q", and potions NOT in the
-- list DO receive "!q".
--
-- NO_INSCRIPTION_NEEDED includes "mutation" and "lignification", so those potions must not get !q.
-- "haste" is NOT in NO_INSCRIPTION_NEEDED, so it must get !q.
--
-- Each potion is given and picked up in its own give/pickup cycle (one item on the floor at a
-- time) to avoid the multi-item pickup menu that would hang headlessly.
--
-- Phase flow:
--   "give1"    (turn 0): wizard_give mutation + identify → CMD_WAIT
--   "pickup1"  (turn 1): CMD_PICKUP mutation → advance
--   "give2"    (turn 2): wizard_give lignification + identify → CMD_WAIT
--   "pickup2"  (turn 3): CMD_PICKUP lignification → advance
--   "give3"    (turn 4): wizard_give haste + identify → CMD_WAIT
--   "pickup3"  (turn 5): CMD_PICKUP haste → advance
--   "verify"   (turn 6): assert mutation/lignification have no !q; haste has !q
---------------------------------------------------------------------------------------------------

test_manage_consumables_potion_mutation = {}
test_manage_consumables_potion_mutation.BRC_FEATURE_NAME = "test-manage-consumables-potion-mutation"

local _phase = "give1"

function test_manage_consumables_potion_mutation.ready()
  if T._done then return end

  T.run("manage-consumables-potion-mutation", function()

    if _phase == "give1" then
      T.wizard_give("potion of mutation")
      T.wizard_identify_all()
      _phase = "pickup1"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup1" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give2"

    elseif _phase == "give2" then
      T.wizard_give("potion of lignification")
      T.wizard_identify_all()
      _phase = "pickup2"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup2" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give3"

    elseif _phase == "give3" then
      T.wizard_give("potion of haste")
      T.wizard_identify_all()
      _phase = "pickup3"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup3" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local mutation_pot = nil
      local lignification_pot = nil
      local haste_pot = nil

      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "potion" then
          local st = it.subtype()
          if st == "mutation" then
            mutation_pot = it
          elseif st == "lignification" then
            lignification_pot = it
          elseif st == "haste" then
            haste_pot = it
          end
        end
      end

      -- Verify all three potions are present
      T.true_(mutation_pot ~= nil, "mutation-potion-in-inventory")
      T.true_(lignification_pot ~= nil, "lignification-potion-in-inventory")
      T.true_(haste_pot ~= nil, "haste-potion-in-inventory")

      -- mutation is in NO_INSCRIPTION_NEEDED: must NOT get !q
      if mutation_pot then
        T.false_(mutation_pot.inscription:contains("!q"), "mutation-potion-no-safe-inscription")
      end

      -- lignification is in NO_INSCRIPTION_NEEDED: must NOT get !q
      if lignification_pot then
        T.false_(lignification_pot.inscription:contains("!q"), "lignification-potion-no-safe-inscription")
      end

      -- haste is NOT in NO_INSCRIPTION_NEEDED: MUST get !q
      if haste_pot then
        T.true_(haste_pot.inscription:contains("!q"), "haste-potion-has-safe-inscription")
      end

      T.pass("manage-consumables-potion-mutation")
      T.done()
    end
  end)
end
