--[[
Feature: color-inscribe
Description: Colorizes inscriptions on items with appropriate colors for resistances, stats, and other properties
Author: buehler
Dependencies: core/constants.lua
--]]

f_color_inscribe = {}
f_color_inscribe.BRC_FEATURE_NAME = "color-inscribe"

-- Local constants / configuration
local negative_color = BRC.COLORS.brown
local positive_color = BRC.COLORS.white
local MULTI_PLUS = "%++"
local MULTI_MINUS = "%-+"
local NEG_NUM = "%-%d+%.?%d*"
local POS_NUM = "%+%d+%.?%d*"
local COLORIZE_TAGS = {
  { "rF" .. MULTI_PLUS, BRC.COLORS.lightred },
  { "rF" .. MULTI_MINUS, negative_color },
  { "rC" .. MULTI_PLUS, BRC.COLORS.lightblue },
  { "rC" .. MULTI_MINUS, negative_color },
  { "rN" .. MULTI_PLUS, BRC.COLORS.lightmagenta },
  { "rN" .. MULTI_MINUS, negative_color },
  { "rPois", BRC.COLORS.lightgreen },
  { "rElec", BRC.COLORS.lightcyan },
  { "rCorr", BRC.COLORS.yellow },
  { "rMut", BRC.COLORS.yellow },
  { "sInv", BRC.COLORS.magenta },
  { "MRegen" .. MULTI_PLUS, BRC.COLORS.cyan },
  { "^Regen" .. MULTI_PLUS, BRC.COLORS.green }, -- Avoiding "MRegen"
  { " Regen" .. MULTI_PLUS, BRC.COLORS.green }, -- Avoiding "MRegen"
  { "Stlth" .. MULTI_PLUS, positive_color },
  { "%+Fly", positive_color },
  { "RMsl", BRC.COLORS.yellow },
  { "Will" .. MULTI_PLUS, BRC.COLORS.blue },
  { "Will" .. MULTI_MINUS, negative_color },
  { "Wiz" .. MULTI_PLUS, BRC.COLORS.cyan },
  { "Wiz" .. MULTI_MINUS, negative_color },
  { "Slay" .. POS_NUM, positive_color },
  { "Slay" .. NEG_NUM, negative_color },
  { "Str" .. POS_NUM, positive_color },
  { "Str" .. NEG_NUM, negative_color },
  { "Dex" .. POS_NUM, positive_color },
  { "Dex" .. NEG_NUM, negative_color },
  { "Int" .. POS_NUM, positive_color },
  { "Int" .. NEG_NUM, negative_color },
  { "AC" .. POS_NUM, positive_color },
  { "AC" .. NEG_NUM, negative_color },
  { "EV" .. POS_NUM, positive_color },
  { "EV" .. NEG_NUM, negative_color },
  { "SH" .. POS_NUM, positive_color },
  { "SH" .. NEG_NUM, negative_color },
  { "HP" .. POS_NUM, positive_color },
  { "HP" .. NEG_NUM, negative_color },
  { "MP" .. POS_NUM, positive_color },
  { "MP" .. NEG_NUM, negative_color },
} -- COLORIZE_TAGS (do not remove this comment)

-- Local functions
local function colorize_subtext(text, s, tag)
  local idx = text:find(s)
  if not idx then return text end
  if idx > 1 then
    -- Avoid '!r' or an existing color tag
    local prev = text:sub(idx - 1, idx - 1)
    if prev == "!" or prev == ">" then return text end
  end

  return text:gsub(s, string.format("<%s>%%1</%s>", tag, tag))
end

-- Hook functions
function f_color_inscribe.c_assign_invletter(it)
  if it.artefact then return end
  -- If enabled, call out to inscribe stats before coloring
  if f_inscribe_stats.do_stat_inscription then f_inscribe_stats.do_stat_inscription(it) end

  local text = it.inscription
  for _, tag in ipairs(COLORIZE_TAGS) do
    text = colorize_subtext(text, tag[1], tag[2])
  end

  -- Limit length for % menu: = 80 total width - 25/32 other text - #name - #" {}"
  it.inscribe("", false)
  local max_length = 80 - (it.is_melded and 32 or 25) - #it.name("plain", true) - 3
  if max_length < 0 then return end
  -- Try removing darkgrey and white, then just remove all
  if #text > max_length then text = text:gsub("</*" .. BRC.COLORS.darkgrey .. ">", "") end
  if #text > max_length then text = text:gsub("</*" .. BRC.COLORS.white .. ">", "") end
  if #text > max_length then text = text:gsub("<.->", "") end

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

  local cleaned = BRC.text.clean(text)
  if cleaned:sub(2, 4) == " - " then
    text = " " .. text
  end

  crawl.mpr(text)
end
--]]
