if loaded_pa_main then return end
loaded_pa_main = true
dofile("crawl-rc/lua/config.lua")
dofile("crawl-rc/lua/util.lua")
dofile("crawl-rc/lua/pickup-alert/pa-util.lua")
dofile("crawl-rc/lua/pickup-alert/pa-data.lua")

local pause_pickup_alert = false
local last_ready_item_alerts_turn = 0

function alert_item(it, alert_type)
  local name = it.name("plain")
  if not it.is_identified then name = "+0 " .. name end

  if not previously_alerted(it) and not previously_picked(it) then
    if is_weapon(it) or is_staff(it) then
      show_alert_msg("Item alert, "..alert_type..": ", name.." "..get_weapon_info(it))
	  elseif is_body_armour(it) then
      local ac, ev = get_armour_info_strings(it)
      show_alert_msg("Item alert, "..alert_type..": ", name.." "..ac..", "..ev)
    elseif is_armour(it) then
      show_alert_msg("Item alert, "..alert_type..": ", name)
    else
      show_alert_msg("Item alert, "..alert_type..": ", name)
    end

    insert_item_and_less_enchanted(items_alerted, it)
    table.insert(level_alerts, name)
  end

  -- Returns true to make other code more concise; indicates that we tried to alert this item
  return true
end
crawl.setopt("runrest_stop_message += Item alert, ")


------------------- Hooks -------------------
function c_assign_invletter_item_alerts(it)
  if is_weapon(it) or is_armour(it) then
    if not previously_picked(it) then
      insert_item_and_less_enchanted(items_picked, it)
      update_high_scores(it)
      remove_from_rare_items(it)
    end
  end

  remove_item_and_less_enchanted(items_alerted, it)
  util.remove(level_alerts, it.name("plain"))
end

function c_message_item_alerts(text, _)
  if text:find("You start waiting.") or text:find("You start resting.") then
    pause_pickup_alert = true
  elseif text:find("Done exploring.") or text:find("Partly explored") then
    local all_alerts = ""
    for v in iter.invent_iterator:new(level_alerts) do
      if all_alerts == "" then all_alerts = v
      else all_alerts = all_alerts..", "..v
      end
    end

    level_alerts = {}
    if all_alerts ~= "" then
      crawl.mpr("<magenta>Recent alerts: "..all_alerts.."</magenta>")
    end
  end
end

function ready_item_alerts()
  if you.turns() == last_ready_item_alerts_turn then return end
  last_ready_item_alerts_turn = you.turns()

  if not pause_pickup_alert then
    generate_inv_weap_arrays()
    update_high_scores(items.equipped_at("armour"))
  else
    pause_pickup_alert = false
  end
end


---- Autopickup main ----
add_autopickup_func(function (it, _)
  if pause_pickup_alert then return end

  -- Check for pickup
  local retVal = false
  if is_armour(it) and loaded_pa_armour and CONFIG.pickup_armour then
    retVal = pickup_armour(it)
  elseif is_weapon(it) and loaded_pa_weapons and CONFIG.pickup_weapons then
    retVal = pickup_weapons(it)
  elseif is_staff(it) and loaded_pa_misc and CONFIG.pickup_misc then
    retVal = pickup_staff(it)
  end

  if retVal == true then
    remove_from_rare_items(it)
    return true
  end

  -- Update inventory high scores before alerting; in case XP gained same turn item is dropped
  if CONFIG.item_alerts then ready_item_alerts() end

  -- Not picking up this item. Check for alerts
  if loaded_pa_misc and CONFIG.misc_alerts then
    alert_rare_items(it)
    if is_staff(it) then alert_staff(it) end
  end

  if is_orb(it) and loaded_pa_misc and CONFIG.alert_misc then alert_orb(it)
  elseif is_armour(it) and loaded_pa_armour and CONFIG.alert_armour then alert_armour(it)
  elseif is_weapon(it) and loaded_pa_weapons and CONFIG.alert_weapons then alert_weapons(it)
  end
end)
