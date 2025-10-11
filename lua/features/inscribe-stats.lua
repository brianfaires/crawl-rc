--[[
Feature: inscribe-stats
Description: Automatically inscribes+updates weapon DPS/dmg/delay, or armour AC/EV/SH, on items in inventory
Author: buehler
Dependencies: core/constants.lua, core/util.lua
--]]

f_inscribe_stats = {}
f_inscribe_stats.BRC_FEATURE_NAME = "inscribe-stats"
f_inscribe_stats.Config = {
  inscribe_weapons = true, -- Inscribe weapon stats on pickup
  inscribe_armour = true, -- Inscribe armour stats on pickup
  inscribe_dps_type = BRC.DMG_TYPE.plain,
} -- f_inscribe_stats.Config (do not remove this comment)

---- Local config alias ----
local Config = f_inscribe_stats.Config

---- Local constants / configuration ----
local NUM_PATTERN = "[%+%-:]%d+%.%d*" -- Matches numbers w/ decimal

---- Local functions ----
local function inscribe_armour_stats(it)
  local abbr = BRC.is.shield(it) and "SH" or "AC"
  local ac_or_sh, ev = BRC.get.armour_stats(it)

  local new_insc
  if it.inscription:find(abbr .. NUM_PATTERN) then
    -- Replace each stat individually, to avoid overwriting <color> tags
    new_insc = it.inscription:gsub(abbr .. NUM_PATTERN, ac_or_sh)
    if ev and ev ~= "" then new_insc = new_insc:gsub("EV" .. NUM_PATTERN, ev) end
  else
    new_insc = ac_or_sh
    if ev and ev ~= "" then new_insc = string.format("%s, %s", new_insc, ev) end
    if it.inscription and it.inscription ~= "" then new_insc = string.format("%s; %s", new_insc, it.inscription) end
  end

  it.inscribe(new_insc, false)
end

local function inscribe_weapon_stats(it)
  local orig_inscr = it.inscription
  local dps_inscr = BRC.get.weapon_stats(it, BRC.DMG_TYPE[Config.inscribe_dps_type])
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

---- Hook functions ----
function f_inscribe_stats.do_stat_inscription(it)
  -- NOTE: It is important that other features do not meddle with the inscription; e.g. adding color tags
  if Config.inscribe_weapons and it.is_weapon then
    inscribe_weapon_stats(it)
  elseif Config.inscribe_armour and BRC.is.armour(it) and not BRC.is.scarf(it) then
    inscribe_armour_stats(it)
  end
end

function f_inscribe_stats.ready()
  for inv in iter.invent_iterator:new(items.inventory()) do
    f_inscribe_stats.do_stat_inscription(inv)
  end
end
