--[[
BRC Utility Functions - All utility functions organized into logical tables
--]]

-- Initialize submodules
BRC.mpr = {}
BRC.get = {}
BRC.is = {}
BRC.you = {}
BRC.util = {}
BRC.dump = {}

-- Local variables
local _mpr_queue = {}

-- Local constants
local CLEANUP_TEXT_CHARS = "([%^%$%(%)%%%.%[%]%*%+%-%?])"


--- BRC.mpr - Wrappers around crawl.mpr ---

-- Display a message, wrapped in a single color tag
function BRC.mpr.col(text, color, channel)
  crawl.mpr(BRC.util.color(color, text), channel)
end

-- Message and stop travel/activity
function BRC.mpr.stop(text, color, channel)
  BRC.mpr.col(text, color, channel)
  you.stop_activity()
end

-- Message and a more prompt
function BRC.mpr.more(text, color, channel)
  BRC.mpr.col(text, color, channel)
  you.stop_activity()
  crawl.more()
  crawl.redraw_screen()
end

-- Conditionally display a more prompt
function BRC.mpr.optmore(show_more, text, color, channel)
  if show_more then
    BRC.mpr.more(text, color, channel)
  else
    BRC.mpr.col(text, color, channel)
  end
end

-- Queue a message, to dispay at start of next turn
function BRC.mpr.que(text, color, channel)
  for _, msg in ipairs(_mpr_queue) do
    if msg.text == text and msg.channel == channel then return end
  end
  local msg = BRC.util.color(color, text)
  _mpr_queue[#_mpr_queue + 1] = { text = msg, channel = channel, show_more = false }
end

-- Queue msg w/ conditional force-more prompt
function BRC.mpr.que_optmore(show_more, text, color, channel)
  for _, msg in ipairs(_mpr_queue) do
    if msg.text == text and msg.channel == channel and msg.show_more == show_more then return end
  end
  local msg = BRC.util.color(color, text)
  _mpr_queue[#_mpr_queue + 1] = { text = msg, channel = channel, show_more = show_more }
end

-- Display and consume the message queue
function BRC.mpr.consume_queue()
  local do_more = false
  for _, msg in ipairs(_mpr_queue) do
    crawl.mpr(msg.text, msg.channel)
    if msg.show_more then do_more = true end
  end

  if do_more then
    you.stop_activity()
    crawl.redraw_screen()
    crawl.more()
    crawl.redraw_screen()
  end

  _mpr_queue = {}
end

-- Get a yes/no response
function BRC.mpr.yesno(text, color, capital_only)
  local suffix = capital_only and " (Y/n)" or " (y/n)"
  local msg = BRC.util.color(color, text .. suffix)
  crawl.formatted_mpr(msg, "prompt")
  local res = crawl.getch()
  if string.char(res) == "Y" or string.char(res) == "y" and not capital_only then return true end
  crawl.mpr("Okay, then.")
  return false
end


---- BRC.get - Functions to get non-boolean data ----

--[[
Returns 2 values: A list of equipped items of the type, and the num_slots (ie maximum size the list can ever be)
This is usually a list of length 1, and num_slots 1. Poltergeists will get all worn aux armours and num_slots=6.
It is possible to have a list with fewer than num_slots items in it.
--]]
function BRC.get.equipped_aux(aux_type)
  local all_aux = {}
  local num_slots = you.race() == "Poltergeist" and 6 or 1
  for i = 1, num_slots do
    local it = items.equipped_at(aux_type, i)
    all_aux[#all_aux + 1] = it
  end
  return all_aux, num_slots
end

function BRC.get.mut(mutation, include_all) 
  return you.get_base_mutation_level(mutation, true, include_all, include_all) 
end

function BRC.get.skill_with_item(it)
  if BRC.is.magic_staff(it) then 
    return math.max(get_skill(BRC.get.staff_school(it)), get_skill("Staves")) 
  end
  if it.is_weapon then return get_skill(it.weap_skill) end
  if BRC.is.body_armour(it) then return get_skill("Armour") end
  if BRC.is.shield(it) then return get_skill("Shields") end
  if BRC.is.talisman(it) then return get_skill("Shapeshifting") end

  return 1 -- Fallback to 1
end

function BRC.get.staff_school(it)
  for k, v in pairs(ALL_STAFF_SCHOOLS) do
    if it.subtype() == k then return v end
  end
end

function BRC.get.talisman_min_level(it)
  -- Parse the item description
  local tokens = crawl.split(it.description, "\n")
  for _, v in ipairs(tokens) do
    if v:sub(1, 4) == "Min " then
      local start_pos = v:find("%d", 4)
      if start_pos then
        local end_pos = v:find("[^%d]", start_pos)
        return tonumber(v:sub(start_pos, end_pos - 1))
      end
    end
  end

  return 0 -- Fallback to 0, to surface any errors. Applies to Protean Talisman.
end


---- BRC.is - Boolean type checks of items ----

function BRC.is.amulet(it) 
  return it and it.name("base") == "amulet" 
end

function BRC.is.armour(it, include_orbs)
  -- exclude orbs by default
  if not it or it.class(true) ~= "armour" then return false end
  if not include_orbs and BRC.is.orb(it) then return false end
  return true
end

function BRC.is.aux_armour(it) 
  return BRC.is.armour(it) and not (BRC.is.body_armour(it) or BRC.is.shield(it)) 
end

function BRC.is.body_armour(it) 
  return it and it.subtype() == "body" 
end

function BRC.is.good_ego(it)
  if not it.branded then return false end
  local ego = get_var_type(it.ego) == "str" and it.ego or it.ego(true)
  if ego == "holy" and util.contains(ALL_POIS_RES_RACES, you.race()) then return false end
  if ego == "rPois" and util.contains(ALL_POIS_RES_RACES, you.race()) then return false end
  return true
end

function BRC.is.jewellery(it) 
  return it and it.class(true) == "jewellery" 
end

function BRC.is.magic_staff(it) 
  return it and it.class and it.class(true) == "magical staff" 
end

function BRC.is.ring(it) 
  return it and it.name("base") == "ring" 
end

function BRC.is.risky_ego(it)
  local text = it.artefact and it.name() or get_ego(it)
  if not text then return false end
  for _, v in ipairs(RISKY_EGOS) do
    if text:find(v) then return true end
  end
  return false
end

function BRC.is.scarf(it) 
  return it and it.class(true) == "armour" and it.subtype() == "scarf" 
end

function BRC.is.shield(it) 
  return it and it.is_shield() 
end

function BRC.is.talisman(it)
  if not it then return false end
  local c = it.class(true)
  return c and (c == "talisman" or c == "bauble")
end

function BRC.is.orb(it) 
  return it and it.class(true) == "armour" and it.subtype() == "offhand" and not it.is_shield() 
end

function BRC.is.polearm(it) 
  return it and it.weap_skill:find("Polearms", 1, true) 
end


---- BRC.you - Boolean attributes of the character ----

function BRC.you.free_offhand()
  if BRC.get.mut(MUTS.missing_hand, true) > 0 then return true end
  return not items.equipped_at("offhand")
end

function BRC.you.have_shield() 
  return BRC.is.shield(items.equipped_at("offhand")) 
end

function BRC.you.in_hell() 
  return util.contains(ALL_HELL_BRANCHES, you.branch()) 
end

function BRC.you.by_slimy_wall()
  for x = -1, 1 do
    for y = -1, 1 do
      if view.feature_at(x, y) == "slimy_wall" then return true end
    end
  end
  return false
end

function BRC.you.miasma_immune()
  if util.contains(ALL_UNDEAD_RACES, you.race()) then return true end
  if util.contains(ALL_NONLIVING_RACES, you.race()) then return true end
  return false
end

function BRC.you.mutation_immune() 
  return util.contains(ALL_UNDEAD_RACES, you.race()) 
end

function BRC.you.zero_stat() 
  return you.strength() <= 0 or you.dexterity() <= 0 or you.intelligence() <= 0 
end


---- BRC.util - Utility functions ----

-- Remove tags from text, and optionally escape special characters
function BRC.util.clean_text(text, escape_chars)
  -- Fast path: if no tags, just handle newlines and escaping
  if not text:find("<", 1, true) then
    local one_line = text:gsub("\n", "")
    if escape_chars then return one_line:gsub(CLEANUP_TEXT_CHARS, "%%%1") end
    return one_line
  end

  local tokens = {}
  local pos = 1
  local len = #text

  while pos <= len do
    local tag_start = text:find("<", pos, true)
    if not tag_start then
      -- No more tags, append remaining text
      tokens[#tokens + 1] = text:sub(pos)
      break
    end

    -- Append text before tag
    if tag_start > pos then tokens[#tokens + 1] = text:sub(pos, tag_start - 1) end

    -- Find end of tag
    local tag_end = text:find(">", tag_start, true)
    if not tag_end then
      -- Malformed tag, append remaining text
      tokens[#tokens + 1] = text:sub(pos)
      break
    end

    pos = tag_end + 1
  end

  -- Join all parts and remove newlines
  local cleaned = table.concat(tokens):gsub("\n", "")

  -- Handle escaping if needed
  if escape_chars then return cleaned:gsub(CLEANUP_TEXT_CHARS, "%%%1") end

  return cleaned
end

-- Wrap text in a color tag
function BRC.util.color(color, text)
  if not color then return text end
  return string.format("<%s>%s</%s>", color, text, color) 
end

-- Get the ascii code for a key
function BRC.util.letter_to_ascii(key) 
  return string.char(string.byte(key) - string.byte("a") + 1) 
end


--- BRC.dump - Debugging utils called from in-game lua interpreter ---

function BRC.dump.all(verbose, skip_char_dump)
  local char_dump = not skip_char_dump
  if dump_persistent_data then dump_persistent_data(char_dump) end
  if verbose then
    BRC.dump.inv(char_dump)
    BRC.dump.text(WEAP_CACHE.serialize(), char_dump)
    BRC.dump.data(char_dump)
  end
end

function BRC.dump.data(char_dump) 
  local tokens = { "\n---CHK_LUA_SAVE---" }
  for _, func in ipairs(chk_lua_save) do
    tokens[#tokens + 1] = util.trim(func())
  end

  BRC.dump.text(table.concat(tokens, "\n"), char_dump) 
end

function BRC.dump.inv(char_dump, include_item_info)
  local tokens = { "\n---INVENTORY---\n" }
  for inv in iter.invent_iterator:new(items.inventory()) do
    tokens[#tokens + 1] = string.format("%s: (%s) Qual: %s", inv.slot, inv.quantity, inv.name("qual"))
    if include_item_info then
      local base = inv.name("base") or "N/A"
      local cls = inv.class(true) or "N/A"
      local st = inv.subtype() or "N/A"
      tokens[#tokens + 1] = string.format("    Base: %s Class: %s, Subtype: %s", base, cls, st)
    end
    tokens[#tokens + 1] = "\n"
  end

  BRC.dump.text(table.concat(tokens, ""), char_dump) 
end

function BRC.dump.text(text, char_dump)
  BRC.mpr.col(text, COLORS.white)

  if char_dump then
    crawl.take_note(text)
    crawl.dump_char()
  end
end
