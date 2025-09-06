--[[
Feature: pickup-alert-data
Description: Data management and persistent storage for the pickup-alert system
Author: buehler
Dependencies: CONFIG, iter
--]]

f_pa_data = {}
--f_pa_data.BRC_FEATURE_NAME = "pickup-alert-data"

-- Persistent variables
pa_items_picked = BRC.data.persist("pa_items_picked", {})
pa_items_alerted = BRC.data.persist("pa_items_alerted", {})
pa_recent_alerts = BRC.data.persist("pa_recent_alerts", {})
pa_OTA_items = BRC.data.persist("pa_OTA_items", BRC.Config.alert.one_time)
pa_high_score = BRC.data.persist("pa_high_score", { ac = 0, weapon = 0, plain_dmg = 0 })

-- Local functions
local function get_pa_keys(it, plain_name)
  if it.class(true) == "bauble" then
    return it.name("qual"):gsub('"', ""), 0
  elseif BRC.is.talisman(it) or BRC.is.orb(it) then
    return it.name():gsub('"', ""), 0
  elseif BRC.is.magic_staff(it) then
    return it.name("base"):gsub('"', ""), 0
  else
    local name = it.name(plain_name and "plain" or "base"):gsub('"', "")
    local value = tonumber(name:sub(1, 3))
    if not value then return name, 0 end
    return util.trim(name:sub(4)), value
  end
end

-- Public API
-- Return name of first entry found in item name, or nil if not found
function f_pa_data.find(table_ref, it)
  if table_ref == pa_OTA_items then
    local qualname = it.name("qual")
    for _, v in ipairs(pa_OTA_items) do
      if v ~= "" and qualname:find(v) then return v end
    end
  else
    local name, value = get_pa_keys(it)
    if table_ref[name] ~= nil and tonumber(table_ref[name]) >= value then
      return name
    end
  end
end


function f_pa_data.insert(table_ref, it)
  if table_ref == pa_recent_alerts then
    pa_recent_alerts[#pa_recent_alerts+1] = f_pa_data.get_keyname(it)
  elseif it.is_weapon or BRC.is.armour(it, true) or BRC.is.talisman(it) then
    local name, value = get_pa_keys(it)
    local cur_val = tonumber(table_ref[name])
    if not cur_val or value > cur_val then table_ref[name] = value end
  end
end

function f_pa_data.remove(table_ref, it)
  if table_ref == pa_OTA_items then
    repeat
      local item_name = f_pa_data.find(pa_OTA_items, it)
      if item_name == nil then return end
      util.remove(pa_OTA_items, item_name)
    until item_name == nil
  elseif table_ref == pa_recent_alerts then
    util.remove(pa_recent_alerts, f_pa_data.get_keyname(it))
  else
    local name, _ = get_pa_keys(it)
    util.remove(table_ref, name)
  end
end

-- Get name with plus included and quotes removed; stored in pa_recent_alerts table
function f_pa_data.get_keyname(it, plain_name)
  local name, value = get_pa_keys(it, plain_name)
  if BRC.is.talisman(it) or BRC.is.orb(it) or BRC.is.magic_staff(it) then return name end
  if value >= 0 then value = "+" .. value end
  return value .. " " .. name
end

-- Returns a string of the high score type if item sets a new high score, else nil
function f_pa_data.update_high_scores(it)
  if not it then return end
  local ret_val = nil

  if BRC.is.armour(it) then
    local ac = BRC.get.armour_ac(it)
    if ac > pa_high_score.ac then
      pa_high_score.ac = ac
      if not ret_val then ret_val = "Highest AC" end
    end
  elseif it.is_weapon then
    -- Don't alert for unusable weapons
    if BRC.get.hands(it) == 2 and not BRC.you.free_offhand() then return end

    local dmg = BRC.get.weap_damage(it, BRC.DMG_TYPE.branded)
    if dmg > pa_high_score.weapon then
      pa_high_score.weapon = dmg
      if not ret_val then ret_val = "Highest damage" end
    end

    dmg = BRC.get.weap_damage(it, BRC.DMG_TYPE.plain)
    if dmg > pa_high_score.plain_dmg then
      pa_high_score.plain_dmg = dmg
      if not ret_val then ret_val = "Highest plain damage" end
    end
  end

  return ret_val
end

-- Hook functions
function f_pa_data.init()

  -- Update alerts & tables for starting items
  for inv in iter.invent_iterator:new(items.inventory()) do
    f_pa_data.remove(pa_OTA_items, inv)
    f_pa_data.insert(pa_items_picked, inv)
  end
end
