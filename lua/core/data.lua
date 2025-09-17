--[[
BRC.data - Persistent data management module
Manages persistent data across games and saves
Author: buehler
Dependencies: (none)
--]]

-- Initialize
BRC = BRC or {}
BRC.data = {}

-- Local constants
local BRC_PREFIX = "brc_data_"
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
local GAME_CHANGE_MONITORS = {}

-- Persistent variables - BRC.data defines these in init(), to come after all other persistent data

-- Private variables
local _persistent_var_names = {}
local _persistent_table_names = {}

-- Private functions (defined globally to allow access from chk_lua_save)
function BRC.data._brc_type_of(value)
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

function BRC.data.val2str(value, indent_count)
  if not value then return "nil" end
  indent_count = indent_count or 1
  local indent = string.rep("  ", indent_count)
  local parent_indent = string.rep("  ", indent_count - 1)
  local list_separator = ",\n" .. indent

  local type = BRC.data._brc_type_of(value)
  if type == TYPES.string then
    return string.format('"%s"', value:gsub('"', ""))
  elseif type == TYPES.number then
    return tostring(value)
  elseif type == TYPES.boolean then
    return tostring(value)
  elseif type == TYPES.list then
    local tokens = {}
    for _, v in ipairs(value) do
      tokens[#tokens + 1] = BRC.data.val2str(v, indent_count + 1)
    end
    if #tokens == 0 then return "{}" end
    if #tokens < 4 then return string.format("{ %s }", table.concat(tokens, ", ")) end
    return string.format("{\n%s%s\n%s}", indent, table.concat(tokens, list_separator), parent_indent)
  elseif type == TYPES.dict then
    local tokens = {}
    for k, v in pairs(value) do
      tokens[#tokens + 1] = string.format('["%s"] = %s', k, BRC.data.val2str(v, indent_count + 1))
    end
    if #tokens == 0 then return "{}" end
    return string.format("{\n%s%s\n%s}", indent, table.concat(tokens, list_separator), parent_indent)
  else
    local str = tostring(value) or "nil"
    BRC.log.error(string.format("Unknown data type for value (%s): %s", str, type))
    return "nil"
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
  -- Reset persistent data on new game, or if not created yet
  if you.turns() == 0 or _G[name] == nil then _G[name] = default_value end

  table.insert(chk_lua_save, function()
    local var_type = BRC.data._brc_type_of(_G[name])
    if var_type == TYPES.unknown then return "" end
    return string.format("%s = %s%s", name, BRC.data.val2str(_G[name]), BRC.KEYS.LF)
  end)

  local var_type = BRC.data._brc_type_of(_G[name])
  if var_type == TYPES.list or var_type == TYPES.dict then
    if not util.contains(util.keys(_persistent_table_names), name) then
      _persistent_table_names[#_persistent_table_names + 1] = name
    end
  else
    if not util.contains(_persistent_var_names, name) then
      _persistent_var_names[#_persistent_var_names + 1] = name
    end
  end

  return _G[name]
end

function BRC.data.serialize()
  local tokens = { "\n---PERSISTENT TABLES---\n" }
  for _, name in ipairs(_persistent_table_names) do
    tokens[#tokens + 1] = string.format("%s = %s\n\n", name, BRC.data.val2str(_G[name]))
  end

  tokens[#tokens + 1] = "\n---PERSISTENT VARIABLES---\n"
  for _, name in ipairs(_persistent_var_names) do
    tokens[#tokens + 1] = string.format("%s = %s\n", name, BRC.data.val2str(_G[name]))
  end

  return table.concat(tokens)
end

function BRC.data.erase()
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
      local prev = _G[BRC_PREFIX .. k]
      if prev ~= v then
        failed_reinit = true
        local msg = string.format("Unexpected change to %s: %s -> %s", k, prev, v)
        _G[BRC_PREFIX .. k] = v
        BRC.mpr.lightred(msg)
      end
    end

    if not _G[BRC_PREFIX .. "successful_reload"] then
      failed_reinit = true
      BRC.log.error(string.format("Failed to load persistent data for buehler.rc v%s!", BRC.VERSION))
      BRC.mpr.darkgrey("Try restarting, or set BRC.DEBUG_MESSAGES=True for more info.")
    end

    if failed_reinit and BRC.mpr.yesno("Deactivate buehler.rc?", BRC.COLORS.yellow) then return false end
  end

  for k, v in pairs(GAME_CHANGE_MONITORS) do
    local var_name = BRC_PREFIX .. k
    _G[var_name] = BRC.data.persist(var_name, v)
  end
  _G[BRC_PREFIX .. "successful_reload"] = true

  return true
end

function BRC.data.init()
  GAME_CHANGE_MONITORS.buehler_rc_version = BRC.VERSION
  GAME_CHANGE_MONITORS.buehler_name = you.name()
  GAME_CHANGE_MONITORS.buehler_race = you.race()
  GAME_CHANGE_MONITORS.buehler_class = you.class()

  -- If monitors already are defined, they will keep their values
  for k, v in pairs(GAME_CHANGE_MONITORS) do
    BRC.data.persist(BRC_PREFIX .. k, v)
  end

  -- brc_data_successful_reload comes last, defaults to false. If true, confirms all data reloaded.
  BRC.data.persist(BRC_PREFIX .. "successful_reload", false)
  return BRC.data.verify_reinit()
end
