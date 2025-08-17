-- Colorize inscriptions --
-- Long inscriptions can break certain menus. In-game inscriptions seem limited to 78 chars.
-- If INSCRIPTION_MAX_LENGTH is exceeded, ending tags are removed. A final tag is added to resume writing in lightgrey.

local MULTI_PLUS = "%++"
local MULTI_MINUS = "%-+"
local NEG_NUM = "%-%d+%.?%d*"
local POS_NUM = "%+%d+%.?%d*"
local COLORIZE_TAGS = {
  { "rF" .. MULTI_PLUS, COLORS.lightred },
  { "rC" .. MULTI_PLUS, COLORS.lightblue },
  { "rN" .. MULTI_PLUS, COLORS.lightmagenta },
  { "rF" .. MULTI_MINUS, COLORS.red },
  { "rC" .. MULTI_MINUS, COLORS.blue },
  { "rN" .. MULTI_MINUS, COLORS.magenta },
  { "rPois", COLORS.green },
  { "rElec", COLORS.lightcyan },
  { "rCorr", COLORS.yellow },
  { "rMut", COLORS.brown },
  { "sInv", COLORS.white },
  { "Wiz" .. MULTI_PLUS, COLORS.white },
  { "Slay" .. POS_NUM, COLORS.white},
  {  "Str" .. POS_NUM, COLORS.white },
  {  "Dex" .. POS_NUM, COLORS.white },
  {  "Int" .. POS_NUM, COLORS.white },
  {   "AC" .. POS_NUM, COLORS.white },
  {   "EV" .. POS_NUM, COLORS.white },
  {   "SH" .. POS_NUM, COLORS.white },
  {   "HP" .. POS_NUM, COLORS.white },
  {   "MP" .. POS_NUM, COLORS.white },
  { "Slay" .. NEG_NUM, COLORS.darkgrey },
  {  "Str" .. NEG_NUM, COLORS.darkgrey },
  {  "Dex" .. NEG_NUM, COLORS.darkgrey },
  {  "Int" .. NEG_NUM, COLORS.darkgrey },
  {   "AC" .. NEG_NUM, COLORS.darkgrey },
  {   "EV" .. NEG_NUM, COLORS.darkgrey },
  {   "SH" .. NEG_NUM, COLORS.darkgrey },
  {   "HP" .. NEG_NUM, COLORS.darkgrey },
  {   "MP" .. NEG_NUM, COLORS.darkgrey },
} --COLORIZE_TAGS (do not remove this comment)


local function colorize_subtext(text, s, tag)
  local idx = text:find(s)
  if not idx then return text end
  if idx > 1 then
    -- Avoid '!r' or an existing color tag
    local prev = text:sub(idx-1, idx-1)
    if prev == "!" or prev == ">" then return text end
  end

  local retval = text:gsub("(" .. s .. ")", "<" .. tag .. ">%1</" .. tag .. ">")
  return retval
end


------------------- Hooks -------------------
function c_assign_invletter_color_inscribe(it)
  if not CONFIG.colorize_inscriptions then return end
  -- If enabled, call out to inscribe stats before coloring
  if ready_inscribe_stats then ready_inscribe_stats() end

  local text = it.inscription
  for _, tag in ipairs(COLORIZE_TAGS) do
    text = colorize_subtext(text, tag[1], tag[2])
  end

  it.inscribe(text, false)
end

-- To colorize more, need a way to:
  -- intercept messages before they're displayed (or delete and re-insert)
  -- insert tags that affect menus
  -- colorize artefact text
-- function c_message_color_inscribe(text, _)
--   local orig_text = text
--   text = colorize_subtext(text)
--   if text == orig_text then return end

--   local cleaned = cleanup_text(text)
--   if cleaned:sub(2, 4) == " - " then
--     text = " " .. text
--   end

--   crawl.mpr(text)
-- end
