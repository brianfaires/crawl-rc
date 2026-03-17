-- @species Mu
-- @background Be
test_minimal_loop = {}
test_minimal_loop.BRC_FEATURE_NAME = "test-minimal-loop"

T.timeout_turns = 30

-- NOTE: closing } must NOT be the only non-whitespace char on a line.
-- DCSS rc parser terminates the outer Lua block on any such line.
local ITEMS = {
  "sword of Power",
  "robe of Night",
  "shield of Resistance",
  "cloak of the Thief",
  "amulet of the Four Winds",
  "ring of Shadows",
  "orb of Dispater",
  } -- ITEMS

local _phase = "give"

function test_minimal_loop.ready()
  if T._done then return end

  T.run("minimal-loop", function()

    if _phase == "give" then
      local M = f_pickup_alert.Config.Alert.More
      for k in pairs(M) do M[k] = false end
      crawl.setopt("default_autopickup = false")
      local P = f_pickup_alert.Config.Pickup
      P.armour = false
      P.weapons = false
      P.staves = false

      for _, name in ipairs(ITEMS) do
        T.wizard_give(name)
      end
      T.wizard_identify_all()
      _phase = "walk_left"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "walk_left" then
      _phase = "walk_right"
      crawl.do_commands({"CMD_MOVE_LEFT"})

    elseif _phase == "walk_right" then
      _phase = "done_walk"
      crawl.do_commands({"CMD_MOVE_RIGHT"})

    elseif _phase == "done_walk" then
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.pass("minimal-loop")
      T.done()
    end

  end)
end
