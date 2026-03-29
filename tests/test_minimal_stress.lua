-- @species Mu
-- @background Be
test_minimal_stress = {}
test_minimal_stress.BRC_FEATURE_NAME = "test-minimal-stress"

T.timeout_turns = 30

local _phase = "give"

function test_minimal_stress.ready()
  if T._done then return end

  T.run("minimal-stress", function()

    if _phase == "give" then
      local M = f_pickup_alert.Config.Alert.More
      for k in pairs(M) do M[k] = false end
      crawl.setopt("default_autopickup = false")
      local P = f_pickup_alert.Config.Pickup
      P.armour = false
      P.weapons = false
      P.staves = false

      T.wizard_give("sword of Power")
      T.wizard_give("robe of Night")
      T.wizard_give("shield of Resistance")
      T.wizard_give("cloak of the Thief")
      T.wizard_give("amulet of the Four Winds")
      T.wizard_give("ring of Shadows")
      T.wizard_give("orb of Dispater")
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
      T.pass("minimal-stress")
      T.done()
    end

  end)
end
