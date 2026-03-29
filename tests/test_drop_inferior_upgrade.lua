---------------------------------------------------------------------------------------------------
-- BRC feature test: drop-inferior (upgrade path)
-- Verifies that f_drop_inferior.c_assign_invletter marks the starting "+0 mace" with
-- "~~DROP_ME" when a "+5 mace" is picked up.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("mace plus:5") + identify → CMD_WAIT to turn 1
--   "verify" (turn 1): find +5 mace on floor, call c_assign_invletter(it) directly,
--                      then assert starting mace inscription contains "~~DROP_ME"
--
-- We call f_drop_inferior.c_assign_invletter(floor_mace) directly rather than CMD_PICKUP
-- because CMD_PICKUP cannot be dispatched from inside ready() ("turn is over" guard).
-- Calling the hook directly with a real floor item is equivalent to what crawl does on pickup.
---------------------------------------------------------------------------------------------------

test_drop_inferior_upgrade = {}
test_drop_inferior_upgrade.BRC_FEATURE_NAME = "test-drop-inferior-upgrade"

local _phase = "give"

function test_drop_inferior_upgrade.ready()
  if T._done then return end

  T.run("drop-inferior-upgrade", function()
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

      crawl.stderr("floor mace: " .. floor_mace.name() .. " plus=" .. tostring(floor_mace.plus))

      -- Call c_assign_invletter directly with the floor mace as the newly-picked-up item.
      -- This is what crawl calls internally when the +5 mace is assigned an inventory letter.
      f_drop_inferior.c_assign_invletter(floor_mace)

      -- Find the starting mace in inventory: a mace with plus < 5 (the +0 starting weapon).
      local starting_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.subtype() == "mace" and (it.plus or 0) < 5 then
          starting_mace = it
          break
        end
      end

      T.true_(starting_mace ~= nil, "starting-mace-found")

      if starting_mace then
        local inscr = tostring(starting_mace.inscription)
        crawl.stderr("starting mace inscription: [" .. inscr .. "]")
        T.true_(string.find(inscr, "~~DROP_ME", 1, true) ~= nil, "starting-mace-marked-for-drop")
      end

      T.pass("drop-inferior-upgrade")
      T.done()
    end
  end)
end
