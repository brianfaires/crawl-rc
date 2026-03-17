---------------------------------------------------------------------------------------------------
-- BRC feature test: drop-inferior (weapon path)
-- Verifies that f_drop_inferior.c_assign_invletter marks the starting +0 mace with
-- "~~DROP_ME" when a better weapon (same subtype, higher enchantment, no ego) is picked up.
--
-- The Mummy Berserker starts with a +0 mace (weapon, subtype "mace", plus=0, no ego).
-- We wizard-give "mace plus:5" on the floor: same subtype ("mace"), plus=5 > 0.
-- This satisfies all conditions in c_assign_invletter:
--   - it.is_weapon = true
--   - BRC.eq.is_risky(it) = false  (no ego)
--   - BRC.you.num_eq_slots(it) == 1 (weapons occupy one slot)
--   - inv_ego == it_ego (both nil) -> not_worse = true
--   - not inv.artefact = true
--   - inv.subtype() == it.subtype() ("mace" == "mace")
--   - inv.plus <= it.plus (0 <= 5) -> triggers inscribe_drop
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("mace plus:5") + identify -> CMD_WAIT to turn 1
--   "verify" (turn 1): find +5 mace on floor, call c_assign_invletter(it) directly,
--                      then assert starting +0 mace inscription contains "~~DROP_ME"
--
-- We call f_drop_inferior.c_assign_invletter(floor_mace) directly rather than CMD_PICKUP
-- because CMD_PICKUP cannot be dispatched from inside ready() ("turn is over" guard).
-- Calling the hook directly with a real floor item is equivalent to what crawl does on pickup.
---------------------------------------------------------------------------------------------------

test_drop_inferior_weapon = {}
test_drop_inferior_weapon.BRC_FEATURE_NAME = "test-drop-inferior-weapon"

local _phase = "give"

function test_drop_inferior_weapon.ready()
  if T._done then return end

  T.run("drop-inferior-weapon", function()
    if _phase == "give" then
      -- Place a mace plus:5 on the floor and identify it.
      T.wizard_give("mace plus:5")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1; returns synchronously

    elseif _phase == "verify" then
      -- Find the +5 mace on the floor.
      local floor_mace = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.subtype() == "mace" and (it.plus or 0) >= 5 then
          floor_mace = it
          break
        end
      end
      T.true_(floor_mace ~= nil, "plus5-mace-on-floor")
      if not floor_mace then T.done() return end

      crawl.stderr("floor mace: " .. floor_mace.name() .. " plus=" .. tostring(floor_mace.plus)
        .. " ego=" .. tostring(BRC.eq.get_ego(floor_mace))
        .. " risky=" .. tostring(BRC.eq.is_risky(floor_mace)))

      -- Find the starting +0 mace in inventory before calling the hook.
      local starting_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.subtype() == "mace" and (it.plus or 0) < 5 then
          starting_mace = it
          break
        end
      end
      T.true_(starting_mace ~= nil, "starting-mace-found")
      if not starting_mace then T.done() return end

      local inscr_before = tostring(starting_mace.inscription)
      crawl.stderr("starting mace before: [" .. inscr_before .. "]"
        .. " plus=" .. tostring(starting_mace.plus or 0)
        .. " ego=" .. tostring(BRC.eq.get_ego(starting_mace)))

      -- Call c_assign_invletter directly with the floor mace as the newly-picked-up item.
      -- This is what crawl calls internally when the item is assigned an inventory letter.
      f_drop_inferior.c_assign_invletter(floor_mace)

      -- Re-find the starting mace (same object, inscription may have changed).
      local marked_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.subtype() == "mace" and (it.plus or 0) < 5 then
          marked_mace = it
          break
        end
      end
      T.true_(marked_mace ~= nil, "starting-mace-still-in-inventory")

      if marked_mace then
        local inscr_after = tostring(marked_mace.inscription)
        crawl.stderr("starting mace after: [" .. inscr_after .. "]")
        T.true_(string.find(inscr_after, "~~DROP_ME", 1, true) ~= nil,
          "starting-mace-marked-for-drop")
      end

      T.pass("drop-inferior-weapon")
      T.done()
    end
  end)
end
