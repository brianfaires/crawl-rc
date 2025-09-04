--[[
Feature: pickup-alert-data
Description: Data management and persistent storage for the pickup-alert system
Author: buehler
Dependencies: CONFIG, create_persistent_data, iter
--]]

f_pa_data = {}
--f_pa_data.BRC_FEATURE_NAME = "pickup-alert-data"

-- Persistent variables
pa_OTA_items = BRC.data.create("pa_OTA_items", CONFIG.alert.one_time)
pa_recent_alerts = BRC.data.create("pa_recent_alerts", {})
pa_items_picked = BRC.data.create("pa_items_picked", {})
pa_items_alerted = BRC.data.create("pa_items_alerted", {})

ac_high_score = BRC.data.create("ac_high_score", 0)
weapon_high_score = BRC.data.create("weapon_high_score", 0)
plain_dmg_high_score = BRC.data.create("plain_dmg_high_score", 0)

---- Helpers for using persistent tables in pickup-alert system----
function f_pa_data.append(table_ref, it)
  if it.is_weapon or BRC.is.armour(it, true) or BRC.is.talisman(it) then
    local name, value = f_pa_data.get_keys(it)
    local cur_val = tonumber(table_ref[name])
    if not cur_val or value > cur_val then table_ref[name] = value end
  end
end

function f_pa_data.contains(table_ref, it)
  local name, value = f_pa_data.get_keys(it)
  return table_ref[name] ~= nil and tonumber(table_ref[name]) >= value
end

function f_pa_data.get_keys(it, name_type)
  if it.class(true) == "bauble" then
    return it.name("qual"):gsub('"', ""), 0
  elseif BRC.is.talisman(it) or BRC.is.orb(it) then
    return it.name():gsub('"', ""), 0
  elseif BRC.is.magic_staff(it) then
    return it.name("base"):gsub('"', ""), 0
  else
    local name = it.name(name_type or "base"):gsub('"', "")
    local value = tonumber(name:sub(1, 3))
    if not value then return name, 0 end
    return util.trim(name:sub(4)), value
  end
end

function f_pa_data.get_name(it, name_type)
  local name, value = f_pa_data.get_keys(it, name_type)
  if BRC.is.talisman(it) or BRC.is.orb(it) or BRC.is.magic_staff(it) then return name end
  if value >= 0 then value = "+" .. value end
  return value .. " " .. name
end

function f_pa_data.get_OTA_index(it)
  local qualname = it.name("qual")
  for i, v in ipairs(pa_OTA_items) do
    if v ~= "" and qualname:find(v) then return i end
  end
  return -1
end

function f_pa_data.remove_from_OTA(it)
  local found = false
  local idx
  repeat
    idx = f_pa_data.get_OTA_index(it)
    if idx ~= -1 then
      util.remove(pa_OTA_items, pa_OTA_items[idx])
      found = true
    end
  until idx == -1

  return found
end

-- Returns a string if item is a new high score, else nil
function f_pa_data.update_high_scores(it)
  if not it then return end
  local ret_val = nil

  if BRC.is.armour(it) then
    local ac = get_armour_ac(it)
    if ac > ac_high_score then
      ac_high_score = ac
      if not ret_val then ret_val = "Highest AC" end
    end
  elseif it.is_weapon then
    -- Don't alert for unusable weapons
    if get_hands(it) == 2 and not BRC.you.free_offhand() then return end

    local dmg = get_weap_damage(it, DMG_TYPE.branded)
    if dmg > weapon_high_score then
      weapon_high_score = dmg
      if not ret_val then ret_val = "Highest damage" end
    end

    dmg = get_weap_damage(it, DMG_TYPE.plain)
    if dmg > plain_dmg_high_score then
      plain_dmg_high_score = dmg
      if not ret_val then ret_val = "Highest plain damage" end
    end
  end

  return ret_val
end

-- Hook functions
function f_pa_data.init()

  -- Update alerts & tables for starting items
  for inv in iter.invent_iterator:new(items.inventory()) do
    f_pa_data.remove_from_OTA(inv)
    f_pa_data.append(pa_items_picked, inv)
  end
end
