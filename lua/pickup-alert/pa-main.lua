if loaded_pa_main then return end
loaded_pa_main = true
loadfile("lua/cache.lua")
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-data.lua")

-- Global var for access by autopickup function
pause_pickup_alert_sys = false
local last_ready_item_alerts_turn = 0
local last_pa_dump_turn = 0

function pa_alert_item(it, alert_type, emoji)
  local name = it.name("plain")
  local qualname = it.name("qual")
  if not (is_talisman(it) or it.is_identified) then
    name = "+0 " .. name
    qualname = "+0 " .. qualname
  end

  if not pa_previously_alerted(it) and not pa_previously_picked(it) then
    if is_weapon(it) or is_staff(it) then
      pa_show_alert_msg(
        table.concat({"Item alert, ", alert_type, ": "}),
        table.concat({name, " ", get_weapon_info_string(it)}),
        emoji or CACHE.EMOJI.WEAPON
      )
	  elseif is_body_armour(it) then
      local ac, ev = get_armour_info_strings(it)
      pa_show_alert_msg(
        table.concat({"Item alert, ", alert_type, ": "}),
        table.concat({name, " ", ac, ", ", ev}),
        emoji or CACHE.EMOJI.BODY_ARMOUR
      )
    elseif is_armour(it) then
      pa_show_alert_msg(
        table.concat({"Item alert, ", alert_type, ": "}),
        name,
        emoji or CACHE.EMOJI.ARMOUR
      )
    else
      pa_show_alert_msg(
        table.concat({"Item alert, ", alert_type, ": "}),
        name,
        emoji or CACHE.EMOJI.MISC
      )
    end

    insert_item_and_less_enchanted(pa_items_alerted, it)
    table.insert(pa_all_level_alerts, name)
  end

  -- Returns true to make other code more concise; indicates that we tried to alert this item
  return true
end
crawl.setopt("runrest_stop_message += Item alert, ")


local function dump_table(name, table)
  local summary = ""
  summary = summary .. name .. ":\n"
  for _,item in ipairs(table) do
    summary = summary .. "  " .. item .. "\n"
  end
  return summary
end


local function dump_persistent_arrays()
  local summary = "---DEBUGGING ARRAYS---\n"
  summary = summary .. dump_table("pa_items_picked", pa_items_picked)
  summary = summary .. dump_table("pa_items_alerted", pa_items_alerted)
  summary = summary .. dump_table("pa_all_level_alerts", pa_all_level_alerts)
  summary = summary .. dump_table("pa_single_alert_items", pa_single_alert_items)
  
  crawl.mpr(summary)
  crawl.take_note(summary)
  crawl.dump_char()
end


------------------- Hooks -------------------
function c_assign_invletter_item_alerts(it)
  if is_weapon(it) or is_armour(it) then
    if not pa_previously_picked(it) then
      insert_item_and_less_enchanted(pa_items_picked, it)
      update_high_scores(it)
      remove_from_pa_single_alert_items(it)
    end
  end

  remove_item_and_less_enchanted(pa_items_alerted, it)
  util.remove(pa_all_level_alerts, it.name("qual"))
end

function c_message_item_alerts(text, _)
  if text:find("You start waiting.") or text:find("You start resting.") then
    pause_pickup_alert_sys = true
  elseif text:find("Done exploring.") or text:find("Partly explored") then
    local all_alerts = ""
    for _,v in ipairs(pa_all_level_alerts) do
      if all_alerts == "" then all_alerts = v
      else all_alerts = all_alerts..", "..v
      end
    end

    pa_all_level_alerts = {}
    if all_alerts ~= "" then
      crawl.mpr("<magenta>Recent alerts: "..all_alerts.."</magenta>")
    end
  end
end

function ready_item_alerts()
  if CACHE.turn == last_ready_item_alerts_turn then return end
  last_ready_item_alerts_turn = CACHE.turn

  if CONFIG.debug_pa_array_freq > 0 and CACHE.turn - last_pa_dump_turn > CONFIG.debug_pa_array_freq then
    last_pa_dump_turn = CACHE.turn
    dump_persistent_arrays()
  end

  if not pause_pickup_alert_sys then
    generate_inv_weap_arrays()
    update_high_scores(items.equipped_at("armour"))
  else
    pause_pickup_alert_sys = false
  end
end


---- Autopickup main ----
add_autopickup_func(function (it, _)
  if pause_pickup_alert_sys then return end

  -- Check for pickup
  local retVal = false
  if loaded_pa_armour and CONFIG.pickup_armour and is_armour(it) then
    retVal = pa_pickup_armour(it)
  elseif loaded_pa_weapons and CONFIG.pickup_weapons and is_weapon(it) then
    retVal = do_pa_weapon_pickup(it)
  elseif loaded_pa_misc and CONFIG.pickup_staves and is_staff(it) then
    retVal = pa_pickup_staff(it)
  end

  if retVal == true then
    remove_from_pa_single_alert_items(it)
    return true
  end

  if CONFIG.alert_system_enabled then
    -- Not picking up this item. Check for alerts.
    -- Update inventory high scores first, in case XP gained same turn item is dropped
    ready_item_alerts()

    if loaded_pa_misc then
      if CONFIG.alert_one_time_items then pa_alert_rare_item(it) end

      if is_staff(it) and CONFIG.alert_staff_resists then pa_alert_staff(it)
      elseif is_orb(it) and CONFIG.alert_orbs then pa_alert_orb(it)
      elseif is_talisman(it) and CONFIG.alert_talismans then pa_alert_talisman(it)
      end
    end

    if is_armour(it) and loaded_pa_armour and CONFIG.alert_armour then pa_alert_armour(it)
    elseif is_weapon(it) and loaded_pa_weapons and CONFIG.alert_weapons then do_pa_weapon_alerts(it)
    end
  end
end)
