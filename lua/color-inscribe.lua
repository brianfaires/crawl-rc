local function colorize_tag(text, tag, color)
  return text:gsub("("..tag..")", "<"..color..">%1</"..color..">")
end

local colorize_tags = {
  { "rF%++", "lightred" },
  { "rC%++", "lightblue" },
  { "rN%++", "lightmagenta" },
  { "rF%-+", "red" },
  { "rC%-+", "blue" },
  { "rN%-+", "magenta" },
  { "rPois", "lightgreen" },
  { "rElec", "cyan" },
  { "rCorr", "yellow" },
  { "rMut", "brown" },
  { "Slay%+%d+", "white"},
  {  "Str%+%d+", "white" },
  {  "Dex%+%d+", "white" },
  {  "Int%+%d+", "white" },
  {   "AC%+%d+", "white" },
  {   "EV%+%d+", "white" },
  {   "SH%+%d+", "white" },
  {   "HP%+%d+", "white" },
  {   "MP%+%d+", "white" },
  { "Slay%-%d+", "darkgrey" },
  {  "Str%-%d+", "darkgrey" },
  {  "Dex%-%d+", "darkgrey" },
  {  "Int%-%d+", "darkgrey" },
  {   "AC%-%d+", "darkgrey" },
  {   "EV%-%d+", "darkgrey" },
  {   "SH%-%d+", "darkgrey" },
  {   "HP%-%d+", "darkgrey" },
  {   "MP%-%d+", "darkgrey" }
}

local function colorize_text(text)
  for _, tag in ipairs(colorize_tags) do
    text = colorize_tag(text, tag[1], tag[2])
  end
  return text
end
---------------------------------------------
------------------- Hooks -------------------
---------------------------------------------
function c_assign_invletter_color_inscribe(it)
  if not it.inscription:find("</") then
      it.inscribe(colorize_text(it.inscription), false)
  end
end

-- TODO: Would like to modify all messages/menus, but need a way to
-- replace messages while they're in queue, delete the last message, or something
function c_message_color_inscribe(text, _)
  local orig_text = text
  text = colorize_text(text)
  if text == orig_text then return end

  local cleaned = cleanup_message(text)
  if cleaned:sub(2, 4) == " - " then
    text = " "..text
  end

  crawl.mpr(text)
end
