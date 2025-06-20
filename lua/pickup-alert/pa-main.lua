if loaded_pa_main then return end
loaded_pa_main = true
loadfile("lua/cache.lua")
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-data.lua")

local last_ready_item_alerts_turn = 0

function pa_alert_item(it, alert_type, emoji)
  local item_desc = get_plussed_name(it, "plain")
  if is_weapon(it) or is_staff(it) then
    item_desc = table.concat({item_desc, " (", get_weapon_info_string(it), ")"})
  elseif is_body_armour(it) then
    local ac, ev = get_armour_info_strings(it)
    item_desc = table.concat({item_desc, " {", ac, ", ", ev, "}"})
  end
  local tokens = {}
  tokens[1] = emoji and emoji or with_color(COLORS.cyan, "----")
  tokens[#tokens+1] = with_color(COLORS.magenta, " " .. alert_type .. ": ")
  tokens[#tokens+1] = with_color(COLORS.yellow, item_desc .. " ")
  tokens[#tokens+1] = emoji and emoji or with_color(COLORS.cyan, "----")
  enqueue_mpr_opt_more(CONFIG.alert_force_more, table.concat(tokens))

  pa_all_level_alerts[#pa_all_level_alerts+1] = get_plussed_name(it, "base")
  add_item_and_lesser(pa_items_alerted, it)
  you.stop_activity()
  return true
end


------------------- Hooks -------------------
function c_assign_invletter_item_alerts(it)
  local name = get_plussed_name(it)
  if is_weapon(it) or is_armour(it) then
    if not util.contains(pa_items_picked, name) then
      add_item_and_lesser(pa_items_picked, it)
      update_high_scores(it)
      remove_from_pa_single_alert_items(it)
    end
  end

  remove_item_and_lesser(pa_items_alerted, it)
  util.remove(pa_all_level_alerts, name)
end

function c_message_item_alerts(text, channel)
  if channel ~= "plain" then return end
  if text:find("Done exploring.") or text:find("Partly explored") then
    local tokens = {}
    for _,v in ipairs(pa_all_level_alerts) do
      tokens[#tokens+1] = "\n  " .. v
    end
    if #tokens > 0 then
      enqueue_mpr(with_color(COLORS.magenta, "Recent alerts:" .. table.concat(tokens)))
    end
    pa_all_level_alerts = {}
  end
end

function ready_item_alerts()
  if CACHE.turn == last_ready_item_alerts_turn then return end
  last_ready_item_alerts_turn = CACHE.turn

  generate_inv_weap_arrays()
  update_high_scores(get_body_armour())
end


---- Autopickup main ----
add_autopickup_func(function (it, _)
  if CACHE.have_orb then return end
  local plus_name = get_plussed_name(it, "base")
  if util.contains(pa_items_picked, plus_name) then return end

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
  if not (CONFIG.alert_system_enabled and you.turn_is_over()) then return end
  if util.contains(pa_items_alerted, plus_name) then return end
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
