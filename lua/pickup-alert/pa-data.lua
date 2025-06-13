if loaded_pa_data then return end
loaded_pa_data = true
loadfile("crawl-rc/lua/util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-util.lua")

create_persistent_data("pa_single_alert_items", CONFIG.one_time_alerts)
create_persistent_data("pa_all_level_alerts", {})
create_persistent_data("pa_items_picked", {})
create_persistent_data("pa_items_alerted", {})
create_persistent_data("alerted_first_ranged_two_handed", 0)
create_persistent_data("alerted_first_ranged_one_handed", 0)
create_persistent_data("armour_high_score", 0)
create_persistent_data("weapon_high_score", 0)
create_persistent_data("unbranded_high_score", 0)
create_persistent_data("polearm_high_score", 0)
create_persistent_data("polearm_onehand_high_score", 0)


---- Accessors into persistent data ----
function get_rare_item_index(it)
  local qualname = it.name("qual")
  for i,v in ipairs(pa_single_alert_items) do
    if v ~= "" and qualname:find(v) then return i end
  end
  return -1
end

function remove_from_pa_single_alert_items(it)
  local idx = get_rare_item_index(it)
  if idx ~= -1 then
    util.remove(pa_single_alert_items, pa_single_alert_items[idx])
    return true
  end

  return false
end

function pa_previously_picked(it)
  local name = it.name("qual")
  if not it.is_identified then name = "+0 " .. name end
  return util.contains(pa_items_picked, name)
end

function pa_previously_alerted(it)
  local name = it.name("qual")
  if not it.is_identified then name = "+0 " .. name end
  return util.contains(pa_items_alerted, name)
end

--- Multi store/remove data ---
local function add_remove_item_and_less_enchanted(table_ref, it, remove_item)
  -- Add (or remove) an item name to a table, along with all less enchanted versions
  -- e.g. "+3 flail" will add: "+3 flail", "+2 flail", "+1 flail", "+0 flail"
  local name = it.name("qual")
  if not it.is_identified then name = "+0 " .. name end
  if util.contains(table_ref, name) ~= remove_item then return end

  if remove_item then util.remove(table_ref, name)
  else table.insert(table_ref, name)
  end

  if it.artefact then return end

  -- Do less enchanted items too
  local plus = tonumber(name:sub(2,2))
  if not plus then return end

  if plus > 0 then
    if tonumber(name:sub(3,3)) then
      plus = 10 * plus + tonumber(name:sub(3,3))
    end

    for i=plus,1,-1 do
      name = name:gsub("+" .. i, "+" .. (i-1))
      if remove_item then util.remove(table_ref, name)
      else table.insert(table_ref, name)
      end
    end
  end
end

function insert_item_and_less_enchanted(table_ref, it)
  add_remove_item_and_less_enchanted(table_ref, it, false)
end

function remove_item_and_less_enchanted(table_ref, it)
  add_remove_item_and_less_enchanted(table_ref, it, true)
end


--- Set all single high scores ---
function update_high_scores(it)
  local ret_val = nil

  if is_armour(it) then
    local ac = get_armour_ac(it)
    if ac > armour_high_score then
      armour_high_score = ac
      if not ret_val then ret_val = "Strongest armour" end
    end
  elseif is_weapon(it) then
    local it_plus = if_el(it.plus, it.plus, 0)
    local score = get_weap_dps(it) + (it.accuracy + it_plus) / 2
    if score > weapon_high_score then
      weapon_high_score = score
      if not ret_val then ret_val = "Good weapon" end
    end

    local unbranded_score = get_weap_dps(it, false) + (it.accuracy + it_plus) / 2
    if unbranded_score > unbranded_high_score then
      unbranded_high_score = score
      if not ret_val then ret_val = "High pure damage" end
    end

    if it.weap_skill == "Polearms" and you_have_allies() then
      if score > polearm_high_score then
        polearm_high_score = score
        if not have_shield() and not ret_val then ret_val = "Good polearm" end
      end

      if get_hands(it) == 1 and score > polearm_onehand_high_score then
        polearm_onehand_high_score = score
        if not ret_val then ret_val = "Good polearm" end
      end
    end
  end

  return ret_val
end


--- Startup code ---
-- Starting items: Remove from pa_single_alert_items, and add to pa_items_picked
if you.turns() == 0 then
  for inv in iter.invent_iterator:new(items.inventory()) do
    local idx = get_rare_item_index(inv)
    if idx ~= -1 then util.remove(pa_single_alert_items, pa_single_alert_items[idx]) end
    insert_item_and_less_enchanted(pa_items_picked, inv)
  end
end
