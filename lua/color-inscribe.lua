-- Long inscriptions can break certain menus. In-game inscriptions seem limited to 78 chars.
-- If INSCRIPTION_MAX_LENGTH is exceeded, ending tags are removed. A final tag is added to resume writing in lightgrey.
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

-- Color map to single digit tags:
  -- 0:black, 1:lightblue, 2:green, 3:cyan, 4:red, 5:magenta,
  -- 6:brown, 7: lightgrey, 8:darkgrey, 9:lightblue, 10:lightgreen, 11:lightyan, 12:lightred,
  -- 13:lightmagenta, 14:yellow, 15:white
local multi_plus = "%++"
local multi_minus = "%-+"
local pos_num = "%+%d+%.?%d*"
local neg_num = "%-%d+%.?%d*"
local colorize_tags = {
  { "rF"..multi_plus, 12 },
  { "rC"..multi_plus, 9 },
  { "rN"..multi_plus, 13 },
  { "rF"..multi_minus, 4 },
  { "rC"..multi_minus, 1 },
  { "rN"..multi_minus, 5 },
  { "rPois", 2 },
  { "rElec", 11 },
  { "rCorr", 14 },
  { "rMut", 6 },
  { "Slay"..pos_num, 15},
  {  "Str"..pos_num, 15 },
  {  "Dex"..pos_num, 15 },
  {  "Int"..pos_num, 15 },
  {   "AC"..pos_num, 15 },
  {   "EV"..pos_num, 15 },
  {   "SH"..pos_num, 15 },
  {   "HP"..pos_num, 15 },
  {   "MP"..pos_num, 15 },
  { "Slay"..neg_num, 8 },
  {  "Str"..neg_num, 8 },
  {  "Dex"..neg_num, 8 },
  {  "Int"..neg_num, 8 },
  {   "AC"..neg_num, 8 },
  {   "EV"..neg_num, 8 },
  {   "SH"..neg_num, 8 },
  {   "HP"..neg_num, 8 },
  {   "MP"..neg_num, 8 },
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

-- TODO: To colorize more, need a way to:
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
