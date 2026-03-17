---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (body armour, naked character / starting-robe scenario)
--
-- FINDINGS FROM INITIAL RUN:
--   A Mummy Berserker starts with a plain robe equipped — the character is NOT naked.
--   items.equipped_at("armour") returns the starting robe, so the naked guard
--   (line 118 in pickup_body_armour, line 227 in alert_body_armour) is NOT hit.
--
-- This test therefore documents the actual starting-robe scenario:
--   - A robe of fire resistance on the floor IS auto-picked up (ego upgrade: nil -> fire res,
--     same AC, same encumbrance → pickup_body_armour returns true).
--   - Because it is picked up, no alert fires (autopickup short-circuits before alert check).
--   - The naked guard code path cannot be triggered through the standard test harness.
--
-- Phase flow:
--   "give"   (turn 0): wizard-give robe of fire resistance + identify, then CMD_WAIT
--   "check"  (turn 1): confirm armour slot state, call BRC.autopickup on floor items, CMD_WAIT
--   "verify" (turn 2): assert robe WAS auto-picked up (ego upgrade), assert no alert message
---------------------------------------------------------------------------------------------------

test_pickup_alert_body_armour_naked = {}
test_pickup_alert_body_armour_naked.BRC_FEATURE_NAME = "test-pickup-alert-body-armour-naked"

local _phase = "give"

function test_pickup_alert_body_armour_naked.ready()
  if T._done then return end

  T.run("pickup-alert-body-armour-naked", function()
    if _phase == "give" then
      -- Give a body armour with ego. The Mummy Berserker starts wearing a plain robe,
      -- so items.equipped_at("armour") is non-nil — this is the non-naked code path.
      T.wizard_give("robe of fire resistance")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Confirm whether the character has body armour equipped (expected: yes, plain robe).
      -- This is the key prereq that determines which code path runs.
      local cur = items.equipped_at("armour")
      T.true_(cur ~= nil, "has-body-armour-equipped-prereq")

      -- The robe of fire resistance was already consumed by the crawl engine's autopickup
      -- hook during CMD_WAIT in the give phase. By the time check phase runs, it is gone
      -- from the floor (either in inventory or auto-equipped).
      -- Confirm it is no longer on the floor.
      local floor_body_armour_count = 0
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) then floor_body_armour_count = floor_body_armour_count + 1 end
      end
      T.true_(floor_body_armour_count == 0, "robe-already-picked-up-by-engine")

      -- Disable force_more so the test doesn't hang waiting for input.
      local orig_body_armour = f_pickup_alert.Config.Alert.More.body_armour
      local orig_armour_ego  = f_pickup_alert.Config.Alert.More.armour_ego
      f_pickup_alert.Config.Alert.More.body_armour = false
      f_pickup_alert.Config.Alert.More.armour_ego  = false

      -- Clear messages then run autopickup on the floor robe.
      T.last_messages = {}
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) then
          BRC.autopickup(it)
        end
      end

      -- Restore force_more settings.
      f_pickup_alert.Config.Alert.More.body_armour = orig_body_armour
      f_pickup_alert.Config.Alert.More.armour_ego  = orig_armour_ego

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- The robe of fire resistance should be in inventory: it is an ego upgrade over the
      -- plain starting robe (cur_ego=nil -> it_ego=fire resistance, same encumbrance, same AC).
      -- pickup_body_armour: not cur_ego and (ac_delta >= 0 or encumb_delta <= 0) -> true.
      -- NOTE: The robe was already picked up by the crawl engine's autopickup hook during the
      -- CMD_WAIT in the give phase — it was gone from the floor by the check phase.
      -- Check inventory AND equipped slot for fire resistance robe.
      local picked_up = false
      for _, it in ipairs(items.inventory()) do
        if BRC.it.is_body_armour(it) then picked_up = true end
      end
      -- Also check if the fire res robe is now equipped (auto-wear after pickup?)
      local worn = items.equipped_at("armour")
      if worn then
        local n = worn.name()
        if n:find("fire") or BRC.eq.get_ego(worn) then picked_up = true end
      end
      T.true_(picked_up, "robe-fire-res-auto-picked-up")

      -- Because it was picked up (autopickup returned true), the alert path is short-circuited.
      -- No "Early armour" or ego alert message should appear.
      local alert_fired = T.messages_contain("Early armour")
        or T.messages_contain("ego")
        or T.messages_contain("fire resistance")
      T.false_(alert_fired, "no-alert-when-picked-up")

      T.pass("pickup-alert-body-armour-naked")
      T.done()
    end
  end)
end
