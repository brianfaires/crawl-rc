-- @species Op
-- @background Sh
---------------------------------------------------------------------------------------------------
-- BRC stress test: pickup-alert system with a pile of unrand artefacts
-- Verifies no Lua errors fire across multiple step-off/step-on cycles over a large item pile.
--
-- Character: Octopode Shapeshifter (8 ring slots, tentacle weapons, Shapeshifting skill).
-- Species chosen to exercise: 8-ring-slot logic (num_eq_slots), robe-only body armour,
-- no shield slot, high Shapeshifting skill affecting talisman_lvl_diff.
--
-- IMPORTANT: all comments must use ASCII only. DCSS's embedded Lua 5.1 does not handle
-- non-ASCII bytes in source code - they cause a silent parse failure.
--
-- Phase flow: same as the mummy variant.
-- See test_pickup_alert_unrand_stress_mummy.lua for full documentation.
---------------------------------------------------------------------------------------------------

test_pickup_alert_unrand_stress_octopode = {}
test_pickup_alert_unrand_stress_octopode.BRC_FEATURE_NAME = "test-pickup-alert-unrand-stress-octopode"

T.timeout_turns = 60

-- NOTE: closing } must NOT be at column 0.
-- DCSS rc parser terminates the outer Lua block on a bare "^}".
-- Octopode-specific: robe-only body armour, 8-ring slots, no shields.
local UNRANDS = {
  "sword of Power",              -- melee weapon
  "trident of the Octopus King", -- Octopode-specific weapon artefact
  "robe of Night",               -- body armour (robe only for Octopodes)
  "robe of Augmentation",        -- body armour variant
  "ring of Shadows",             -- ring (Octopodes wear 8)
  "ring of the Octopus King",    -- Octopode-specific ring artefact
  "amulet of the Four Winds",    -- amulet
  "cloak of the Thief",          -- aux armour (cloak)
  "orb of Dispater",             -- misc
  } -- indented: bare "^}" at col 0 terminates the rc Lua block

local _phase = "give"
local _walk_cycles = 0
local WALK_CYCLES = 2

function test_pickup_alert_unrand_stress_octopode.ready()
  if T._done then return end

  T.run("pickup-alert-unrand-stress-octopode", function()

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
      T.pass("pickup-alert-unrand-stress-octopode")
      T.done()
    end

  end)
end
