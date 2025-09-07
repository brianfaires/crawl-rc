--[[
Feature: color-inscribe
Description: Colorizes inscriptions on items with appropriate colors for resistances, stats, and other properties
Author: buehler
Dependencies: core/config.lua, core/constants.lua
--]]

f_color_inscribe = {}
f_color_inscribe.BRC_FEATURE_NAME = "color-inscribe"

-- Local constants / configuration
local MULTI_PLUS = "%++"
local MULTI_MINUS = "%-+"
local NEG_NUM = "%-%d+%.?%d*"
local POS_NUM = "%+%d+%.?%d*"
local COLORIZE_TAGS = {
  { "rF" .. MULTI_PLUS, BRC.COLORS.lightred },
  { "rF" .. MULTI_MINUS, BRC.COLORS.red },
  { "rC" .. MULTI_PLUS, BRC.COLORS.lightblue },
  { "rC" .. MULTI_MINUS, BRC.COLORS.blue },
  { "rN" .. MULTI_PLUS, BRC.COLORS.lightmagenta },
  { "rN" .. MULTI_MINUS, BRC.COLORS.magenta },
  { "rPois", BRC.COLORS.lightgreen },
  { "rElec", BRC.COLORS.lightcyan },
  { "rCorr", BRC.COLORS.yellow },
  { "rMut", BRC.COLORS.brown },
  { "sInv", BRC.COLORS.white },
  { "MRegen" .. MULTI_PLUS, BRC.COLORS.cyan },
  { "Regen" .. MULTI_PLUS, BRC.COLORS.green },
  { "Stlth" .. MULTI_PLUS, BRC.COLORS.white },
  { "Will" .. MULTI_PLUS, BRC.COLORS.brown },
  { "Will" .. MULTI_MINUS, BRC.COLORS.darkgrey },
  { "Wiz" .. MULTI_PLUS, BRC.COLORS.white },
  { "Wiz" .. MULTI_MINUS, BRC.COLORS.darkgrey },
  { "Slay" .. POS_NUM, BRC.COLORS.white },
  { "Slay" .. NEG_NUM, BRC.COLORS.darkgrey },
  { "Str" .. POS_NUM, BRC.COLORS.white },
  { "Str" .. NEG_NUM, BRC.COLORS.darkgrey },
  { "Dex" .. POS_NUM, BRC.COLORS.white },
  { "Dex" .. NEG_NUM, BRC.COLORS.darkgrey },
  { "Int" .. POS_NUM, BRC.COLORS.white },
  { "Int" .. NEG_NUM, BRC.COLORS.darkgrey },
  { "AC" .. POS_NUM, BRC.COLORS.white },
  { "AC" .. NEG_NUM, BRC.COLORS.darkgrey },
  { "EV" .. POS_NUM, BRC.COLORS.white },
  { "EV" .. NEG_NUM, BRC.COLORS.darkgrey },
  { "SH" .. POS_NUM, BRC.COLORS.white },
  { "SH" .. NEG_NUM, BRC.COLORS.darkgrey },
  { "HP" .. POS_NUM, BRC.COLORS.white },
  { "HP" .. NEG_NUM, BRC.COLORS.darkgrey },
  { "MP" .. POS_NUM, BRC.COLORS.white },
  { "MP" .. NEG_NUM, BRC.COLORS.darkgrey },
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

  return text:gsub(string.format("(%s)", s), string.format("<%s>%%1</%s>", tag, tag))
end

-- Hook functions
function f_color_inscribe.c_assign_invletter(it)
  if not BRC.Config.colorize_inscriptions then return end
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
TODO: To colorize more, need a way to:
  intercept messages before they're displayed (or delete and re-insert)
  insert tags that affect menus
  colorize artefact text
function f_color_inscribe.c_message(text, _)
  local orig_text = text
  text = colorize_subtext(text)
  if text == orig_text then return end

  local cleaned = BRC.text.clean_text(text)
  if cleaned:sub(2, 4) == " - " then
    text = " " .. text
  end

  crawl.mpr(text)
end
--]]
