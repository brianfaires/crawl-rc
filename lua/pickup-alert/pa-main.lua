--dofile("crawl-rc/lua/pickup-alert/pa-data.lua")

function alert_item(it, alert_type)
  local name = it.name("plain")
  if not it.is_identified then name = "+0 " .. name end

  if not previously_alerted(it) and not previously_picked(it) then
    if is_weapon(it) or is_staff(it) then
      show_alert_msg("Item alert, "..alert_type..": ", name.." "..get_weapon_info(it))
	elseif is_body_armour(it) then
      show_alert_msg("Item alert, "..alert_type..": ", name.." "..get_armour_info(it))
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




---------------------------------------------
------------------- Hooks -------------------
---------------------------------------------
function c_assign_invletter_item_alerts(it)
  local name = it.name("plain")
  if is_weapon(it) or is_armour(it) then
    if not previously_picked(it) then
      insert_item_and_less_enchanted(items_picked, it)
      update_high_scores(it)
      remove_from_rare_items(it)
    end
  end
  
  remove_item_and_less_enchanted(items_alerted, it)
  util.remove(level_alerts, name)
end

function c_message_item_alerts(text, channel)
  if text:find("You start waiting.") or text:find("You start resting.") then
    disable_autopickup = true
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
  update_high_scores(items.equipped_at("Armour"))
  if not disable_autopickup then
	  for it in iter.invent_iterator:new(items.inventory()) do
		if is_weapon(it) then update_high_scores(it) end
	end
  end
  
  disable_autopickup = false
end



-------------------------
---- Autopickup main ----
-------------------------
add_autopickup_func(function (it, name)
  if disable_autopickup then return end

  -- Check for pickup
  local retVal = false
  if is_armour(it) and loaded_pa_armour then retVal = pickup_armour(it)
  elseif is_weapon(it) and loaded_pa_weapons then retVal = pickup_weapons(it)
  elseif is_staff(it) and loaded_pa_misc then retVal = pickup_staff(it)
  end

  if retVal == true then
    remove_from_rare_items(it)
    return true
  end

  -- Update inventory high scores before alerting; in case XP gained same turn item is dropped
  ready_item_alerts()

  -- Not picking up this item. Check for alerts
  if loaded_pa_misc then
    alert_rare_items(it)
    if is_staff(it) then alert_staff(it) end
  end

  if is_orb(it) and loaded_pa_misc then alert_orb(it)
  elseif is_armour(it) and loaded_pa_armour then alert_armour(it)
  elseif is_weapon(it) and loaded_pa_weapons then alert_weapons(it)
  end
end)
