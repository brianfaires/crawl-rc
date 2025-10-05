--[[
BRC.data - Persistent data management module
Manages persistent data across games and saves
Author: buehler
Dependencies: core/util.lua
--]]

-- Initialize
BRC = BRC or {}
BRC.data = {}

-- Local constants
local BRC_PREFIX = "brc_data_"
local VALID_PERSISTENCE_TYPES = { "table", "string", "number", "boolean" }


-- Local variables
local _persistent_var_names = {}
local _persistent_table_names = {}
local game_trackers = {} -- Values to detect when character is changed

-- Public API

--[[
BRC.data.persist() Creates a persistent global variable or table, initialized to the default value if it doesn't exist.
The variable/table is automatically persisted across saves.
Returns the current value.
Usage: variable_name = BRC.data.persist("variable_name", default_value)
--]]
function BRC.data.persist(name, default_value)
  -- Set global if it doesn't exist, or on turn 0
  if you.turns() == 0 or _G[name] == nil then _G[name] = default_value end

  if not util.contains(VALID_PERSISTENCE_TYPES, type(_G[name])) then
    BRC.log.error(string.format("Cannot persist %s. Its value (%s) is of type %s", name, _G[name], type(_G[name])))
    return _G[name]
  end


  if type(_G[name]) == "table" then
    if util.contains(util.keys(_persistent_table_names), name) then return _G[name] end
    _persistent_table_names[#_persistent_table_names + 1] = name
  else
    if util.contains(_persistent_var_names, name) then return _G[name] end
    _persistent_var_names[#_persistent_var_names + 1] = name
  end

  table.insert(chk_lua_save, function() return name .. " = " .. BRC.util.tostring(_G[name]) .. BRC.KEYS.LF end)

  return _G[name]
end

function BRC.data.serialize()
  local tokens = { "\n---PERSISTENT TABLES---\n" }
  for _, name in ipairs(_persistent_table_names) do
    if type(_G[name]) == "table" then
      tokens[#tokens + 1] = string.format("%s = %s\n\n", name, BRC.util.tostring(_G[name]))
    end
  end

  tokens[#tokens + 1] = "\n---PERSISTENT VARIABLES---\n"
  for _, name in ipairs(_persistent_var_names) do
    if type(_G[name]) ~= "table" then
      tokens[#tokens + 1] = string.format("%s = %s\n", name, BRC.util.tostring(_G[name]))
    end
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
  BRC.active = false
  BRC.log.warning("Erased all persistent data and disabled BRC. Restart crawl to reload defaults.")
end

--[[
BRC.data.verify_reinit() Verifies data reinitialization and game state consistency
This should be called after all features have run init() to declare their data
--]]
function BRC.data.verify_reinit()
  local failed_reinit = false
  if you.turns() > 0 then
    for k, v in pairs(game_trackers) do
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
      BRC.log.error(string.format("Persistent data not loaded for buehler.rc v%s!", BRC.VERSION))
      BRC.mpr.darkgrey("Try restarting, or set BRC.Config.show_debug_messages=True for more info.")
    end
  end

  for k, v in pairs(game_trackers) do
    local var_name = BRC_PREFIX .. k
    _G[var_name] = BRC.data.persist(var_name, v)
  end
  _G[BRC_PREFIX .. "successful_reload"] = true

  if failed_reinit and BRC.mpr.yesno("Deactivate buehler.rc?", BRC.COLORS.yellow) then return false end
  return true
end

function BRC.data.init()
  game_trackers.buehler_rc_version = BRC.VERSION
  game_trackers.buehler_name = you.name()
  game_trackers.buehler_race = you.race()
  game_trackers.buehler_class = you.class()

  -- If monitors already are defined, they will keep their values
  for k, v in pairs(game_trackers) do
    BRC.data.persist(BRC_PREFIX .. k, v)
  end

  -- brc_data_successful_reload comes last, defaults to false. If true, confirms all data reloaded.
  BRC.data.persist(BRC_PREFIX .. "successful_reload", false)
  return BRC.data.verify_reinit()
end
