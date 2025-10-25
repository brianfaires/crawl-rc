--[[
Feature: inscribe-stats
Description: Inscribes+updates weapon DPS/dmg/delay, or armour AC/EV/SH, on items in inventory
Author: buehler
Dependencies: core/constants.lua, core/util.lua, color-inscribe.lua
--]]

f_inscribe_stats = {}
f_inscribe_stats.BRC_FEATURE_NAME = "inscribe-stats"
f_inscribe_stats.Config = {
  inscribe_weapons = true, -- Inscribe weapon stats on pickup
  inscribe_armour = true, -- Inscribe armour stats on pickup
  dmg_type = BRC.DMG_TYPE.unbranded,
} -- f_inscribe_stats.Config (do not remove this comment)

---- Local config alias ----
local Config = f_inscribe_stats.Config

---- Local constants / configuration ----
local NUM_PATTERN = "[%+%-:]%d+%.%d*" -- Matches numbers w/ decimal

---- Local functions ----
local function inscribe_armour_stats(it)
  local abbr = BRC.it.is_shield(it) and "SH" or "AC"
  local ac_or_sh, ev = BRC.eq.arm_stats(it)
  local sign_change = false

  local new_insc
  if it.inscription:find(abbr .. NUM_PATTERN) then
    new_insc = it.inscription:gsub(abbr .. NUM_PATTERN, ac_or_sh)
    if not it.inscription:contains(ac_or_sh:sub(1, 3)) then sign_change = true end

    if ev and ev ~= "" then
      new_insc = new_insc:gsub("EV" .. NUM_PATTERN, ev)
      if not it.inscription:contains(ev:sub(1, 3)) then sign_change = true end
    end
  else
    new_insc = ac_or_sh
    if ev and ev ~= "" then new_insc = string.format("%s, %s", new_insc, ev) end
    if it.inscription and it.inscription ~= "" then
      new_insc = string.format("%s; %s", new_insc, it.inscription)
    end
  end

  it.inscribe(new_insc, false)

  -- If f_color_inscribe is enabled, update the color
  if
    sign_change
    and f_color_inscribe
    and f_color_inscribe.Config
    and not f_color_inscribe.Config.disabled
    and f_color_inscribe.colorize
  then
    f_color_inscribe.colorize(it)
  end
end

local function inscribe_weapon_stats(it)
  local orig_inscr = it.inscription
  local dps_inscr = BRC.eq.wpn_stats(it, BRC.DMG_TYPE[Config.dmg_type])
  local prefix, suffix = "", ""

  local idx = orig_inscr:find("DPS:", 1, true)
  if idx then
    if idx > 1 then prefix = orig_inscr:sub(1, idx - 1) .. "; " end
    if idx + #dps_inscr - 1 < #orig_inscr then
      suffix = orig_inscr:sub(idx + #dps_inscr, #orig_inscr)
    end
  elseif #orig_inscr > 0 then
    suffix = "; " .. orig_inscr
  end

  it.inscribe(table.concat({ prefix, dps_inscr, suffix }), false)
end

---- Hook functions ----
function f_inscribe_stats.do_stat_inscription(it)
  if Config.inscribe_weapons and it.is_weapon then
    inscribe_weapon_stats(it)
  elseif Config.inscribe_armour and BRC.it.is_armour(it) and not BRC.it.is_scarf(it) then
    inscribe_armour_stats(it)
  end
end

function f_inscribe_stats.ready()
  for _, inv in ipairs(items.inventory()) do
    f_inscribe_stats.do_stat_inscription(inv)
  end
end
