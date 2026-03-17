---------------------------------------------------------------------------------------------------
-- BRC feature test: drop-inferior (armour path)
-- Verifies that f_drop_inferior.c_assign_invletter marks the starting animal skin with
-- "~~DROP_ME" when a better body armour (same subtype, higher AC, same encumbrance) is picked up.
--
-- The Mummy Berserker starts wearing an animal skin (body armour, AC 2, encumbrance 0, no ego).
-- We wizard-give "animal skin plus:5" on the floor: same subtype ("body"), same encumbrance (0),
-- higher effective AC due to +5 enchantment. This satisfies all conditions in c_assign_invletter:
--   - BRC.it.is_armour(it) = true
--   - inv_ego == it_ego (both nil) -> not_worse = true
--   - not inv.artefact = true
--   - inv.subtype() == it.subtype() ("body" == "body")
--   - BRC.eq.get_ac(inv) <= BRC.eq.get_ac(it) (starting skin AC <= enchanted skin AC)
--   - inv.encumbrance >= it.encumbrance (0 >= 0)
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("animal skin plus:5") + identify -> CMD_WAIT to turn 1
--   "verify" (turn 1): find +5 animal skin on floor, call c_assign_invletter(it) directly,
--                      then assert starting animal skin inscription contains "~~DROP_ME"
--
-- We call f_drop_inferior.c_assign_invletter(floor_item) directly rather than CMD_PICKUP
-- because CMD_PICKUP cannot be dispatched from inside ready() ("turn is over" guard).
-- Calling the hook directly with a real floor item is equivalent to what crawl does on pickup.
---------------------------------------------------------------------------------------------------

test_drop_inferior_armour = {}
test_drop_inferior_armour.BRC_FEATURE_NAME = "test-drop-inferior-armour"

local _phase = "give"

function test_drop_inferior_armour.ready()
  if T._done then return end

  T.run("drop-inferior-armour", function()
    if _phase == "give" then
      -- Place an animal skin plus:5 on the floor and identify it.
      T.wizard_give("animal skin plus:5")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1; returns synchronously

    elseif _phase == "verify" then
      -- Find the +5 animal skin on the floor.
      local floor_skin = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and it.subtype() == "body" and (it.plus or 0) >= 5 then
          floor_skin = it
          break
        end
      end
      T.true_(floor_skin ~= nil, "plus5-animal-skin-on-floor")
      if not floor_skin then T.done() return end

      crawl.stderr("floor skin: " .. floor_skin.name() .. " plus=" .. tostring(floor_skin.plus)
        .. " enc=" .. tostring(floor_skin.encumbrance)
        .. " ac=" .. tostring(floor_skin.ac))

      -- Find the starting animal skin in inventory before calling the hook.
      local starting_skin = nil
      for _, it in ipairs(items.inventory()) do
        if BRC.it.is_body_armour(it) and it.subtype() == "body" then
          starting_skin = it
          break
        end
      end
      T.true_(starting_skin ~= nil, "starting-animal-skin-found")
      if not starting_skin then T.done() return end

      local inscr_before = tostring(starting_skin.inscription)
      crawl.stderr("starting skin before: [" .. inscr_before .. "]"
        .. " enc=" .. tostring(starting_skin.encumbrance)
        .. " ac=" .. tostring(starting_skin.ac)
        .. " plus=" .. tostring(starting_skin.plus or 0))

      -- Call c_assign_invletter directly with the floor skin as the newly-picked-up item.
      -- This is what crawl calls internally when the item is assigned an inventory letter.
      f_drop_inferior.c_assign_invletter(floor_skin)

      -- Re-find the starting animal skin (same object, inscription may have changed).
      local marked_skin = nil
      for _, it in ipairs(items.inventory()) do
        if BRC.it.is_body_armour(it) and it.subtype() == "body" then
          marked_skin = it
          break
        end
      end
      T.true_(marked_skin ~= nil, "starting-skin-still-in-inventory")

      if marked_skin then
        local inscr_after = tostring(marked_skin.inscription)
        crawl.stderr("starting skin after: [" .. inscr_after .. "]")
        T.true_(string.find(inscr_after, "~~DROP_ME", 1, true) ~= nil,
          "starting-animal-skin-marked-for-drop")
      end

      T.pass("drop-inferior-armour")
      T.done()
    end
  end)
end
