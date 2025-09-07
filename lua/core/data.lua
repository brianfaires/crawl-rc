--[[
BRC.data - Persistent data management module
Manages persistent data across games and saves
--]]

-- Initialize
BRC = BRC or {}
BRC.data = {}

-- Local constants
local TYPES = {
  string = "string",
  number = "number",
  boolean = "boolean",
  list = "list",
  dict = "dict",
  table = "table",
  unknown = "unknown",
}

-- Values to detect when character is changed
local GAME_CHANGE_MONITORS = {
  buehler_rc_version = BRC.VERSION,
  buehler_name = you.name(),
  buehler_race = you.race(), -- using 'race' without a prefix breaks RC parser
  buehler_class = you.class(), -- using 'class' without a prefix breaks RC parser
  buehler_turn = you.turns(),
} -- GAME_CHANGE_MONITORS (do not remove this comment)

-- Persistent variables defined in init(), so it comes after all other persistent data

-- Private variables
local _persistent_var_names = {}
local _persistent_table_names = {}

-- Local functions
local function typeof(value)
  local t = type(value)
  if t == "table" then
    if #value > 0 then
      return TYPES.list
    else
      return TYPES.dict
    end
  elseif t == "string" then
    return TYPES.string
  elseif t == "number" then
    return TYPES.number
  elseif t == "boolean" then
    return TYPES.boolean
  else
    return TYPES.unknown
  end
end

local function to_formatted_string(value)
  local type = typeof(value)
  if type == TYPES.string then
    return string.format('"%s"', value.gsub('"', ""))
  elseif type == TYPES.number then
    return tostring(value)
  elseif type == TYPES.boolean then
    return tostring(value)
  elseif type == TYPES.list then
    local tokens = {}
    for _, v in ipairs(value) do
      tokens[#tokens + 1] = to_formatted_string(v)
    end
    return string.format("{ %s }", table.concat(tokens, ", "))
  elseif type == TYPES.dict then
    local tokens = {}
    for k, v in pairs(value) do
      tokens[#tokens + 1] = string.format('["%s"] = %s', k, to_formatted_string(v))
    end
    return string.format("{ %s }", table.concat(tokens, ", "))
  else
    local str = tostring(value) or "nil"
    BRC.error(string.format("Unknown data type for value (%s): %s", str, type))
    return nil
  end
end

-- Public API

--[[
BRC.data.persist() Creates a persistent global variable or table, initialized to the default value if it doesn't exist.
The variable/list/dict is automatically persisted across saves.
Returns the current value.
Usage: variable_name = BRC.data.persist("variable_name", default_value)
--]]
function BRC.data.persist(name, default_value)
  if _G[name] == nil then _G[name] = default_value end

  table.insert(chk_lua_save, function()
    local var_type = typeof(_G[name])
    if var_type == TYPES.unknown then return "" end
    return string.format("%s = %s%s", name, to_formatted_string(_G[name]), BRC.KEYS.LF)
  end)

  local var_type = typeof(_G[name])
  if var_type == TYPES.list or var_type == TYPES.dict then
    _persistent_table_names[#_persistent_table_names + 1] = name
  else
    _persistent_var_names[#_persistent_var_names + 1] = name
  end

  return _G[name]
end

function BRC.data.dump(char_dump)
  local tokens = { "\n---PERSISTENT TABLES---\n" }
  for _, name in ipairs(_persistent_table_names) do
    tokens[#tokens + 1] = string.format("%s:\n%s\n", name, to_formatted_string(_G[name]))
  end

  tokens[#tokens + 1] = "\n---PERSISTENT VARIABLES---\n"
  for _, name in ipairs(_persistent_var_names) do
    tokens[#tokens + 1] = string.format("%s = %s\n", name, to_formatted_string(_G[name]))
  end

  BRC.dump.text(table.concat(tokens), char_dump)
end

function BRC.data.clear(delete_globals)
  if delete_globals then
    if _persistent_var_names then
      for _, name in ipairs(_persistent_var_names) do
        _G[name] = nil
      end
    end

    if _persistent_table_names then
      for _, name in ipairs(_persistent_table_names) do
        _G[name] = nil
      end
    end
  end

  _persistent_var_names = {}
  _persistent_table_names = {}
end

--[[
BRC.data.verify_reinit() Verifies data reinitialization and game state consistency
This should be called after all features have run init() to declare their data
--]]
function BRC.data.verify_reinit()
  local failed_reinit = false
  if you.turns() > 0 then
    for k, v in pairs(GAME_CHANGE_MONITORS) do
      local prev = _G[string.format("prev_%s", k)]
      if prev ~= v then
        failed_reinit = true
        local msg = string.format("Unexpected change to %s: %s -> %s", k, prev, v)
        BRC.mpr.color(msg, BRC.COLORS.lightred)
      end
    end

    if not _G.successful_data_reload then
      failed_reinit = true
      BRC.error(string.format("\nFailed to load persistent data for buehler.rc v%s!", BRC.VERSION))
      BRC.mpr.color("Try restarting, or set BRC.DEBUG_MESSAGES=True for more info.", BRC.COLORS.darkgrey)
    end

    if failed_reinit and BRC.mpr.yesno("Deactivate buehler.rc?", BRC.COLORS.yellow) then return false end
  end

  for k, v in pairs(GAME_CHANGE_MONITORS) do
    local var_name = string.format("prev_%s", k)
    _G[var_name] = BRC.data.persist(var_name, v)
  end
  _G.successful_data_reload = true

  return true
end

function BRC.data.init()
  for k, v in pairs(GAME_CHANGE_MONITORS) do
    BRC.data.persist(string.format("prev_%s", k), v)
  end

  -- successful_data_reload comes last, defaults to false. If true, confirms all data reloaded.
  BRC.data.persist("successful_data_reload", false)
  return BRC.data.verify_reinit()
end
