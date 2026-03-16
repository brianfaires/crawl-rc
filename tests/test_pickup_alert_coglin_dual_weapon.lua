-- @species Co
-- @background Fi
-- @weapon flail
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Coglin 2 weapon equipment slots)
-- Verifies BRC.you.num_eq_slots() returns 2 for weapons for Coglin (you.lua:84 branch).
-- Coglin can dual-wield, so a weapon occupies 2 slots (main + offhand).
-- Non-weapon items (helmet) still return 1 for Coglin.
--
-- Note: it.is_weapon and it.is_armour return nil for floor items from you.floor_items().
-- Search uses name-based matching only.
--
-- Phase flow:
--   "give"   (turn 0): wizard-give hand axe + helmet, identify, CMD_WAIT → turn 1
--   "verify" (turn 1): find items on floor by name, assert num_eq_slots, T.pass, T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_coglin_dual_weapon = {}
test_pickup_alert_coglin_dual_weapon.BRC_FEATURE_NAME = "test-pickup-alert-coglin-dual-weapon"

local _phase = "give"

function test_pickup_alert_coglin_dual_weapon.ready()
  if T._done then return end

  T.run("pickup-alert-coglin-dual-weapon", function()

    if _phase == "give" then
      T.wizard_give("hand axe")
      T.wizard_give("helmet")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.eq(you.race(), "Coglin", "char-is-coglin")

      local floor_axe = nil
      local floor_helmet = nil
      for _, it in ipairs(you.floor_items()) do
        local n = it.name()
        if n:find("hand axe") and not floor_axe then
          floor_axe = it
        elseif n:find("helmet") and not floor_helmet then
          floor_helmet = it
        end
      end

      T.true_(floor_axe ~= nil, "hand-axe-on-floor")
      T.true_(floor_helmet ~= nil, "coglin-helmet-on-floor")
      if not floor_axe or not floor_helmet then T.done() return end

      T.eq(BRC.you.num_eq_slots(floor_axe),    2, "coglin-weapon-2-slots")
      T.eq(BRC.you.num_eq_slots(floor_helmet),  1, "coglin-non-weapon-slots-unaffected")

      T.pass("pickup-alert-coglin-dual-weapon")
      T.done()
    end
  end)
end
