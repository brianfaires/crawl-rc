--[[
Feature: inscribe-stats
Description: Automatically inscribes+updates weapon DPS/dmg/delay, or armour AC/EV/SH, on items in inventory
Author: buehler
Dependencies: CONFIG, iter, pa-util, util
--]]

f_inscribe_stats = {}
f_inscribe_stats.BRC_FEATURE_NAME = "inscribe-stats"

-- Local constants / configuration
local NUM_PATTERN = "[%+%-:]%d+%.%d*" -- Matches numbers w/ decimal

-- Local functions
local function inscribe_armour_stats(it)
  local abbr = BRC.is.shield(it) and "SH" or "AC"
  local primary, ev = BRC.get.armour_info(it)

  local new_insc
  if it.inscription:find(abbr .. NUM_PATTERN) then
    -- Replace each stat individually, to avoid overwriting <color> tags
    new_insc = it.inscription:gsub(abbr .. NUM_PATTERN, primary)
    if ev and ev ~= "" then new_insc = new_insc:gsub("EV" .. NUM_PATTERN, ev) end
  else
    new_insc = primary
    if ev and ev ~= "" then new_insc = new_insc .. ", " .. ev end
    if it.inscription and it.inscription ~= "" then new_insc = new_insc .. "; " .. it.inscription end
  end

  it.inscribe(new_insc, false)
end

local function inscribe_weapon_stats(it)
  local orig_inscr = it.inscription
  local dps_inscr = BRC.get.weapon_info(it, BRC.Config.inscribe_dps_type)
  local prefix, suffix = "", ""

  local idx = orig_inscr:find("DPS:", 1, true)
  if idx then
    if idx > 1 then prefix = orig_inscr:sub(1, idx - 1) .. "; " end
    if idx + #dps_inscr - 1 < #orig_inscr then suffix = orig_inscr:sub(idx + #dps_inscr, #orig_inscr) end
  elseif #orig_inscr > 0 then
    suffix = "; " .. orig_inscr
  end

  it.inscribe(table.concat({ prefix, dps_inscr, suffix }), false)
end

-- Hook functions
function do_stat_inscription(it)
  if BRC.Config.inscribe_weapons and it.is_weapon then
    inscribe_weapon_stats(it)
  elseif BRC.Config.inscribe_armour and BRC.is.armour(it) and not BRC.is.scarf(it) then
    inscribe_armour_stats(it)
  end
end

-- Hook functions
function f_inscribe_stats.ready()
  for inv in iter.invent_iterator:new(items.inventory()) do
    do_stat_inscription(inv)
  end
end
