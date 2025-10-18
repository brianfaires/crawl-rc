--[[
BRC Utility Functions - All utility functions organized into logical tables
Author: buehler
Dependencies: core/config.lua, core/constants.lua
--]]

---- Initialize BRC namespace
BRC = BRC or {}

---- Local variables ----
local _mpr_queue = {}

---- Local functions ----
local function cap_lines(str)
  if BRC.Data.Config.max_lines_per_table and BRC.Data.Config.max_lines_per_table > 0 then
    local lines = BRC.util.count_lines(str)
    if lines > BRC.Data.Config.max_lines_per_table then
      return string.format("{ %s lines... }", lines)
    end
  end
  return str
end

local function log_message(message, context, color)
  -- Avoid referencing BRC, to stay robust during startup
  color = color or "lightgrey"
  local msg = "[BRC] " .. tostring(message)
  if context then msg = string.format("%s (%s)", msg, tostring(context)) end
  crawl.mpr(string.format("<%s>%s</%s>", color, msg, color))
  crawl.flush_prev_message()
end

local function serialize_chk_lua_save()
  local tokens = { BRC.text.lightblue("\n---CHK_LUA_SAVE---") }
  for _, func in ipairs(chk_lua_save) do
    local result = func()
    if result and #result > 0 then tokens[#tokens + 1] = util.trim(result) end
  end

  return table.concat(tokens, "\n")
end

local function serialize_inventory()
  local tokens = { BRC.text.lightcyan("\n---INVENTORY---\n") }
  for _, inv in ipairs(items.inventory()) do
    local base = inv.name("base") or "N/A"
    local cls = inv.class(true) or "N/A"
    local st = inv.subtype() or "N/A"
    tokens[#tokens + 1] = string.format("%s: (%s) Qual: %s", inv.slot, inv.quantity, inv.name())
    tokens[#tokens + 1] = string.format("  Base: %s Class: %s, Subtype: %s\n", base, cls, st)
  end

  return table.concat(tokens)
end

--- Stringify BRC.Config and all feature configs, including headers
local function serialize_config()
  local tokens = {}
  tokens[#tokens + 1] = BRC.text.lightcyan("\n---BRC Config---\n")
  tokens[#tokens + 1] = BRC.util.tostring(BRC.Config, true)

  local all_features = BRC.get_registered_features()
  local keys = util.keys(all_features)
  util.sort(keys)

  for i = 1, #keys do
    local name = keys[i]
    local feature = all_features[name]
    if feature.Config then
      local header = BRC.text.cyan("\n\n---Feature Config: " .. name .. "---\n")
      tokens[#tokens + 1] = header .. BRC.util.tostring(feature.Config, true)
    end
  end

  return table.concat(tokens)
end

-----------------------------------
---- BRC.log - Logging methods ----
BRC.log = {}

--- Primary function for displaying errors. Includes a force_more_message by default.
-- @param context (optional) Additional context. No context if params are (string, bool).
function BRC.log.error(message, context, skip_more)
  if type(context) == "boolean" and skip_more == nil then
    skip_more = context
    context = nil
  end

  log_message("(Error) " .. message, context, BRC.COL.lightred)
  you.stop_activity()
  crawl.redraw_screen()

  if not skip_more then
    crawl.more()
    crawl.redraw_screen()
  end
end

function BRC.log.warning(message, context)
  log_message(message, context, BRC.COL.yellow)
  you.stop_activity()
end

function BRC.log.info(message, context)
  log_message(message, context, BRC.COL.white)
end

function BRC.log.debug(message, context)
  if not BRC.Config.show_debug_messages then return end
  log_message(message, context, BRC.COL.lightblue)
end

---------------------------------------------------
---- BRC.text - Text color + parsing functions ----
BRC.text = {}

--- Remove newlines and tags from text
function BRC.text.clean(text)
  return text:gsub("\n", ""):gsub("<[^>]*>", "")
end

-- Wrap text in a color tag, Usage: BRC.text.blue("Hello"), or BRC.text["1"]("Hello")
for k, v in pairs(BRC.COL) do
  BRC.text[k] = function(text)
    return string.format("<%s>%s</%s>", v, tostring(text), v)
  end
  BRC.text[v] = BRC.text[k]
end

function BRC.text.contains(self, text)
  return self:find(text, 1, true) ~= nil
end
-- Connect string:contains() to BRC.text.contains()
getmetatable("").__index.contains = BRC.text.contains

function BRC.text.wrap(text, wrapper, no_space)
  if not wrapper then return text end
  return table.concat({ wrapper, text, wrapper }, no_space and "" or " ")
end

function BRC.text.get_pickup_info(text)
  local cleaned = BRC.text.clean(text)
  if cleaned:sub(2, 4) ~= " - " then return nil end
  return cleaned:sub(5, #cleaned), items.letter_to_index(cleaned:sub(1, 1))
end

---------------------------------------------
---- BRC.mpr - Wrappers around crawl.mpr ----
BRC.mpr = {}

--- Output message in color. Usage: BRC.mpr.white("Hello"), or BRC.mpr["15"]("Hello")
for k, v in pairs(BRC.COL) do
  BRC.mpr[k] = function(msg, channel)
    crawl.mpr(BRC.text[v](msg), channel)
    crawl.flush_prev_message()
  end
  BRC.mpr[v] = BRC.mpr[k]
end

function BRC.mpr.okay(suffix)
  BRC.mpr.darkgrey("Okay, then." .. (suffix and " " .. suffix or ""))
end

-- Message plus stop travel/activity
function BRC.mpr.stop(msg, color, channel)
  BRC.mpr[color](msg, channel)
  you.stop_activity()
end

-- Message as a force_more_message
function BRC.mpr.more(msg, color, channel)
  BRC.mpr[color](msg, channel)
  you.stop_activity()
  crawl.redraw_screen()
  crawl.more()
  crawl.redraw_screen()
end

-- Conditional force_more_message
function BRC.mpr.optmore(show_more, msg, color, channel)
  if show_more then
    BRC.mpr.more(msg, color, channel)
  else
    BRC.mpr[color](msg, channel)
  end
end

--- Queue the message to dispay at the end of ready()
function BRC.mpr.que(msg, color, channel)
  BRC.mpr.que_optmore(false, msg, color, channel)
end

-- Queue msg w/ conditional force_more_message
function BRC.mpr.que_optmore(show_more, msg, color, channel)
  for _, q in ipairs(_mpr_queue) do
    if q.m == msg and q.ch == channel and q.more == show_more then return end
  end
  _mpr_queue[#_mpr_queue + 1] = { m = BRC.text[color](msg), ch = channel, more = show_more }
end

-- Display queued messages and clear the queue
function BRC.mpr.consume_queue()
  local do_more = false
  for _, msg in ipairs(_mpr_queue) do
    crawl.mpr(tostring(msg.m), msg.ch)
    crawl.flush_prev_message()
    do_more = do_more or msg.more
  end

  if do_more then
    you.stop_activity()
    crawl.redraw_screen()
    crawl.more()
    crawl.redraw_screen()
  end

  _mpr_queue = {}
end

--- Get a selection from the user, from a list of options
function BRC.mpr.select(msg, options, color)
  if not (type(options) == "table" and #options > 0) then
    BRC.log.error("No options provided for BRC.mpr.select")
    return false
  end

  msg = msg .. ":\n"
  for i, option in ipairs(options) do
    msg = msg .. string.format("%s: %s\n", i, BRC.text.white(option))
  end
  BRC.mpr[color or BRC.COL.lightcyan](msg, "prompt")
  for _ = 1, 10 do
    local res = crawl.getch()
    if res then
      local num = res - string.byte("0")
      if num > 0 and num <= #options then return options[num] end
    end
    BRC.mpr.magenta("Invalid option, try again.")
  end

  BRC.mpr.lightmagenta("Fine then. Using option 1: " .. options[1])
  return options[1]
end

-- Get a yes/no response
function BRC.mpr.yesno(msg, color, capital_only)
  msg = string.format("%s (%s)", msg, capital_only and "Y/N" or "y/n")

  for i = 1, 10 do
    BRC.mpr[color](msg, "prompt")
    local res = crawl.getch()
    if res and res >= 0 and res <= 255 then
      local c = string.char(res)
      if c == "Y" or c == "y" and not capital_only then return true end
      if c == "N" or c == "n" and not capital_only then return false end
    end
    if i == 1 and capital_only then msg = "[CAPS ONLY] " .. msg end
  end

  BRC.mpr.lightmagenta("Feels like a no.")
  return false
end

-----------------------------------------------------
---- BRC.get - Functions to get non-boolean data ----
BRC.get = {}

function BRC.get.num_equip_slots(it)
  local player_race = you.race()
  if it.is_weapon then return player_race == "Coglin" and 2 or 1 end
  if BRC.is.aux_armour(it) then
    if player_race == "Formicid" then return it.subtype() == "gloves" and 2 or 1 end
    return player_race == "Poltergeist" and 6 or 1
  end

  return 1
end

function BRC.get.command_key(cmd)
  local key = crawl.get_command(cmd)
  if not key then return nil end
  -- get_command returns things like "Uppercase Ctrl-S"; we just want 'S'
  local char_key = key:sub(-1)
  return key:contains("Ctrl") and BRC.util.control_key(char_key) or char_key
end

--[[
BRC.get.equipped_at() - Returns 2 values (usually a list of length 1, with num_slots==1):
  1. A list of equipped items at the same slot as the item
  2. the num_slots (ie maximum size the list can ever be)
--]]
function BRC.get.equipped_at(it)
  local all_aux = {}
  local num_slots = BRC.get.num_equip_slots(it)
  local slot_name = it.is_weapon and "weapon"
    or BRC.is.body_armour(it) and "armour"
    or it.subtype()

  for i = 1, num_slots do
    local eq = items.equipped_at(slot_name, i)
    all_aux[#all_aux + 1] = eq
  end

  return all_aux, num_slots
end

--- Get mutation level, explicitly specifying crawl's optional params
-- @param bool innate_only (optional) - Exclude to include all mutations
function BRC.get.mut(mutation, innate_only)
  return you.get_base_mutation_level(mutation, true, not innate_only, not innate_only)
end

function BRC.get.preferred_weapon_type()
  local max_weap_skill = 0
  local pref = nil
  for _, v in ipairs(BRC.WEAP_SCHOOLS) do
    if BRC.get.skill(v) > max_weap_skill then
      max_weap_skill = BRC.get.skill(v)
      pref = v
    end
  end
  return pref
end

function BRC.get.skill(skill)
  if skill and not skill:contains(",") then return you.skill(skill) end

  local skills = crawl.split(skill, ",")
  local sum = 0
  local count = 0
  for _, s in ipairs(skills) do
    sum = sum + you.skill(s)
    count = count + 1
  end

  return sum / count
end

function BRC.get.skill_with(it)
  if BRC.is.magic_staff(it) then
    return math.max(BRC.get.skill(BRC.get.staff_school(it)), BRC.get.skill("Staves"))
  end
  if it.is_weapon then return BRC.get.skill(it.weap_skill) end
  if BRC.is.body_armour(it) then return BRC.get.skill("Armour") end
  if BRC.is.shield(it) then return BRC.get.skill("Shields") end
  if BRC.is.talisman(it) then return BRC.you.shapeshifting_skill() end

  BRC.log.error("Unknown skill for item: " .. it.name())
end

function BRC.get.staff_school(it)
  for k, v in pairs(BRC.STAFF_SCHOOLS) do
    if it.subtype() == k then return v end
  end
end

function BRC.get.talisman_min_level(it)
  if it.name() == "protean talisman" then return 6 end

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

  BRC.log.error("Failed to find skill required for: " .. it.name())
  return -1
end

------------------------------------------
---- BRC.is - Boolean checks of items ----
BRC.is = {}

function BRC.is.amulet(it)
  return it and it.name("base") == "amulet"
end

function BRC.is.armour(it, include_orbs)
  return it and it.class(true) == "armour" and (include_orbs or not BRC.is.orb(it))
end

function BRC.is.aux_armour(it)
  return BRC.is.armour(it) and not (BRC.is.body_armour(it) or BRC.is.shield(it))
end

function BRC.is.body_armour(it)
  return it and it.subtype() == "body"
end

function BRC.is.jewellery(it)
  return it and it.class(true) == "jewellery"
end

function BRC.is.list(value)
  return value and type(value) == "table" and #value > 0
end

function BRC.is.magic_staff(it)
  return it and it.class and it.class(true) == "magical staff"
end

function BRC.is.map(value)
  return value and type(value) == "table" and next(value) ~= nil and #value == 0
end

function BRC.is.ring(it)
  return it and it.name("base") == "ring"
end

function BRC.is.scarf(it)
  return BRC.is.armour(it) and it.subtype() == "cloak" and it.name():contains("scarf")
end

function BRC.is.shield(it)
  return it and it.is_shield()
end

function BRC.is.talisman(it)
  return it and it.class(true) == "talisman"
end

function BRC.is.orb(it)
  return it and it.subtype() == "offhand" and not it.is_shield()
end

function BRC.is.polearm(it)
  return it and it.weap_skill:contains("Polearms")
end

-------------------------------------------------------
---- BRC.you - Boolean attributes of the character ----
BRC.you = {}

function BRC.you.by_slimy_wall()
  for x = -1, 1 do
    for y = -1, 1 do
      if view.feature_at(x, y) == "slimy_wall" then return true end
    end
  end
  return false
end

function BRC.you.free_offhand()
  if BRC.get.mut("missing a hand") > 0 then return true end
  return not items.equipped_at("offhand")
end

function BRC.you.have_shield()
  return BRC.is.shield(items.equipped_at("offhand"))
end

function BRC.you.in_hell(exclude_vestibule)
  local branch = you.branch()
  if exclude_vestibule and branch == "Hell" then return false end
  return util.contains(BRC.HELL_BRANCHES, branch)
end

function BRC.you.miasma_immune()
  if util.contains(BRC.UNDEAD_RACES, you.race()) then return true end
  if util.contains(BRC.NONLIVING_RACES, you.race()) then return true end
  return false
end

function BRC.you.mutation_immune()
  return util.contains(BRC.UNDEAD_RACES, you.race())
end

function BRC.you.shapeshifting_skill()
  local skill = you.skill("Shapeshifting")
  local AMU = "amulet of wildshape"
  if util.exists(items.inventory(), function(i) return i.name("qual") == AMU end) then
    return skill + 5
  end
  return skill
end

function BRC.you.zero_stat()
  return you.strength() <= 0 or you.dexterity() <= 0 or you.intelligence() <= 0
end

--------------------------------------------------
---- BRC.set - Wrappers around crawl.setopt() ----
BRC.set = {}

function BRC.set.autopickup_exceptions(pattern, add_pattern)
  local op = add_pattern and "^=" or "-="
  crawl.setopt(string.format("autopickup_exceptions %s %s", op, pattern))
end

function BRC.set.explore_stop(pattern, add_pattern)
  local op = add_pattern and "+=" or "-="
  crawl.setopt(string.format("explore_stop %s %s", op, pattern))
end

function BRC.set.explore_stop_pickup_ignore(pattern, add_pattern)
  local op = add_pattern and "+=" or "-="
  crawl.setopt(string.format("explore_stop_pickup_ignore %s %s", op, pattern))
end

function BRC.set.flash_screen_message(pattern, add_pattern)
  local op = add_pattern and "+=" or "-="
  crawl.setopt(string.format("flash_screen_message %s %s", op, pattern))
end

function BRC.set.force_more_message(pattern, add_pattern)
  local op = add_pattern and "+=" or "-="
  crawl.setopt(string.format("force_more_message %s %s", op, pattern))
end

-- Binds a macro to a key. Function must be global and not a member of a module.
function BRC.set.macro(key, function_name)
  BRC.log.debug(
    string.format(
      "Assigning macro: %s to key: %s",
      BRC.text.magenta(function_name .. "()"),
      BRC.text.lightred("<<< '" .. key .. "' >>")
    )
  )
  crawl.setopt(string.format("macros += M %s ===%s", key, function_name))
end

function BRC.set.message_mute(pattern, mute_pattern)
  local op = mute_pattern and "^=" or "-="
  crawl.setopt(string.format("message_colour %s mute:%s", op, pattern))
end

function BRC.set.runrest_ignore_message(pattern, add_pattern)
  local op = add_pattern and "+=" or "-="
  crawl.setopt(string.format("runrest_ignore_message %s %s", op, pattern))
end

function BRC.set.runrest_stop_message(pattern, add_pattern)
  local op = add_pattern and "+=" or "-="
  crawl.setopt(string.format("runrest_stop_message %s %s", op, pattern))
end

------------------------------------------------------------------------------
--- BRC.dump - Debugging messages for char dump or in-game lua interpreter ---
BRC.dump = {}

--- Main dump for debugging
-- @param skip_mpr (optional bool) Used in char dump macro to only return the string
function BRC.dump.all(verbose, skip_mpr)
  local tokens = {}
  tokens[#tokens + 1] = BRC.Data.serialize()
  if verbose then
    tokens[#tokens + 1] = serialize_chk_lua_save()
    tokens[#tokens + 1] = serialize_inventory()
    tokens[#tokens + 1] = _weapon_cache.serialize()
    tokens[#tokens + 1] = serialize_config()
  end

  local text = table.concat(tokens, "\n")
  if not skip_mpr then BRC.mpr.white(text) end

  return text
end

function BRC.dump.char(add_debug_info)
  if add_debug_info then
    crawl.take_note(BRC.dump.all(true, true))
    BRC.mpr.lightgrey("BRC debug info added to character dump.")
  else
    BRC.mpr.darkgrey("No debug info added.")
  end
  BRC.util.do_cmd("CMD_CHARACTER_DUMP")
end

function BRC.dump.var(v)
  crawl.mpr(BRC.util.tostring(v, true) or "nil")
end

function macro_brc_dump_character()
  if not BRC.active then BRC.util.do_cmd("CMD_CHARACTER_DUMP") end
  BRC.dump.char(BRC.mpr.yesno("Add BRC debug info to character dump?", BRC.COL.lightcyan))
end

----------------------------------------------
---- BRC.util - General utility functions ----
BRC.util = {}

function BRC.util.control_key(c)
  return string.byte(c:upper()) - 64
end

function BRC.util.count_lines(str)
  if type(str) ~= "string" then return 0 end
  local count = 1
  str:gsub("\n", function() count = count + 1 end)
  return count
end

--- Tries keypress first, then crawl.do_commands() (which isn't always immediate)
-- @param cmd (string) The command to execute like "CMD_EXPLORE"
function BRC.util.do_cmd(cmd)
  local key = BRC.get.command_key(cmd)
  if key then
    crawl.sendkeys({ key })
  else
    crawl.do_commands({ cmd })
  end
end

function BRC.util.int2char(num)
  return string.char(string.byte("a") + num)
end

--- Sorts the keys of a dictionary/map: vars before tables, then alphabetically by key
--- If a list is passed, it assumed it is a list of global variable names
function BRC.util.get_sorted_keys(map_or_list)
  local keys_vars = {}
  local keys_tables = {}

  if BRC.is.map(map_or_list) then
    for key, v in pairs(map_or_list) do
      table.insert(type(v) == "table" and keys_tables or keys_vars, key)
    end
  else
    for _, key in ipairs(map_or_list) do
      table.insert(type(_G[key]) == "table" and keys_tables or keys_vars, key)
    end
  end

  util.sort(keys_vars)
  util.sort(keys_tables)
  util.append(keys_vars, keys_tables)
  return keys_vars
end

--- Serializes a variable to a string, for chk_lua_save or data dumps.
-- @param pretty (optional bool) format for human readability
-- @param _indents (optional int) Used internally to format multi-line tables
function BRC.util.tostring(var, pretty, _indents)
  local var_type = type(var)
  if var_type == "string" then
    local s
    if var:contains("\n") then
      s = string.format("[[\n%s]]", var)
    else
      s = '"' .. var:gsub('"', "") .. '"'
    end

    if not pretty then return s end
    -- Replace > and < to display the color tags instead of colored text
    return s:gsub(">", "TempGT"):gsub("<", "TempLT"):gsub("TempGT", "<gt>"):gsub("TempLT", "<lt>")
  elseif var_type == "table" then
    _indents = _indents or 0
    local indent = string.rep("  ", _indents)
    local child_indent = string.rep("  ", _indents + 1)
    local list_sep = ",\n" .. child_indent

    if BRC.is.list(var) then
      local tokens = {}
      for _, v in ipairs(var) do
        tokens[#tokens + 1] = cap_lines(BRC.util.tostring(v, pretty, _indents + 1))
      end
      if #tokens < 4 and not util.exists(var, function(t) return type(t) == "table" end) then
        return "{ " .. table.concat(tokens, ", ") .. " }"
      else
        return "{\n" .. child_indent .. table.concat(tokens, list_sep) .. "\n" .. indent .. "}"
      end
    elseif BRC.is.map(var) then
      local tokens = {}
      if pretty then
        local keys = BRC.util.get_sorted_keys(var)
        local contains_table = false
        for i = 1, #keys do
          local v = cap_lines(BRC.util.tostring(var[keys[i]], true, _indents + 1))
          if v then
            if type(var[keys[i]]) == "table" then
              contains_table = true
              tokens[#tokens + 1] = string.format('["%s"] = %s', keys[i], v)
            else
              tokens[#tokens + 1] = string.format("%s = %s", keys[i], v)
            end
          end
        end
        if #tokens <= 2 and not contains_table then
          return "{ " .. table.concat(tokens, ", ") .. " }"
        end
      else
        for k, v in pairs(var) do
          tokens[#tokens + 1] = '["' .. k .. '"] = ' .. BRC.util.tostring(v, pretty, _indents + 1)
        end
      end
      return "{\n" .. child_indent .. table.concat(tokens, list_sep) .. "\n" .. indent .. "}"
    else
      return "{}"
    end
  else
    if BRC.Data.Config.skip_pointers and (type(var) == "function" or type(var) == "userdata") then
      return nil
    end
    return tostring(var)
  end
end

--[[
The functions above are general purpose: They should apply to any crawl RC file.
The functions below contain design choices or logic that are somewhat specific to BRC.
Examples: Weapon DPS calculation, treat dragon scales as branded, defining what a "risky item" is.
--]]

---- Local functions ---- (Often mirroring calculations that live in crawl.)
-- Last verified against: dcss v0.33.1

local function format_dmg(dmg)
  -- Format damage values for consistent display width (4 characters)
  if dmg < 10 then return string.format("%.2f", dmg) end
  if dmg > 99.9 then return ">100" end
  return string.format("%.1f", dmg)
end

--- Format as armour/weapon stat to a string for display or inscription
local function format_stat(abbr, val, is_worn)
  local stat_str = string.format("%.1f", val)
  if val < 0 then
    return string.format("%s%s", abbr, stat_str)
  elseif is_worn then
    return string.format("%s:%s", abbr, stat_str)
  else
    return string.format("%s+%s", abbr, stat_str)
  end
end

local function get_size_penalty()
  if util.contains(BRC.LITTLE_RACES, you.race()) then
    return BRC.SIZE_PENALTY.LITTLE
  elseif util.contains(BRC.SMALL_RACES, you.race()) then
    return BRC.SIZE_PENALTY.SMALL
  elseif util.contains(BRC.LARGE_RACES, you.race()) then
    return BRC.SIZE_PENALTY.LARGE
  else
    return BRC.SIZE_PENALTY.NORMAL
  end
end

local function get_unadjusted_armour_pen(encumb)
  local pen = encumb - 2 * BRC.get.mut("sturdy frame")
  if pen > 0 then return pen end
  return 0
end

local function get_adjusted_armour_pen(encumb, str)
  local base_pen = get_unadjusted_armour_pen(encumb)
  return 2 * base_pen * base_pen * (45 - you.skill("Armour")) / 45 / (5 * (str + 3))
end

local function get_adjusted_dodge_bonus(encumb, str, dex)
  local size_factor = -2 * get_size_penalty()
  local dodge_bonus = 8 * (10 + you.skill("Dodging") * dex) / (20 - size_factor) / 10
  local armour_dodge_penalty = get_unadjusted_armour_pen(encumb) - 3
  if armour_dodge_penalty <= 0 then return dodge_bonus end

  if armour_dodge_penalty >= str then return dodge_bonus * str / (armour_dodge_penalty * 2) end
  return dodge_bonus - dodge_bonus * armour_dodge_penalty / (str * 2)
end

local function get_shield_penalty(sh)
  return 2 * sh.encumbrance * sh.encumbrance
    * (27 - you.skill("Shields")) / 27
    / (25 + 5 * you.strength())
end

local function get_branded_delay(delay, ego)
  if not ego then return delay end
  if ego == "speed" then
    return delay * 2 / 3
  elseif ego == "heavy" then
    return delay * 1.5
  end
  return delay
end

local function get_weap_min_delay(it)
  -- This is an abbreviated version of the actual calculation.
  -- Doesn't check brand or delay >=3, which are covered in get_weap_delay()
  if it.artefact and it.name("qual"):contains("woodcutter's axe") then return it.delay end

  local min_delay = math.floor(it.delay / 2)
  if it.weap_skill == "Short Blades" then return 5 end
  if it.is_ranged then
    local basename = it.name("base")
    local is_2h_ranged = basename:contains("crossbow") or basename:contains("arbalest")
    if is_2h_ranged then return math.max(min_delay, 10) end
  end

  return math.min(min_delay, 7)
end

local function get_weap_delay(it)
  -- dcss v0.33.1
  local delay = it.delay - BRC.get.skill(it.weap_skill) / 2
  delay = math.max(delay, get_weap_min_delay(it))
  delay = get_branded_delay(delay, BRC.get.ego(it))
  delay = math.max(delay, 3)

  local sh = items.equipped_at("offhand")
  if BRC.is.shield(sh) then delay = delay + get_shield_penalty(sh) end

  if it.is_ranged then
    local worn = items.equipped_at("armour")
    if worn then
      local str = you.strength()

      local cur = items.equipped_at("weapon")
      if cur and cur ~= it and cur.artefact then
        if it.artefact and it.artprops["Str"] then str = str + it.artprops["Str"] end
        if cur.artefact and cur.artprops["Str"] then str = str - cur.artprops["Str"] end
      end

      delay = delay + get_adjusted_armour_pen(worn.encumbrance, str)
    end
  end

  return delay / 10
end

local function get_slay_bonuses()
  local sum = 0

  -- Slots can go as high as 18 afaict
  for i = 0, 20 do
    local inv = items.equipped_at(i)
    if inv then
      if BRC.is.ring(inv) then
        if inv.artefact then
          local name = inv.name()
          local idx = name:find("Slay", 1, true)
          if idx then
            local slay = tonumber(name:sub(idx + 5, idx + 5))
            if slay == 1 then
              local next_digit = tonumber(name:sub(idx + 6, idx + 6))
              if next_digit then slay = 10 + next_digit end
            end

            if name:sub(idx + 4, idx + 4) == "+" then
              sum = sum + slay
            else
              sum = sum - slay
            end
          end
        elseif BRC.get.ego(inv) == "Slay" then
          sum = sum + inv.plus
        end
      elseif inv.artefact and (BRC.is.armour(inv, true) or BRC.is.amulet(inv)) then
        local slay = inv.artprops["Slay"]
        if slay then sum = sum + slay end
      end
    end
  end

  if you.race() == "Demonspawn" then
    sum = sum + 3 * BRC.get.mut("augmentation")
    sum = sum + BRC.get.mut("sharp scales")
  end

  return sum
end

local function get_staff_bonus_dmg(it, dmg_type)
  -- dcss v0.33.1
  if dmg_type == BRC.DMG_TYPE.unbranded then return 0 end
  if dmg_type == BRC.DMG_TYPE.plain then
    local basename = it.name("base")
    if basename ~= "staff of earth" and basename ~= "staff of conjuration" then return 0 end
  end

  local spell_skill = BRC.get.skill(BRC.get.staff_school(it))
  local evo_skill = you.skill("Evocations")

  local chance = (2 * evo_skill + spell_skill) / 30
  if chance > 1 then chance = 1 end
  -- 0.75 is an acceptable approximation; most commonly 63/80
  -- Varies by staff type in sometimes complex ways
  local avg_dmg = 3 / 4 * (evo_skill / 2 + spell_skill)
  return avg_dmg * chance
end

-- Formatting for stat inscriptions & alerts
function BRC.get.armour_stats(it)
  if not BRC.is.armour(it) then return "", "" end

  local equip_type = it.equip_type
  if equip_type == "body armour" then equip_type = "armour" end
  local cur = items.equipped_at(equip_type)
  local is_worn = it.equipped or (it.ininventory and cur and cur.slot == it.slot)
  local cur_ac = 0
  local cur_sh = 0
  local cur_ev = 0

  -- Show as delta if wearing a different item (and only one equip slot)
  if cur and not is_worn and BRC.get.num_equip_slots(it) == 1 then
    if BRC.is.shield(cur) then
      cur_sh = BRC.get.shield_sh(cur)
      cur_ev = -get_shield_penalty(cur)
    else
      cur_ac = BRC.get.armour_ac(cur)
      cur_ev = BRC.get.armour_ev(cur)
    end
  end

  if BRC.is.shield(it) then
    local sh_str = format_stat("SH", BRC.get.shield_sh(it) - cur_sh, is_worn)
    local ev_str = format_stat("EV", -get_shield_penalty(it) - cur_ev, is_worn)
    return sh_str, ev_str
  else
    local ac_str = format_stat("AC", BRC.get.armour_ac(it) - cur_ac, is_worn)
    if not BRC.is.body_armour(it) then return ac_str end
    local ev_str = format_stat("EV", BRC.get.armour_ev(it) - cur_ev, is_worn)
    return ac_str, ev_str
  end
end

function BRC.get.weapon_stats(it, dmg_type)
  if not it.is_weapon then return end
  if not dmg_type then
    if f_inscribe_stats and f_inscribe_stats.Config and f_inscribe_stats.Config.dmg_type then
      dmg_type = BRC.DMG_TYPE[f_inscribe_stats.Config.dmg_type]
    else
      dmg_type = BRC.DMG_TYPE.plain
    end
  end

  local dmg = format_dmg(BRC.get.weap_damage(it, dmg_type))
  local delay = get_weap_delay(it)
  local delay_str = string.format("%.1f", delay)
  if delay < 1 then
    delay_str = string.format("%.2f", delay)
    delay_str = delay_str:sub(2, #delay_str)
  end

  local dps = format_dmg(dmg / delay)
  local acc = it.accuracy + (it.plus or 0)
  if acc >= 0 then acc = "+" .. acc end

  --TODO: This would be nice if it worked in all UIs
  --return string.format("DPS:<w>%s</w> (%s/%s), Acc<w>%s</w>", dps, dmg, delay_str, acc)
  return string.format("DPS: %s (%s/%s), Acc%s", dps, dmg, delay_str, acc)
end

--- Get the ego of an item, with custom logic:
-- Treat unusable egos as no ego. Always lowercase egos.
-- Include armours with innate effects (except steam dragon scales)
-- Artefacts return their normal ego if they have one, else their name
-- @param no_stat_only_egos (optional bool) Exclude egos that only affect speed/damage
function BRC.get.ego(it, no_stat_only_egos)
  local ego = it.ego(true)
  if ego then
    if BRC.is.unusable_ego(ego) or (no_stat_only_egos and (ego == "speed" or ego == "heavy")) then
      return it.artefact and it.name() or nil
    end
    return ego
  end

  if BRC.is.body_armour(it) then
    local name = it.name("qual")
    local good_scales = name:contains("dragon scales") and not name:contains("steam")
    if name:contains("troll leather") or good_scales then return name end
  end

  return it.artefact and it.name() or nil
end

function BRC.get.hands(it)
  if you.race() ~= "Formicid" then return it.hands end
  local st = it.subtype()
  if st == "giant club" or st == "giant spiked club" then return 2 end
  return 1
end

function BRC.is.risky_item(it)
  if it.artefact then
    for k, v in pairs(it.artprops) do
      if util.contains(BRC.BAD_ART_PROPS, k) or v < 0 then return true end
    end
  end

  local ego_name = BRC.get.ego(it)
  return ego_name and util.contains(BRC.RISKY_EGOS, ego_name)
end

function BRC.is.unusable_ego(ego)
  local race = you.race()
  return ego == "holy" and util.contains(BRC.UNDEAD_RACES, race)
    or ego == "rPois" and util.contains(BRC.POIS_RES_RACES, race)
    or ego == "pain" and you.skill("Necromancy") == 0
end

-- Armour stats
function BRC.get.armour_ac(it)
  -- dcss v0.33.1
  local it_plus = it.plus or 0

  if it.artefact and it.is_identified then
    local art_ac = it.artprops["AC"]
    if art_ac then it_plus = it_plus + art_ac end
  end

  local ac = it.ac * (1 + you.skill("Armour") / 22) + it_plus
  if not BRC.is.body_armour(it) then return ac end

  if BRC.get.mut("deformed body") + BRC.get.mut("pseudopods") > 0 then ac = ac * 0.6 end

  return ac
end

function BRC.get.armour_ev(it)
  -- dcss v0.33.1
  -- This function computes the armour-based component to standard EV (not paralysed, etc)
  -- Factors in stat changes from this armour and removing current one
  local str = you.strength()
  local dex = you.dexterity()
  local no_art_str = str
  local no_art_dex = dex
  local art_ev = 0

  -- Adjust str/dex/EV for artefact stat changes
  local worn = items.equipped_at("armour")
  if worn and worn.artefact then
    if worn.artprops["Str"] then str = str - worn.artprops["Str"] end
    if worn.artprops["Dex"] then dex = dex - worn.artprops["Dex"] end
    if worn.artprops["EV"] then art_ev = art_ev - worn.artprops["EV"] end
  end

  if it.artefact then
    if it.artprops["Str"] then str = str + it.artprops["Str"] end
    if it.artprops["Dex"] then dex = dex + it.artprops["Dex"] end
    if it.artprops["EV"] then art_ev = art_ev + it.artprops["EV"] end
  end

  if str <= 0 then str = 1 end

  local dodge_bonus = get_adjusted_dodge_bonus(it.encumbrance, str, dex)
  local naked_dodge_bonus = get_adjusted_dodge_bonus(0, no_art_str, no_art_dex)
  return (dodge_bonus - naked_dodge_bonus) + art_ev - get_adjusted_armour_pen(it.encumbrance, str)
end

function BRC.get.shield_sh(it)
  -- dcss v0.33.1
  local dex = you.dexterity()
  if it.artefact and it.is_identified then
    local art_dex = it.artprops["Dex"]
    if art_dex then dex = dex + art_dex end
  end

  local cur = items.equipped_at("offhand")
  if BRC.is.shield(cur) and cur.artefact and cur.slot ~= it.slot then
    local art_dex = cur.artprops["Dex"]
    if art_dex then dex = dex - art_dex end
  end

  local it_plus = it.plus or 0

  local base_sh = it.ac * 2
  local shield = base_sh * (50 + you.skill("Shields") * 5 / 2)
  shield = shield + 200 * it_plus
  shield = shield + 38 * (you.skill("Shields") + 3 + dex * (base_sh + 13) / 26)
  return shield / 200
end

-- Weapon stats
function BRC.get.weap_dps(it, dmg_type)
  if not dmg_type then dmg_type = BRC.DMG_TYPE.scoring end
  return BRC.get.weap_damage(it, dmg_type) / get_weap_delay(it)
end

function BRC.get.weap_damage(it, dmg_type)
  -- Returns an adjusted weapon damage = damage * speed
  -- Includes stat/slay changes between weapon and the one currently wielded
  -- Aux attacks not included
  if not dmg_type then dmg_type = BRC.DMG_TYPE.scoring end
  local it_plus = it.plus or 0
  -- Adjust str/dex/slay from artefacts
  local str = you.strength()
  local dex = you.dexterity()

  -- Adjust str/dex/EV for artefact stat changes
  if not it.equipped then
    local wielded = items.equipped_at("weapon")
    if wielded and wielded.artefact then
      if wielded.artprops["Str"] then str = str - wielded.artprops["Str"] end
      if wielded.artprops["Dex"] then dex = dex - wielded.artprops["Dex"] end
      if wielded.artprops["Slay"] then it_plus = it_plus - wielded.artprops["Slay"] end
    end

    if it.artefact and it.is_identified then
      if it.artprops["Str"] then str = str + it.artprops["Str"] end
      if it.artprops["Dex"] then dex = dex + it.artprops["Dex"] end
      if it.artprops["Slay"] then it_plus = it_plus + it.artprops["Slay"] end
    end
  end

  local stat = str
  if it.is_ranged or it.weap_skill:contains("Blades") then stat = dex end

  local stat_mod = 0.75 + 0.025 * stat
  local skill_mod = (1 + BRC.get.skill(it.weap_skill) / 50) * (1 + you.skill("Fighting") / 60)

  it_plus = it_plus + get_slay_bonuses()

  local pre_brand_dmg_no_plus = it.damage * stat_mod * skill_mod
  local pre_brand_dmg = pre_brand_dmg_no_plus + it_plus

  if BRC.is.magic_staff(it) then return pre_brand_dmg + get_staff_bonus_dmg(it, dmg_type) end

  if dmg_type == BRC.DMG_TYPE.plain then
    local ego = BRC.get.ego(it)
    if ego and util.contains(BRC.NON_ELEMENTAL_DMG_EGOS, ego) then
      local bonus = BRC.Data.Config.BrandBonus[ego] or BRC.Data.Config.BrandBonus.subtle[ego]
      return bonus.factor * pre_brand_dmg_no_plus + it_plus + bonus.offset
    end
  elseif dmg_type >= BRC.DMG_TYPE.branded then
    local ego = BRC.get.ego(it)
    if ego then
      local bonus = BRC.Data.Config.BrandBonus[ego]
      if not bonus and dmg_type == BRC.DMG_TYPE.scoring then
        bonus = BRC.Data.Config.BrandBonus.subtle[ego]
      end
      if bonus then return bonus.factor * pre_brand_dmg_no_plus + it_plus + bonus.offset end
    end
  end

  return pre_brand_dmg
end
