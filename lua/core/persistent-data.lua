--[[
BRC.data - Persistent data management module
Manages persistent data across games and saves
--]]

-- Initialize BRC.data module
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

-- Private variables
local _persistent_var_names
local _persistent_table_names

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

local function dump_var(value)
  local type = typeof(value)
  if type == TYPES.string then
    return '"' .. value.gsub('"', "") .. '"'
  elseif type == TYPES.number then
    return tostring(value)
  elseif type == TYPES.boolean then
    return tostring(value)
  elseif type == TYPES.list then
    local tokens = {}
    for _, v in ipairs(value) do
      tokens[#tokens + 1] = dump_var(v)
    end
    return "{" .. table.concat(tokens, ", ") .. "}"
  elseif type == TYPES.dict then
    local tokens = {}
    for k, v in pairs(value) do
      tokens[#tokens + 1] = string.format('["%s"] = %s', k, dump_var(v))
    end
    return "{" .. table.concat(tokens, ", ") .. "}"
  else
    local str = tostring(value) or "nil"
    BRC.error("Unknown data type for value (" .. str .. "): " .. type)
    return nil
  end
end

-- Public API

--[[
create() declares a persistent global variable or table, initialized to the default value if it doesn't exist.
The variable/list/dict is automatically persisted across saves. Function returns the current value.

Usage: variable_name = BRC.data.create("variable_name", default_value)
--]]
function BRC.data.create(name, default_value)
  if _G[name] == nil then _G[name] = default_value end

  table.insert(chk_lua_save, function()
    local var_type = typeof(_G[name])
    if var_type == TYPES.unknown then return "" end
    return name .. " = " .. dump_var(_G[name]) .. KEYS.LF
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
    tokens[#tokens + 1] = name
    tokens[#tokens + 1] = ":\n"
    if typeof(_G[name]) == TYPES.list then
      for _, item in ipairs(_G[name]) do
        tokens[#tokens + 1] = "  "
        tokens[#tokens + 1] = dump_var(item)
        tokens[#tokens + 1] = "\n"
      end
    else
      for k, v in pairs(_G[name]) do
        tokens[#tokens + 1] = "  "
        tokens[#tokens + 1] = tostring(k)
        tokens[#tokens + 1] = " = "
        tokens[#tokens + 1] = dump_var(v)
        tokens[#tokens + 1] = "\n"
      end
    end
  end

  tokens[#tokens + 1] = "\n---PERSISTENT VARIABLES---\n"
  for _, name in ipairs(_persistent_var_names) do
    tokens[#tokens + 1] = name
    tokens[#tokens + 1] = " = "
    tokens[#tokens + 1] = tostring(_G[name])
    tokens[#tokens + 1] = "\n"
  end

  BRC.dump.text(table.concat(tokens), char_dump)
end

function BRC.data.init(full_reset)
  -- Clear persistent data (data is created via BRC.data.create)
  if full_reset then
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
Verifies data reinitialization and game state consistency
This should be called after all features have run init() to declare their data
--]]
function BRC.data.verify_reinit()
  local failed_reinit = false
  local GAME_CHANGE_MONITORS = {
    buehler_rc_version = BRC.VERSION,
    buehler_name = you.name(),
    buehler_race = you.race(), -- this breaks RC parser without 'buehler_' prefix
    buehler_class = you.class(), -- this breaks RC parser without 'buehler_' prefix
    turn = you.turns(), -- this doesn't break it, and relies on ready's `prev_turn` variable
  } -- GAME_CHANGE_MONITORS (do not remove this comment)

  -- Track values that shouldn't change, the turn, and a flag to confirm all data reloaded
  -- Default successful_data_reload to false, to confirm the data reload set it to true
  for k, v in pairs(GAME_CHANGE_MONITORS) do
    BRC.data.create("prev_" .. k, v)
  end
  BRC.data.create("successful_data_reload", false)

  if you.turns() > 0 then
    for k, v in pairs(GAME_CHANGE_MONITORS) do
      local prev = _G["prev_" .. k]
      if prev ~= v then
        failed_reinit = true
        local msg = string.format("Unexpected change to %s: %s -> %s", k, prev, v)
        BRC.mpr.col(msg, COLORS.lightred)
      end
    end

    if not _G.successful_data_reload then
      failed_reinit = true
      local fail_message = string.format("Failed to load persistent data for buehler.rc v%s!", BRC.VERSION)
      BRC.mpr.col("\n" .. fail_message, COLORS.lightred)
      BRC.mpr.col("Try restarting, or set BRC.DEBUG_MESSAGES=True for more info.", COLORS.darkgrey)
    end

    if failed_reinit and BRC.mpr.yesno("Deactivate buehler.rc?", COLORS.yellow) then return false end
  end

  for k, v in pairs(GAME_CHANGE_MONITORS) do
    _G["prev_" .. k] = v
  end
  _G.successful_data_reload = true

  return true
end
