--[[
BRC.Data - Persistent data management module
Manages persistent data across games and saves
Author: buehler
Dependencies: core/constants.lua, core/util.lua
--]]

-- Initialize BRC namespace and Data module
BRC = BRC or {}
BRC.Data = {}
BRC.data = BRC.Data -- alias

-- Local variables
local _persist_names = {}
local _game_trackers = { -- Values to detect when character is changed
  brc_version = nil,
  brc_name = nil,
  brc_race = nil,
  brc_class = nil,
  brc_turn = nil,
} -- _game_trackers (do not remove this comment)

-- Local functions
local function verify_game_trackers()
  local success = true

  if you.turns() > 0 then
    for k, v in pairs(_game_trackers) do
      local prev = _G[k]
      if prev ~= v then
        success = false
        _G[k] = v
        BRC.log.warning(string.format("Unexpected change of %s: %s -> %s", k, prev, v))
      end
    end

    if not _G.reload_complete then
      success = false
      BRC.log.warning(string.format("Did not reload persistent data for BRC v%s!", BRC.VERSION))
      BRC.mpr.lightgrey("[BRC] This usually occurs following a malformed RC file. Attempting backup restore...")
    end
  end

  return success
end

local function verify_num_autopickup_funcs()
  _G.num_autopickup_funcs = BRC.Data.persist("num_autopickup_funcs", 0) -- Use _G to make checklua happy
  if _G.num_autopickup_funcs == 0 then _G.num_autopickup_funcs = #chk_force_autopickup end
  if _G.num_autopickup_funcs == #chk_force_autopickup then return true end

  BRC.log.warning(string.format("%s\nExpected: %s but got: %s",
    "Warning: Extra autopickup funcs detected. (Commonly from reloading a local game.)",
    _G.num_autopickup_funcs,
    #chk_force_autopickup
  ))
  BRC.mpr.lightgrey("If this is unexpected, you might want to restart crawl.")
  if BRC.mpr.yesno("Update expected number of autopickup functions?") then
    _G.num_autopickup_funcs = #chk_force_autopickup
  end

  return nil
end

local function is_usable_backup()
  if
    type(c_persist.BRC) ~= "table"
    or type(c_persist.BRC.Backup) ~= "table"
    or c_persist.BRC.Backup.brc_version ~= BRC.VERSION
    or c_persist.BRC.Backup.brc_name ~= you.name()
    or c_persist.BRC.Backup.brc_race ~= you.race()
    or c_persist.BRC.Backup.brc_class ~= you.class()
  then
    return false
  end

  local turn_diff = you.turns() - c_persist.BRC.Backup.backup_turn
  if turn_diff == 0 then return true end
  return BRC.mpr.yesno(string.format("Use backup from %s turns ago?", turn_diff))
end

local function restore_from_backup()
  if type(c_persist.BRC) ~= "table" or type(c_persist.BRC.Backup) ~= "table" then return false end
  for name, value in pairs(c_persist.BRC.Backup) do
    BRC.data.persist(name, value)
    _G[name] = c_persist.BRC.Backup[name]
  end
end

-- Public API

--[[
BRC.Data.persist() Creates a persistent global variable or table, initialized to the default value if it doesn't exist.
The variable/table is automatically persisted across saves.
Returns the current value.
Usage: variable_name = BRC.Data.persist("variable_name", default_value)
--]]
function BRC.Data.persist(name, default_value)
  -- Set global if it doesn't exist, or on turn 0
  if you.turns() == 0 or _G[name] == nil then _G[name] = default_value end

  if not util.contains({ "table", "string", "number", "boolean" }, type(_G[name])) then
    BRC.log.error(string.format("Cannot persist %s. Its value (%s) is of type %s", name, _G[name], type(_G[name])))
  elseif not util.contains(_persist_names, name) then
    _persist_names[#_persist_names + 1] = name
    table.insert(chk_lua_save, function()
      if not _G[name] then return "" end
      return name .. " = " .. BRC.util.tostring(_G[name]) .. BRC.KEYS.LF
    end)
  end

  return _G[name]
end

function BRC.Data.serialize()
  local tokens = { "\n---PERSISTENT TABLES---\n" }
  for _, name in ipairs(_persist_names) do
    if type(_G[name]) == "table" then
      tokens[#tokens + 1] = string.format("%s = %s\n\n", name, BRC.util.tostring(_G[name], true))
    end
  end

  tokens[#tokens + 1] = "\n---PERSISTENT VARIABLES---\n"
  for _, name in ipairs(_persist_names) do
    if type(_G[name]) ~= "table" then
      tokens[#tokens + 1] = string.format("%s = %s\n", name, BRC.util.tostring(_G[name], true))
    end
  end

  return table.concat(tokens)
end

function BRC.Data.erase()
  if _persist_names then
    for _, name in ipairs(_persist_names) do
      _G[name] = nil
    end
  end

  _persist_names = {}
  BRC.active = false
  BRC.log.warning("Erased all persistent data and disabled BRC. Restart crawl to reload defaults.")
end

function BRC.Data.init()
  -- Update game trackers; Important that this happens in init()
  _game_trackers.brc_version = BRC.VERSION
  _game_trackers.brc_name = you.name()
  _game_trackers.brc_race = you.race()
  _game_trackers.brc_class = you.class()
  _game_trackers.brc_turn = you.turns()

  -- Ensure turns() is captured on save, before persist() to get the updated value in chk_lua_save before it's checked
  table.insert(chk_lua_save, function()
    _G.brc_turn = you.turns()
    return ""
  end)
  for k, v in pairs(_game_trackers) do
    BRC.Data.persist(k, v)
  end

  -- reload_complete comes after all other data, defaults to false. If true, confirms all data reloaded.
  BRC.Data.persist("reload_complete", false)
end

-- BRC.Data.verify_reinit(): After all feature init(), verifies data restored as expected
-- Returns true if successful, false if failed, nil if warning only
function BRC.Data.verify_reinit()
  local success = true

  if not verify_game_trackers() then success = false end
  local autopickup_valid = verify_num_autopickup_funcs()
  if not autopickup_valid then success = autopickup_valid end -- False, or nil for warning only

  -- Update game trackers, to compare on next init()
  for k, v in pairs(_game_trackers) do
    BRC.Data.persist(k, v)
  end

  _G.reload_complete = true
  return success
end

-- Backup and Restore from c_persist.BRC.Backup
function BRC.Data.backup()
  if type(c_persist.BRC) ~= "table" then c_persist.BRC = {} end
  c_persist.BRC.Backup = {}
  for _, name in ipairs(_persist_names) do
    c_persist.BRC.Backup[name] = _G[name]
  end
  c_persist.BRC.Backup.backup_turn = you.turns()
end

function BRC.Data.try_restore()
  if not is_usable_backup() then
    BRC.mpr.red("[BRC] Failed to restore backup. Persistent data may have been lost. ")
    BRC.log.info("For detailed startup info, set BRC.Config.show_debug_messages=True.")
    return false
  end

  restore_from_backup()
  BRC.mpr.green("[BRC] Restored data from backup.")
  return true
end
