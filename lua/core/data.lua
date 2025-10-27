--[[
BRC.Data - Persistent data management module
Manages persistent data across games and saves
Author: buehler
Dependencies: core/constants.lua, core/util/*
--]]

---- Initialize BRC namespace and Data module
BRC.Data = {}
BRC.Data.BRC_FEATURE_NAME = "data-manager" -- Included as a feature for Config override

---- Local constants ----
local RESTORE_TABLE = "_brc_persist_restore_table"

---- Local variables ----
-- Init tables in declaration, so persist() can be called before init()
local _failures = {}
local _persist_names = {}
local _default_values = {}
local pushed_restore_table_creation = false -- Set this on file load, not on init()
local cur_location

---- Local functions ----
local function is_usable_backup()
  if
    type(c_persist.BRC) ~= "table"
    or type(c_persist.BRC.Backup) ~= "table"
    or c_persist.BRC.Backup.backup_name ~= you.name()
    or c_persist.BRC.Backup.backup_race ~= you.race()
    or c_persist.BRC.Backup.backup_class ~= you.class()
  then
    return false
  end

  local turn_diff = you.turns() - c_persist.BRC.Backup.backup_turn
  if turn_diff == 0 then return true end
  for _ = 1, 5 do
    if BRC.mpr.yesno("Use backup from " .. turn_diff .. " turns ago?") then return true end
    if BRC.mpr.yesno("Are you sure? Data will reset to defaults.") then return false end
  end
  return true
end

local function try_restore(failed_vars)
  if not is_usable_backup() then
    BRC.mpr.error("Unable to restore from backup. Persistent data reset to defaults.", true)
    BRC.mpr.info("For detailed startup info, set BRC.Config.mpr.show_debug_messages=True.")
    return false
  end

  for _, name in ipairs(failed_vars) do
    _default_values[name] = nil -- Avoid re-init warnings
    _G[name] = BRC.Data.persist(name, c_persist.BRC.Backup[name])
  end
  BRC.mpr.green("[BRC] Restored data from backup.")
  return true
end

---- Public API ----

--- Creates a persistent global variable or table, that retains its value through restarts.
-- Use this pattern to make the global definition obvious: `var = BRC.Data.persist("var", value)`
-- After restarting, the variable/table will not exist until this is called.
-- @param default_value - Variable set to this if it doesn't exist yet
-- @return The current value (whether default or persisted)
function BRC.Data.persist(name, default_value)
  local t = type(default_value)
  if not util.contains({ "table", "string", "number", "boolean", "nil" }, t) then
    BRC.mpr.error(string.format("Cannot persist %s. Default value is of type %s", name, t))
    return default_value
  end

  -- Keep default value for re-init
  if _default_values[name] then
    BRC.mpr.warning("Multiple calls to BRC.Data.persist(" .. name .. ", ...)")
  end
  if type(default_value) == "table" then
    -- Preserve the user's original table (may be in a config, etc)
    default_value = util.copy_table(default_value)
    _default_values[name] = util.copy_table(default_value)
  else
    _default_values[name] = default_value
  end

  -- Try to restore from persistent restore table
  if you.turns() == 0 then
    _G[name] = default_value
  elseif _G[RESTORE_TABLE] and _G[RESTORE_TABLE][name] ~= nil then
    _G[name] = _G[RESTORE_TABLE][name]
    _G[RESTORE_TABLE][name] = nil
  elseif default_value ~= nil and not util.contains(_failures, name) then -- avoid inf loop
    _G[name] = default_value
    _failures[#_failures + 1] = name
    BRC.mpr.debug(BRC.txt.red(name .. " failed to restore from chk_lua_save."))
  end

  -- Create persistent restore table on next startup
  if not pushed_restore_table_creation then
    table.insert(chk_lua_save, function()
      return RESTORE_TABLE .. " = {}\n"
    end)
    pushed_restore_table_creation = true
  end

  -- Set up persist on next startup
  if not util.contains(_persist_names, name) then
    _persist_names[#_persist_names + 1] = name
    table.insert(chk_lua_save, function()
      if _G[name] == nil then return "" end
      return RESTORE_TABLE .. "." .. name .. " = " .. BRC.txt.tostr(_G[name]) .. "\n"
    end)
  end

  return _G[name]
end

function BRC.Data.serialize()
  local tokens = { BRC.txt.lightmagenta("\n---PERSISTENT VARIABLES---\n") }
  local sorted_keys = BRC.util.get_sorted_keys(_persist_names)
  for _, key in ipairs(sorted_keys) do
    tokens[#tokens + 1] = string.format("%s = %s\n", key, BRC.txt.tostr(_G[key], true))
  end
  return table.concat(tokens)
end

function BRC.Data.reset()
  if _persist_names then
    for _, name in ipairs(_persist_names) do
      if type(_default_values[name]) == "table" then
        _G[name] = util.copy_table(_default_values[name])
      else
        _G[name] = _default_values[name]
      end
    end
  end

  BRC.mpr.warning("Reset all persistent data to default values.")
end

-- @return true if no persist errors, false if failed restore, nil for user-accepted errors
function BRC.Data.handle_persist_errors()
  if #_failures == 0 then return true end
  local msg = "%s persistent variables did not restore: (%s)"
  BRC.mpr.error(msg:format(#_failures, table.concat(_failures, ", ")), true)

  for _ = 1, 5 do
    if BRC.mpr.yesno("Try restoring from backup?") then break end
    if BRC.mpr.yesno("Are you sure? Data will reset to defaults.") then return nil end
  end

  -- Whether restore works or not, we should reset _failures
  local failed_vars = _failures
  _failures = {}
  if try_restore(failed_vars) then return nil end
  return false
end

-- Backup and Restore from c_persist.BRC.Backup
function BRC.Data.backup()
  if type(c_persist.BRC) ~= "table" then c_persist.BRC = {} end
  c_persist.BRC.Backup = {}
  c_persist.BRC.Backup.backup_name = you.name()
  c_persist.BRC.Backup.backup_race = you.race()
  c_persist.BRC.Backup.backup_class = you.class()
  c_persist.BRC.Backup.backup_turn = you.turns()
  for _, name in ipairs(_persist_names) do
    c_persist.BRC.Backup[name] = _G[name]
  end
end

---- Hook functions ----
function BRC.Data.init()
  cur_location = you.where()
  if type(c_persist.BRC) ~= "table" then c_persist.BRC = {} end
end

function BRC.Data.ready()
  if you.where() ~= cur_location and not you.have_orb() then
    cur_location = you.where()
    BRC.Data.backup()
  end
end
