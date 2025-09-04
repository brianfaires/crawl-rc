--[[
Feature: color-inscribe
Description: Colorizes inscriptions on items with appropriate colors for resistances, stats, and other properties
Author: buehler
Dependencies: CONFIG, COLORS, do_stat_inscription
--]]

f_color_inscribe = {}
f_color_inscribe.BRC_FEATURE_NAME = "color-inscribe"

-- Local constants / configuration
local MULTI_PLUS = "%++"
local MULTI_MINUS = "%-+"
local NEG_NUM = "%-%d+%.?%d*"
local POS_NUM = "%+%d+%.?%d*"
local COLORIZE_TAGS = {
  { "rF" .. MULTI_PLUS, COLORS.lightred },
  { "rF" .. MULTI_MINUS, COLORS.red },
  { "rC" .. MULTI_PLUS, COLORS.lightblue },
  { "rC" .. MULTI_MINUS, COLORS.blue },
  { "rN" .. MULTI_PLUS, COLORS.lightmagenta },
  { "rN" .. MULTI_MINUS, COLORS.magenta },
  { "rPois", COLORS.lightgreen },
  { "rElec", COLORS.lightcyan },
  { "rCorr", COLORS.yellow },
  { "rMut", COLORS.brown },
  { "sInv", COLORS.white },
  { "MRegen" .. MULTI_PLUS, COLORS.cyan },
  { "Regen" .. MULTI_PLUS, COLORS.green },
  { "Stlth" .. MULTI_PLUS, COLORS.white },
  { "Will" .. MULTI_PLUS, COLORS.brown },
  { "Will" .. MULTI_MINUS, COLORS.darkgrey },
  { "Wiz" .. MULTI_PLUS, COLORS.white },
  { "Wiz" .. MULTI_MINUS, COLORS.darkgrey },
  { "Slay" .. POS_NUM, COLORS.white },
  { "Slay" .. NEG_NUM, COLORS.darkgrey },
  { "Str" .. POS_NUM, COLORS.white },
  { "Str" .. NEG_NUM, COLORS.darkgrey },
  { "Dex" .. POS_NUM, COLORS.white },
  { "Dex" .. NEG_NUM, COLORS.darkgrey },
  { "Int" .. POS_NUM, COLORS.white },
  { "Int" .. NEG_NUM, COLORS.darkgrey },
  { "AC" .. POS_NUM, COLORS.white },
  { "AC" .. NEG_NUM, COLORS.darkgrey },
  { "EV" .. POS_NUM, COLORS.white },
  { "EV" .. NEG_NUM, COLORS.darkgrey },
  { "SH" .. POS_NUM, COLORS.white },
  { "SH" .. NEG_NUM, COLORS.darkgrey },
  { "HP" .. POS_NUM, COLORS.white },
  { "HP" .. NEG_NUM, COLORS.darkgrey },
  { "MP" .. POS_NUM, COLORS.white },
  { "MP" .. NEG_NUM, COLORS.darkgrey },
}

-- Local functions
local function colorize_subtext(text, s, tag)
  local idx = text:find(s)
  if not idx then return text end
  if idx > 1 then
    -- Avoid '!r' or an existing color tag
    local prev = text:sub(idx - 1, idx - 1)
    if prev == "!" or prev == ">" then return text end
  end

  local retval = text:gsub("(" .. s .. ")", "<" .. tag .. ">%1</" .. tag .. ">")
  return retval
end

-- Hook functions
function f_color_inscribe.c_assign_invletter(it)
  if not CONFIG.colorize_inscriptions then return end
  if it.artefact then return end
  -- If enabled, call out to inscribe stats before coloring
  if do_stat_inscription then do_stat_inscription(it) end

  local text = it.inscription
  for _, tag in ipairs(COLORIZE_TAGS) do
    text = colorize_subtext(text, tag[1], tag[2])
  end

  it.inscribe(text, false)
end

--[[
To colorize more, need a way to:
  intercept messages before they're displayed (or delete and re-insert)
  insert tags that affect menus
  colorize artefact text
function f_color_inscribe.c_message(text, _)
  local orig_text = text
  text = colorize_subtext(text)
  if text == orig_text then return end

  local cleaned = BRC.util.clean_text(text)
  if cleaned:sub(2, 4) == " - " then
    text = " " .. text
  end

  crawl.mpr(text)
end
--]]
