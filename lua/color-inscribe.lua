-- Colorize inscriptions --
-- Long inscriptions can break certain menus. In-game inscriptions seem limited to 78 chars.
-- If INSCRIPTION_MAX_LENGTH is exceeded, ending tags are removed. A final tag is added to resume writing in lightgrey.
loadfile("lua/constants.lua")

local INSCRIPTION_MAX_LENGTH = 70

local function colorize_text(text, s, tag)
  local idx = text:find(s)
  if not idx then return text end
  if idx > 1 then
    -- Avoid '!r' or an existing color tag
    local prev = text:sub(idx-1, idx-1)
    if prev == "!" or prev == ">" then return text end
  end

  local retval = text:gsub("("..s..")", "<"..tag..">%1</"..tag..">")
  return retval
end


local multi_plus = "%++"
local multi_minus = "%-+"
local pos_num = "%+%d+%.?%d*"
local neg_num = "%-%d+%.?%d*"
local colorize_tags = {
  { "rF"..multi_plus, COLORS.lightred },
  { "rC"..multi_plus, COLORS.lightblue },
  { "rN"..multi_plus, COLORS.lightmagenta },
  { "rF"..multi_minus, COLORS.red },
  { "rC"..multi_minus, COLORS.blue },
  { "rN"..multi_minus, COLORS.magenta },
  { "rPois", COLORS.green },
  { "rElec", COLORS.lightcyan },
  { "rCorr", COLORS.yellow },
  { "rMut", COLORS.brown },
  { "Slay"..pos_num, COLORS.white},
  {  "Str"..pos_num, COLORS.white },
  {  "Dex"..pos_num, COLORS.white },
  {  "Int"..pos_num, COLORS.white },
  {   "AC"..pos_num, COLORS.white },
  {   "EV"..pos_num, COLORS.white },
  {   "SH"..pos_num, COLORS.white },
  {   "HP"..pos_num, COLORS.white },
  {   "MP"..pos_num, COLORS.white },
  { "Slay"..neg_num, COLORS.darkgrey },
  {  "Str"..neg_num, COLORS.darkgrey },
  {  "Dex"..neg_num, COLORS.darkgrey },
  {  "Int"..neg_num, COLORS.darkgrey },
  {   "AC"..neg_num, COLORS.darkgrey },
  {   "EV"..neg_num, COLORS.darkgrey },
  {   "SH"..neg_num, COLORS.darkgrey },
  {   "HP"..neg_num, COLORS.darkgrey },
  {   "MP"..neg_num, COLORS.darkgrey },
} --colorize_tags (do not remove this comment)

------------------- Hooks -------------------
function c_assign_invletter_color_inscribe(it)
  local text = it.inscription
  for _, tag in ipairs(colorize_tags) do
    text = colorize_text(text, tag[1], tag[2])
  end

  if text:len() > INSCRIPTION_MAX_LENGTH then
    text = text:gsub("<.*>", "").."<7>"
  end
  it.inscribe(text, false)
end

-- To colorize more, need a way to:
  -- intercept messages before they're displayed
  -- insert tags that affect menus
  -- colorize artefact text
-- function c_message_color_inscribe(text, _)
--   local orig_text = text
--   text = colorize_text(text)
--   if text == orig_text then return end

--   local cleaned = cleanup_text(text)
--   if cleaned:sub(2, 4) == " - " then
--     text = " "..text
--   end

--   crawl.mpr(text)
-- end