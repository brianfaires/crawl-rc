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
local PA_UNIQUE_TAG = "beuhler-PA-tag"
if CONFIG.alert_force_more then
  crawl.setopt("force_more_message += " .. PA_UNIQUE_TAG)
end
if CONFIG.alert_flash_screen then
  -- This doesn't seem to work; maybee because it gets written during autopickup hook?
  crawl.setopt("flash_screen_message += " .. PA_UNIQUE_TAG)
end

function pa_alert_item(it, alert_type, emoji)
  local item_name = get_plussed_name(it)
  if util.contains(pa_items_picked, item_name) then return false end
  if util.contains(pa_items_alerted, item_name) then return false end

  you.stop_activity()

  if is_weapon(it) or is_staff(it) then
    item_name = table.concat({item_name, " ", get_weapon_info_string(it)})
  elseif is_body_armour(it) then
    local ac, ev = get_armour_info_strings(it)
    item_name = table.concat({item_name, " ", ac, ", ", ev})
  end
  local tokens = {}
  tokens[1] = emoji and emoji or "<cyan>----"
  tokens[#tokens+1] = " <magenta>" .. alert_type .. ": </magenta>"
  tokens[#tokens+1] = "<yellow>" .. item_name .. " </yellow>"
  tokens[#tokens+1] = emoji and emoji or "----</cyan>"
  tokens[#tokens+1] = "<black>" .. PA_UNIQUE_TAG .. "</black>"
  crawl.mpr(table.concat(tokens))

  pa_all_level_alerts[#pa_all_level_alerts+1] = item_name
  insert_item_and_less_enchanted(pa_items_alerted, it)
  return true
end


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
    if not util.contains(pa_items_picked, get_plussed_name(it)) then
      insert_item_and_less_enchanted(pa_items_picked, it)
      update_high_scores(it)
      remove_from_pa_single_alert_items(it)
    end
  end

  remove_item_and_less_enchanted(pa_items_alerted, it)
  util.remove(pa_all_level_alerts, get_plussed_name(it))
end

function c_message_item_alerts(text, _)
  if text:find("You start waiting.") or text:find("You start resting.") then
    pause_pickup_alert_sys = true
  elseif text:find("Done exploring.") or text:find("Partly explored") then
    local tokens = {}
    for _,v in ipairs(pa_all_level_alerts) do
      tokens[#tokens+1] = "\n  " .. v
    end
    if #tokens > 0 then
      crawl.mpr("<magenta>Recent alerts:" .. table.concat(tokens) .. "</magenta>")
    end
    pa_all_level_alerts = {}
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

  -- Not picking up this item. Check for alerts.
  -- Update inventory high scores first, in case XP gained same turn item is dropped
  if not CONFIG.alert_system_enabled then return end
  ready_item_alerts()

  if loaded_pa_misc and CONFIG.alert_one_time_items then
    if pa_alert_rare_item(it) then return end
  end

  if loaded_pa_misc and CONFIG.alert_staff_resists and is_staff(it) then
    if pa_alert_staff(it) then return end
  elseif loaded_pa_misc and CONFIG.alert_orbs and is_orb(it) then
    if pa_alert_orb(it) then return end
  elseif loaded_pa_misc and CONFIG.alert_talismans and is_talisman(it) then
    if pa_alert_talisman(it) then return end
  elseif loaded_pa_armour and CONFIG.alert_armour and is_armour(it) then
    if pa_alert_armour(it) then return end
  elseif loaded_pa_weapons and CONFIG.alert_weapons and is_weapon(it) then
    if do_pa_weapon_alerts(it) then return end
  end
end)
