--[[
Feature: color-inscribe
Description: Colorizes inscriptions on items with appropriate colors for resistances, stats, and other properties
Author: buehler
Dependencies: core/constants.lua
--]]

f_color_inscribe = {}
f_color_inscribe.BRC_FEATURE_NAME = "color-inscribe"

---- Local constants / configuration ----
local LOSS_COLOR = BRC.COLOR.brown
local GAIN_COLOR = BRC.COLOR.white
local MULTI_PLUS = "%++"
local MULTI_MINUS = "%-+"
local NEG_NUM = "%-%d+%.?%d*"
local POS_NUM = "%+%d+%.?%d*"
local COLORIZE_TAGS = {
  { "rF" .. MULTI_PLUS, BRC.COLOR.lightred },
  { "rF" .. MULTI_MINUS, LOSS_COLOR },
  { "rC" .. MULTI_PLUS, BRC.COLOR.lightblue },
  { "rC" .. MULTI_MINUS, LOSS_COLOR },
  { "rN" .. MULTI_PLUS, BRC.COLOR.lightmagenta },
  { "rN" .. MULTI_MINUS, LOSS_COLOR },
  { "rPois", BRC.COLOR.lightgreen },
  { "rElec", BRC.COLOR.lightcyan },
  { "rCorr", BRC.COLOR.yellow },
  { "rMut", BRC.COLOR.yellow },
  { "sInv", BRC.COLOR.magenta },
  { "MRegen" .. MULTI_PLUS, BRC.COLOR.cyan },
  { "^Regen" .. MULTI_PLUS, BRC.COLOR.green }, -- Avoiding "MRegen"
  { " Regen" .. MULTI_PLUS, BRC.COLOR.green }, -- Avoiding "MRegen"
  { "Stlth" .. MULTI_PLUS, GAIN_COLOR },
  { "%+Fly", GAIN_COLOR },
  { "RMsl", BRC.COLOR.yellow },
  { "Will" .. MULTI_PLUS, BRC.COLOR.blue },
  { "Will" .. MULTI_MINUS, LOSS_COLOR },
  { "Wiz" .. MULTI_PLUS, BRC.COLOR.cyan },
  { "Wiz" .. MULTI_MINUS, LOSS_COLOR },
  { "Slay" .. POS_NUM, GAIN_COLOR },
  { "Slay" .. NEG_NUM, LOSS_COLOR },
  { "Str" .. POS_NUM, GAIN_COLOR },
  { "Str" .. NEG_NUM, LOSS_COLOR },
  { "Dex" .. POS_NUM, GAIN_COLOR },
  { "Dex" .. NEG_NUM, LOSS_COLOR },
  { "Int" .. POS_NUM, GAIN_COLOR },
  { "Int" .. NEG_NUM, LOSS_COLOR },
  { "AC" .. POS_NUM, GAIN_COLOR },
  { "AC" .. NEG_NUM, LOSS_COLOR },
  { "EV" .. POS_NUM, GAIN_COLOR },
  { "EV" .. NEG_NUM, LOSS_COLOR },
  { "SH" .. POS_NUM, GAIN_COLOR },
  { "SH" .. NEG_NUM, LOSS_COLOR },
  { "HP" .. POS_NUM, GAIN_COLOR },
  { "HP" .. NEG_NUM, LOSS_COLOR },
  { "MP" .. POS_NUM, GAIN_COLOR },
  { "MP" .. NEG_NUM, LOSS_COLOR },
} -- COLORIZE_TAGS (do not remove this comment)

---- Local functions ----
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

---- Hook functions ----
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
  if #text > max_length then text = text:gsub("</*" .. BRC.COLOR.darkgrey .. ">", "") end
  if #text > max_length then text = text:gsub("</*" .. BRC.COLOR.white .. ">", "") end
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
