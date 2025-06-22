---- Helpers for using persistent tables in pickup-alert system----
local function add_remove_item_and_lesser(table_ref, it, remove_item)
  -- Add (or remove) an item name to a table, along with all less enchanted versions
  -- e.g. "+3 flail" will add: "+3 flail", "+2 flail", "+1 flail", "+0 flail"
  local name = get_plussed_name(it, "base")
  if util.contains(table_ref, name) ~= remove_item then return end

  if remove_item then util.remove(table_ref, name)
  else table_ref[#table_ref+1] = name
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
      else table_ref[#table_ref+1] = name
      end
    end
  end
end


function init_pa_data()
  if CONFIG.debug_init then crawl.mpr("Initializing pa-data") end

  create_persistent_data("pa_single_alert_items", CONFIG.one_time_alerts)
  create_persistent_data("pa_all_level_alerts", {})
  create_persistent_data("pa_items_picked", {})
  create_persistent_data("pa_items_alerted", {})
  create_persistent_data("alerted_first_ranged_2h", 0)
  create_persistent_data("alerted_first_ranged_1h", 0)
  create_persistent_data("alerted_first_polearm", 0)
  create_persistent_data("armour_high_score", 0)
  create_persistent_data("weapon_high_score", 0)
  create_persistent_data("unbranded_high_score", 0)
  create_persistent_data("polearm_high_score", 0)
  create_persistent_data("polearm_1h_high_score", 0)

  -- Starting items: Remove from pa_single_alert_items, add to pa_items_picked
  -- Update alerts for first polearm/ranged]
  for inv in iter.invent_iterator:new(items.inventory()) do
    local idx = get_rare_item_index(inv)
    if idx ~= -1 then util.remove(pa_single_alert_items, pa_single_alert_items[idx]) end

    if is_weapon(inv) or is_armour(inv) or is_talisman(inv) or is_orb(inv) then
      add_item_and_lesser(pa_items_picked, inv)
    end

    if is_weapon(inv) then
      if is_polearm(inv) then
        alerted_first_polearm = 1
      elseif inv.is_ranged then
        if get_hands(inv) == 2 then
          alerted_first_ranged_2h = 1
        else
          alerted_first_ranged_1h = 1
        end
      end
    end
  end
end

function add_item_and_lesser(table_ref, it)
  add_remove_item_and_lesser(table_ref, it, false)
end

function remove_item_and_lesser(table_ref, it)
  add_remove_item_and_lesser(table_ref, it, true)
end

function get_rare_item_index(it)
  local qualname = it.name("qual")
  for i,v in ipairs(pa_single_alert_items) do
    if v ~= "" and qualname:find(v) then return i end
  end
  return -1
end

function remove_from_rare_items(it)
  local found = false
  local idx
  repeat
    idx = get_rare_item_index(it)
    if idx ~= -1 then
      util.remove(pa_single_alert_items, pa_single_alert_items[idx])
      found = true
    end
  until idx == -1

  return found
end

--- Set all single high scores ---
-- Returns a string if item is a new high score, else nil
function update_high_scores(it)
  local ret_val = nil

  if is_armour(it) then
    local ac = get_armour_ac(it)
    if ac > armour_high_score then
      armour_high_score = ac
      if not ret_val then ret_val = "Strongest armour" end
    end
  elseif is_weapon(it) then
    local it_plus = it.plus or 0
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

    if is_polearm(it) and you_have_allies() then
      if score > polearm_high_score then
        polearm_high_score = score
        if not have_shield() and not ret_val then ret_val = "Good polearm" end
      end

      if get_hands(it) == 1 and score > polearm_1h_high_score then
        polearm_1h_high_score = score
        if not ret_val then ret_val = "Good polearm" end
      end
    end
  end

  return ret_val
end
