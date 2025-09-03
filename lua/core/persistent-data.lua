--[[
BRC.data - Persistent data management module
Manages persistent data across games and saves
--]]

-- Initialize BRC.data module
BRC.data = {}

-- Constants

BRC.data.TYPES = {
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


-- Public API: Creates a persistent global variable or table, initialized to the default value
-- Once initialized, the variable is persisted across saves without re-init
function BRC.data.create(name, default_value)
  if _G[name] == nil then _G[name] = default_value end

  table.insert(chk_lua_save, function()
    local var_type = BRC.data.typeof(_G[name])
    if var_type == BRC.data.TYPES.unknown then return "" end
    return name .. " = " .. BRC.data.tostring(_G[name]) .. KEYS.LF
  end)

  local var_type = BRC.data.typeof(_G[name])
  if var_type == BRC.data.TYPES.list or var_type == BRC.data.TYPES.dict then
    _persistent_table_names[#_persistent_table_names + 1] = name
  else
    _persistent_var_names[#_persistent_var_names + 1] = name
  end
end

-- Public API: Dumps persistent data to character dump
function BRC.data.dump(char_dump)
  BRC.dump.text(BRC.data.serialize(), char_dump)
end

-- Public API: Serializes persistent data to string format
function BRC.data.serialize()
  local tokens = { "\n---PERSISTENT TABLES---\n" }
  for _, name in ipairs(_persistent_table_names) do
    tokens[#tokens + 1] = name
    tokens[#tokens + 1] = ":\n"
    if BRC.data.typeof(_G[name]) == BRC.data.TYPES.list then
      for _, item in ipairs(_G[name]) do
        tokens[#tokens + 1] = "  "
        tokens[#tokens + 1] = BRC.data.tostring(item)
        tokens[#tokens + 1] = "\n"
      end
    else
      for k, v in pairs(_G[name]) do
        tokens[#tokens + 1] = "  "
        tokens[#tokens + 1] = tostring(k)
        tokens[#tokens + 1] = " = "
        tokens[#tokens + 1] = BRC.data.tostring(v)
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

  return table.concat(tokens)
end

-- Public API: Initializes persistent data system
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

-- Public API: Verifies data reinitialization and game state consistency
-- This should be called after all features have run init(), to declare their data
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

function BRC.data.typeof(value)
  local t = type(value)
  if t == BRC.data.TYPES.table then
    if #value > 0 then
      return BRC.data.TYPES.list
    else
      return BRC.data.TYPES.dict
    end
  elseif t == BRC.data.TYPES.string then
    return BRC.data.TYPES.string
  elseif t == BRC.data.TYPES.number then
    return BRC.data.TYPES.number
  elseif t == BRC.data.TYPES.boolean then
    return BRC.data.TYPES.boolean
  else
    return BRC.data.TYPES.unknown
  end
end

function BRC.data.tostring(value)
  local type = BRC.data.typeof(value)
  if type == BRC.data.TYPES.string then
    return '"' .. value:gsub('"', '\\"') .. '"'
  elseif type == BRC.data.TYPES.number then
    return tostring(value)
  elseif type == BRC.data.TYPES.boolean then
    return tostring(value)
  elseif type == BRC.data.TYPES.list then
    local tokens = {}
    for _, v in ipairs(value) do
      tokens[#tokens + 1] = BRC.data.tostring(v)
    end
    return "{" .. table.concat(tokens, ", ") .. "}"
  elseif type == BRC.data.TYPES.dict then
    local tokens = {}
    for k, v in pairs(value) do
      tokens[#tokens + 1] = string.format('["%s"] = %s', k, BRC.data.tostring(v))
    end
    return "{" .. table.concat(tokens, ", ") .. "}"
  else
    local str = tostring(value) or "nil"
    BRC.error("Unknown data type for value (" .. str .. "): " .. type)
    return nil
  end
end
