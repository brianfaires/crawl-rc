---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (is_unneeded_ring)
-- Verifies f_pa_misc.is_unneeded_ring(it) returns true when the player already has
-- two of the same ring subtype in inventory (non-Octopode can only wear 2 rings total).
--
-- Uses "ring of slaying" (a valid ring type in current DCSS). Note: "ring of fire" is
-- an obsolete ring type and cannot be created via wizard_give.
--
-- Phase flow (one ready() call per phase):
--   "give1"   (turn 0): wizard-give 1st ring of slaying, identify, CMD_WAIT -> turn 1
--   "pickup1" (turn 1): CMD_PICKUP (pick up 1st ring), phase -> "give2"
--   "give2"   (turn 2): wizard-give 2nd ring of slaying, identify, CMD_WAIT -> turn 3
--   "pickup2" (turn 3): CMD_PICKUP (pick up 2nd ring), phase -> "verify"
--   "verify"  (turn 4): wizard-give 3rd ring of slaying, find on floor,
--                        call is_unneeded_ring -> assert true;
--                        also give ring of evasion, assert is_unneeded_ring -> false;
--                        T.pass, T.done
--
-- Note: CMD_PICKUP with exactly one item on the floor picks it up immediately without
-- opening a menu. Rings are NOT auto-picked by BRC (is_unneeded_ring guards) nor by
-- crawl's default autopickup, so they remain on the floor for explicit pickup.
---------------------------------------------------------------------------------------------------

test_pickup_alert_unneeded_ring = {}
test_pickup_alert_unneeded_ring.BRC_FEATURE_NAME = "test-pickup-alert-unneeded-ring"

local _phase = "give1"

function test_pickup_alert_unneeded_ring.ready()
  if T._done then return end

  T.run("pickup-alert-unneeded-ring", function()

    if _phase == "give1" then
      -- Place first ring of slaying on floor and identify it.
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()
      _phase = "pickup1"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup1" then
      -- Exactly one ring on floor: CMD_PICKUP picks it up without a menu.
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give2"

    elseif _phase == "give2" then
      -- Place second ring of slaying on floor and identify it.
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()
      _phase = "pickup2"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup2" then
      -- Pick up the second ring of slaying.
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      -- Confirm 2 rings of slaying are in inventory.
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
      crawl.stderr("DEBUG ring_st=" .. tostring(ring_st) .. " inv_count=" .. tostring(inv_count))
      T.true_(inv_count >= 2, "two-rings-in-inventory")

      -- Give a 3rd ring of the same type and leave it on the floor.
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()

      -- Find the 3rd ring on the floor.
      local floor_ring = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_ring(it) and it.subtype() == ring_st then
          floor_ring = it
          break
        end
      end
      crawl.stderr("DEBUG floor_ring=" .. tostring(floor_ring))
      T.true_(floor_ring ~= nil, "third-ring-on-floor")

      -- Core assertion: 3rd ring of same type is unneeded (2 already in inventory).
      if floor_ring then
        local result = f_pa_misc.is_unneeded_ring(floor_ring)
        crawl.stderr("DEBUG is_unneeded_ring(same-type)=" .. tostring(result))
        T.true_(result, "third-same-type-ring-is-unneeded")
      end

      -- Sanity: a DIFFERENT ring type (0 in inventory) is NOT unneeded.
      T.wizard_give("ring of evasion")
      T.wizard_identify_all()
      local other_ring = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_ring(it) and it.subtype() ~= ring_st then
          other_ring = it
          break
        end
      end
      crawl.stderr("DEBUG other_ring=" .. tostring(other_ring))
      T.true_(other_ring ~= nil, "different-ring-on-floor")
      if other_ring then
        local result = f_pa_misc.is_unneeded_ring(other_ring)
        crawl.stderr("DEBUG is_unneeded_ring(different-type)=" .. tostring(result))
        T.false_(result, "different-type-ring-not-unneeded")
      end

      T.pass("pickup-alert-unneeded-ring")
      T.done()
    end

  end)
end
