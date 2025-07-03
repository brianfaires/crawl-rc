---- Helpers for using persistent tables in pickup-alert system----
function add_to_pa_table(table_ref, it)
  if is_weapon(it) or is_armour(it) or is_talisman(it) or is_orb(it) then
    local name, value = get_pa_keys(it)
    local cur_val = tonumber(table_ref[name])
    if not cur_val or value > cur_val then
      table_ref[name] = value
    end
  end
end

function already_contains(table_ref, it)
  local name, value = get_pa_keys(it)
  return table_ref[name] ~= nil and tonumber(table_ref[name]) >= value
end

function init_pa_data()
  if CONFIG.debug_init then crawl.mpr("Initializing pa-data") end

  create_persistent_data("pa_OTA_items", CONFIG.one_time_alerts)
  create_persistent_data("pa_recent_alerts", {})
  create_persistent_data("pa_items_picked", {})
  create_persistent_data("pa_items_alerted", {})
  create_persistent_data("alerted_first_ranged_2h", 0)
  create_persistent_data("alerted_first_ranged_1h", 0)
  create_persistent_data("alerted_first_polearm", 0)
  create_persistent_data("ac_high_score", 0)
  create_persistent_data("weapon_high_score", 0)
  create_persistent_data("unbranded_high_score", 0)
  create_persistent_data("polearm_high_score", 0)
  create_persistent_data("polearm_1h_high_score", 0)

  -- Update alerts & tables for starting items
  for inv in iter.invent_iterator:new(items.inventory()) do
    remove_from_OTA(inv)
    add_to_pa_table(pa_items_picked, inv)

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

function get_OTA_index(it)
  local qualname = it.name("qual")
  for i,v in ipairs(pa_OTA_items) do
    if v ~= "" and qualname:find(v) then return i end
  end
  return -1
end

function remove_from_OTA(it)
  local found = false
  local idx
  repeat
    idx = get_OTA_index(it)
    if idx ~= -1 then
      util.remove(pa_OTA_items, pa_OTA_items[idx])
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
    if ac > ac_high_score then
      ac_high_score = ac
      if not ret_val then ret_val = "Strongest armour" end
    end
  elseif is_weapon(it) then
    local it_plus = it.plus or 0
    local score = it.score or get_weap_score(it)
    if score > weapon_high_score then
      weapon_high_score = score
      if not ret_val then ret_val = "Good weapon" end
    end

    if score > unbranded_high_score then
      local unbranded_score = it.unbranded_score or get_weap_score(it, true)
      if unbranded_score > unbranded_high_score then
        unbranded_high_score = score
        if not ret_val then ret_val = "High pure damage" end
      end
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
