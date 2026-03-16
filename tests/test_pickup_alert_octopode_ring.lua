-- @species Op
-- @background Be
-- @weapon handaxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Octopode is_unneeded_ring short-circuit)
-- Verifies f_pa_misc.is_unneeded_ring() returns false for Octopode even when 2 rings of
-- the same subtype are in inventory (pa-misc.lua:108 short-circuits on you.race() == "Octopode").
--
-- Octopode can wear 8 rings (one per tentacle arm), so no ring is ever "unneeded" for them.
-- For non-Octopode with 2 same-type rings in inventory, is_unneeded_ring returns true.
-- For Octopode, it returns false regardless.
--
-- Phase flow:
--   "give1"   (turn 0): wizard-give 1st ring of slaying, identify, CMD_WAIT -> turn 1
--   "pickup1" (turn 1): CMD_PICKUP (pick up 1st ring), phase -> "give2"
--   "give2"   (turn 2): wizard-give 2nd ring of slaying, identify, CMD_WAIT -> turn 3
--   "pickup2" (turn 3): CMD_PICKUP (pick up 2nd ring), phase -> "verify"
--   "verify"  (turn 4): wizard-give 3rd ring, find on floor, assert is_unneeded_ring=false;
--                       T.pass, T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_octopode_ring = {}
test_pickup_alert_octopode_ring.BRC_FEATURE_NAME = "test-pickup-alert-octopode-ring"

local _phase = "give1"

function test_pickup_alert_octopode_ring.ready()
  if T._done then return end

  T.run("pickup-alert-octopode-ring", function()

    if _phase == "give1" then
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()
      _phase = "pickup1"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup1" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give2"

    elseif _phase == "give2" then
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()
      _phase = "pickup2"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup2" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      T.eq(you.race(), "Octopode", "char-is-octopode")

      -- Confirm 2 rings of slaying are in inventory
      local ring_st = nil
      local inv_count = 0
      for _, inv in ipairs(items.inventory()) do
        if BRC.it.is_ring(inv) then
          ring_st = ring_st or inv.subtype()
          if inv.subtype() == ring_st then
            inv_count = inv_count + 1
          end
        end
      end
      T.true_(inv_count >= 2, "two-rings-of-slaying-in-inventory")

      -- Give a 3rd ring of same type and leave it on the floor
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()

      local floor_ring = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_ring(it) and it.subtype() == ring_st then
          floor_ring = it
          break
        end
      end
      T.true_(floor_ring ~= nil, "third-ring-on-floor")
      if not floor_ring then T.done() return end

      -- Core assertion: Octopode short-circuit → ring is NOT unneeded even with 2 in inventory
      local result = f_pa_misc.is_unneeded_ring(floor_ring)
      T.false_(result, "octopode-ring-not-unneeded")

      -- Sanity: a DIFFERENT ring type (0 in inventory) is also not unneeded for Octopode
      T.wizard_give("ring of evasion")
      T.wizard_identify_all()
      local other_ring = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_ring(it) and it.subtype() ~= ring_st then
          other_ring = it
          break
        end
      end
      T.true_(other_ring ~= nil, "evasion-ring-on-floor")
      if not other_ring then T.done() return end
      T.false_(f_pa_misc.is_unneeded_ring(other_ring), "octopode-different-ring-not-unneeded")

      T.pass("pickup-alert-octopode-ring")
      T.done()
    end
  end)
end
