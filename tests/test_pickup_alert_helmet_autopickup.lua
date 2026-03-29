---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (helmet autopickup, Mummy Berserker)
-- Verifies that a plain helmet is auto-picked up when no helmet is equipped or in inventory,
-- and that a SECOND plain helmet is NOT auto-picked up when one is already in inventory.
--
-- Mummy Berserker: no horns/beak/antennae mutations, so aux_slot_is_impaired returns false.
-- helmet has num_slots == 1. pickup_aux_armour logic:
--   1st helmet: slot empty, not carrying one -> pickup_aux_armour returns true
--   2nd helmet: slot empty, but one already in inventory -> pickup_aux_armour returns false
--
-- Phase flow:
--   "give_first"    (turn 0): wizard_give("helmet") + identify -> CMD_WAIT
--   "verify_first"  (turn 1): assert f_pa_armour.pickup_armour returns true,
--                             assert BRC.autopickup returns true,
--                             then CMD_PICKUP (explicitly pick it up)
--   "give_second"   (turn 2): assert first helmet now in inventory,
--                             wizard_give second helmet + identify -> CMD_WAIT
--   "verify_second" (turn 3): assert f_pa_armour.pickup_armour returns false
--                             (already carrying one) -> done
--
-- Note: CMD_PICKUP is used to explicitly pick up the first helmet (one item on floor at a time
-- avoids the multi-item pickup menu that would hang headlessly).
---------------------------------------------------------------------------------------------------

test_pickup_alert_helmet_autopickup = {}
test_pickup_alert_helmet_autopickup.BRC_FEATURE_NAME = "test-pickup-alert-helmet-autopickup"

local _phase = "give_first"

local function find_helmet_on_floor()
  for _, it in ipairs(you.floor_items()) do
    if it.subtype() == "helmet" then return it end
  end
  return nil
end

local function find_helmet_in_inventory()
  for _, it in ipairs(items.inventory()) do
    if it.subtype() == "helmet" then return it end
  end
  return nil
end

function test_pickup_alert_helmet_autopickup.ready()
  if T._done then return end

  T.run("pickup-alert-helmet-autopickup", function()
    if _phase == "give_first" then
      T.wizard_give("helmet")
      T.wizard_identify_all()
      _phase = "verify_first"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify_first" then
      -- Preconditions: no helmet equipped, none in inventory yet
      T.false_(items.equipped_at("helmet") ~= nil, "no-helmet-equipped-precond")
      T.false_(find_helmet_in_inventory() ~= nil, "no-helmet-in-inventory-precond")

      local helmet = find_helmet_on_floor()
      T.true_(helmet ~= nil, "first-helmet-on-floor")

      if helmet then
        -- Direct function test: pickup_aux_armour returns true (slot empty, not carrying one)
        local pa_result = f_pa_armour.pickup_armour(helmet)
        T.true_(pa_result == true, "first-helmet-pickup-armour-returns-true")

        -- Full autopickup hook: BRC.autopickup returns true (would trigger pickup)
        -- Temporarily disable one_time_alerts force_more so headless doesn't hang
        local orig_fm = f_pickup_alert.Config.Alert.More.one_time_alerts
        f_pickup_alert.Config.Alert.More.one_time_alerts = false
        local ap_result = BRC.autopickup(helmet)
        f_pickup_alert.Config.Alert.More.one_time_alerts = orig_fm
        T.true_(ap_result == true, "first-helmet-autopickup-returns-true")
      end

      -- Explicitly pick up the helmet so it's in inventory for the next phase
      _phase = "give_second"
      crawl.do_commands({"CMD_PICKUP"})

    elseif _phase == "give_second" then
      -- CMD_PICKUP should have moved the first helmet into inventory
      T.true_(find_helmet_in_inventory() ~= nil, "first-helmet-in-inventory-after-pickup")

      -- Give a second plain helmet
      T.wizard_give("helmet")
      T.wizard_identify_all()
      _phase = "verify_second"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify_second" then
      -- First helmet is still in inventory (not equipped — Mummy Berserker starts naked)
      T.true_(find_helmet_in_inventory() ~= nil, "first-helmet-still-in-inventory")

      local second_helmet = find_helmet_on_floor()
      T.true_(second_helmet ~= nil, "second-helmet-on-floor")

      if second_helmet then
        -- Already carrying one helmet -> pickup_aux_armour returns false
        local pa_result2 = f_pa_armour.pickup_armour(second_helmet)
        T.false_(pa_result2, "second-helmet-pickup-armour-returns-false")

        -- Full autopickup hook: should NOT return true
        local orig_fm = f_pickup_alert.Config.Alert.More.one_time_alerts
        f_pickup_alert.Config.Alert.More.one_time_alerts = false
        local ap_result2 = BRC.autopickup(second_helmet)
        f_pickup_alert.Config.Alert.More.one_time_alerts = orig_fm
        T.false_(ap_result2 == true, "second-helmet-autopickup-not-true")
      end

      T.pass("pickup-alert-helmet-autopickup")
      T.done()
    end
  end)
end
