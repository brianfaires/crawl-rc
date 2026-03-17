-- @species Tr
-- @background Be
---------------------------------------------------------------------------------------------------
-- BRC stress test: pickup-alert system with a pile of unrand artefacts
-- Verifies no Lua errors fire across multiple step-off/step-on cycles over a large item pile.
--
-- Character: Troll Berserker (large, high HP, natural claws, limited armour slots).
-- Species chosen to exercise: useless-aux-armour path (gloves/boots are useless for Trolls
-- due to natural claws/feet), moon troll leather armour (Troll-specific artefact),
-- high starting HP pool, preference for Axes/M&F weapon schools.
--
-- IMPORTANT: all comments must use ASCII only. DCSS's embedded Lua 5.1 does not handle
-- non-ASCII bytes in source code - they cause a silent parse failure.
--
-- Phase flow: same as the mummy variant.
-- See test_pickup_alert_unrand_stress_mummy.lua for full documentation.
---------------------------------------------------------------------------------------------------

test_pickup_alert_unrand_stress_troll = {}
test_pickup_alert_unrand_stress_troll.BRC_FEATURE_NAME = "test-pickup-alert-unrand-stress-troll"

T.timeout_turns = 60

-- NOTE: closing } must NOT be at column 0.
-- DCSS rc parser terminates the outer Lua block on a bare "^}".
-- Troll-specific: leather/scale armour only, natural claws (gloves useless).
local UNRANDS = {
  "Wrath of Trog",             -- battleaxe (Troll-favored)
  "obsidian axe",              -- great axe artefact
  "moon troll leather armour", -- Troll-specific body armour artefact
  "salamander hide armour",    -- scale body armour
  "shield of Resistance",      -- shield
  "crown of Dyrovepreva",      -- helmet (Trolls CAN wear)
  "cloak of the Thief",        -- cloak (Trolls CAN wear)
  "gauntlets of War",          -- gloves (USELESS for Troll, exercises is_useless)
  "amulet of the Four Winds",  -- jewellery
  "orb of Dispater",           -- misc
  } -- indented: bare "^}" at col 0 terminates the rc Lua block

local _phase = "give"
local _walk_cycles = 0
local WALK_CYCLES = 2

function test_pickup_alert_unrand_stress_troll.ready()
  if T._done then return end

  T.run("pickup-alert-unrand-stress-troll", function()

    if _phase == "give" then
      local M = f_pickup_alert.Config.Alert.More
      for k in pairs(M) do M[k] = false end
      crawl.setopt("default_autopickup = false")
      local P = f_pickup_alert.Config.Pickup
      P.armour = false
      P.weapons = false
      P.staves = false

      for _, name in ipairs(UNRANDS) do
        T.wizard_give(name)
      end
      T.wizard_identify_all()
      _phase = "walk_left"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "walk_left" then
      _phase = "walk_right"
      crawl.do_commands({"CMD_MOVE_LEFT"})

    elseif _phase == "walk_right" then
      _walk_cycles = _walk_cycles + 1
      _phase = (_walk_cycles >= WALK_CYCLES) and "done_walk" or "walk_left"
      crawl.do_commands({"CMD_MOVE_RIGHT"})

    elseif _phase == "done_walk" then
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.pass("pickup-alert-unrand-stress-troll")
      T.done()
    end

  end)
end
