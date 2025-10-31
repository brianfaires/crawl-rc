--[[
Feature: pickup-alert-data
Description: Data management and persistent storage for the pickup-alert system
Author: buehler
Dependencies: core/constants.lua, core/data.lua, core/util.lua, pa-config.lua
--]]

f_pa_data = {}

---- Persistent variables ----
pa_items_alerted = BRC.Data.persist("pa_items_alerted", {})
pa_recent_alerts = BRC.Data.persist("pa_recent_alerts", {})
pa_OTA_items = BRC.Data.persist("pa_OTA_items", f_pickup_alert.Config.Alert.one_time)
pa_high_score = BRC.Data.persist("pa_high_score", { ac = 0, weapon = 0, plain_dmg = 0 })
pa_egos_alerted = BRC.Data.persist("pa_egos_alerted", {})

---- Local functions ----
local function get_pa_keys(it, use_plain_name)
  if it.class(true) == "bauble" then
    return it.name("qual"):gsub('"', ""), 0
  elseif BRC.it.is_talisman(it) or BRC.it.is_orb(it) then
    return it.name():gsub('"', ""), 0
  elseif BRC.it.is_magic_staff(it) then
    return it.name("base"):gsub('"', ""), 0
  else
    local name = it.name(use_plain_name and "plain" or "base"):gsub('"', "")
    local value = tonumber(name:sub(1, 3))
    if not value then return name, 0 end
    return util.trim(name:sub(4)), value
  end
end

---- Public API ----
function f_pa_data.already_alerted(it)
  local name, value = get_pa_keys(it)
  if pa_items_alerted[name] ~= nil and tonumber(pa_items_alerted[name]) >= value then
    return name
  end
end

function f_pa_data.remember_alert(it)
  if not (it.is_weapon or BRC.it.is_armour(it, true) or BRC.it.is_talisman(it)) then return end
  local name, value = get_pa_keys(it)
  local cur_val = tonumber(pa_items_alerted[name])
  if not cur_val or value > cur_val then pa_items_alerted[name] = value end

  -- Add lesser versions of same item, to avoid alerting an inferior item
  if BRC.eq.get_ego(it) and not BRC.eq.is_risky(it) and not BRC.it.is_talisman(it) then
    -- Add plain unbranded version
    name = it.name("db")
    cur_val = tonumber(pa_items_alerted[name])
    if not cur_val or value > cur_val then pa_items_alerted[name] = value end

    -- For branded artefact, add the plain branded version
    local verbose_ego = it.ego(false)
    if it.artefact and verbose_ego then
      local branded_name
      if BRC.ADJECTIVE_EGOS[verbose_ego] then
        branded_name = BRC.ADJECTIVE_EGOS[verbose_ego] .. " " .. name
      else
        branded_name = name .. " of " .. verbose_ego
      end
      cur_val = tonumber(pa_items_alerted[name])
      if not cur_val or value > cur_val then pa_items_alerted[branded_name] = value end
    end

    -- Armour may hit multiple egos based on artefact properties. Add each plain branded version.
    if it.artefact and BRC.it.is_armour(it) then
      for k, v in pairs(it.artprops) do
        if v > 0 and BRC.ARTPROPS_EGO[k] then
          local branded_name = name .. " of " .. BRC.ARTPROPS_EGO[k]
          cur_val = tonumber(pa_items_alerted[branded_name])
          if not cur_val or value > cur_val then pa_items_alerted[branded_name] = value end
        end
      end
    end
  end
end

function f_pa_data.forget_alert(it)
  local name, _ = get_pa_keys(it)
  pa_items_alerted[name] = nil
end

function f_pa_data.add_recent_alert(it)
  if it.is_weapon or BRC.it.is_armour(it, true) or BRC.it.is_talisman(it) then
    pa_recent_alerts[#pa_recent_alerts + 1] = f_pa_data.get_keyname(it)
  end
end

function f_pa_data.remove_recent_alert(it)
  util.remove(pa_recent_alerts, f_pa_data.get_keyname(it))
end

function f_pa_data.find_OTA(it)
  local qualname = it.name("qual")
  for _, v in ipairs(pa_OTA_items) do
    if v and qualname:find(v) then return v end
  end
end

function f_pa_data.remove_OTA(it)
  repeat
    local item_name = f_pa_data.find_OTA(it)
    if item_name == nil then return end
    util.remove(pa_OTA_items, item_name)
  until item_name == nil
end

--- Return name with plus included and quotes removed; used as key in tables
function f_pa_data.get_keyname(it, use_plain_name)
  local name, value = get_pa_keys(it, use_plain_name)
  if not (BRC.it.is_armour(it) or it.is_weapon) then return name end
  if value >= 0 then value = string.format("+%s", value) end
  return string.format("%s %s", value, name)
end

--- Return string of the high score type if item sets a new high score, else nil
function f_pa_data.update_high_scores(it)
  if not it then return end
  local ret_val = nil

  if BRC.it.is_armour(it) then
    local ac = BRC.eq.get_ac(it)
    if ac > pa_high_score.ac then
      pa_high_score.ac = ac
      if not ret_val then ret_val = "Highest AC" end
    end
  elseif it.is_weapon then
    -- Don't alert for unusable weapons
    if BRC.eq.get_hands(it) == 2 and not BRC.you.free_offhand() then return end

    local dmg = BRC.eq.get_dmg(it, BRC.DMG_TYPE.branded)
    if dmg > pa_high_score.weapon then
      pa_high_score.weapon = dmg
      if not ret_val then ret_val = "Highest damage" end
    end

    dmg = BRC.eq.get_dmg(it, BRC.DMG_TYPE.plain)
    if dmg > pa_high_score.plain_dmg then
      pa_high_score.plain_dmg = dmg
      if not ret_val then ret_val = "Highest plain damage" end
    end
  end

  return ret_val
end
