-- @species Mu
-- @background Be
---------------------------------------------------------------------------------------------------
-- BRC stress test: pickup-alert system with a pile of unrand artefacts
-- Verifies no Lua errors fire across multiple step-off/step-on cycles over a large item pile.
--
-- Character: Mummy Berserker (undead, no magic, starts with mace).
--
-- Phase flow:
--   "give"      (turn 0): suppress ALL More flags and ALL pickup flags so items stay on floor.
--                         Give all unrands + wizard_identify_all, then CMD_WAIT.
--   "walk_left" (3x):     CMD_MOVE_LEFT off the pile.
--   "walk_right"(3x):     CMD_MOVE_RIGHT back onto pile (triggers autopickup/alert hooks per item).
--                         Pickup suppressed so items stay on floor and no equip sequence fires.
--   "done_walk" (1):      CMD_WAIT to flush any queued alerts.
--   "verify":             T.pass + T.done. Reaching here = no Lua errors (T.run pcall catches all).
--
-- Force_more suppression: all keys in M table set false before give phase, never restored.
-- Pickup suppression: C.Pickup.armour/weapons/staves set false so items stay on floor and don't
--   trigger equip sequences (which set pause_pa_system=true and block headlessly).
--
-- IMPORTANT: all comments must use ASCII only. DCSS's embedded Lua 5.1 does not handle
-- non-ASCII bytes in source code - they cause a silent parse failure.
---------------------------------------------------------------------------------------------------

test_pickup_alert_unrand_stress_mummy = {}
test_pickup_alert_unrand_stress_mummy.BRC_FEATURE_NAME = "test-pickup-alert-unrand-stress-mummy"

T.timeout_turns = 60

-- Representative unrands covering every item category.
-- All given in one ready() call (no per-item return needed).
-- NOTE: closing } must NOT be at column 0.
-- DCSS rc parser terminates the outer Lua block on a bare "^}".
local UNRANDS = {
  "sword of Power",           -- melee weapon
  "Wrath of Trog",            -- melee weapon (M&F)
  "robe of Night",            -- body armour
  "Maxwell's patent armour",  -- body armour (plate)
  "shield of Resistance",     -- shield
  "cloak of the Thief",       -- aux armour (cloak)
  "gauntlets of War",         -- aux armour (gloves)
  "amulet of the Four Winds", -- jewellery (amulet)
  "ring of Shadows",          -- jewellery (ring)
  "orb of Dispater",          -- misc
  } -- indented: bare "^}" at col 0 terminates the rc Lua block

local _phase = "give"
local _walk_cycles = 0
local WALK_CYCLES = 2

function test_pickup_alert_unrand_stress_mummy.ready()
  if T._done then return end

  T.run("pickup-alert-unrand-stress-mummy", function()

    if _phase == "give" then
      -- Suppress all force_more flags so consume_queue() never calls crawl.more()
      local M = f_pickup_alert.Config.Alert.More
      for k in pairs(M) do M[k] = false end

      -- Disable DCSS default autopickup so floor items don't get picked up when BRC
      -- returns nil (no decision). Without this, DCSS picks up armour/jewellery by default
      -- and triggers equip sequences that block headlessly.
      crawl.setopt("default_autopickup = false")

      -- Also disable BRC pickup to prevent BRC itself from picking up items.
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
      -- Reaching here means T.run's pcall never caught a Lua error.
      T.pass("pickup-alert-unrand-stress-mummy")
      T.done()
    end

  end)
end
