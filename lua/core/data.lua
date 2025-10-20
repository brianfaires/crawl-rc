--[[
BRC.Data - Persistent data management module
Manages persistent data across games and saves
Author: buehler
Dependencies: core/constants.lua, core/util.lua
--]]

---- Initialize BRC namespace and Data module
BRC = BRC or {}
BRC.Data = {}
BRC.Data.BRC_FEATURE_NAME = "data-manager" -- Included as a feature for Config override

-- Config values for data dumps
BRC.Data.Config = {
  max_lines_per_table = 200, -- Avoid huge tables (alert_monsters.Config.Alerts) in debug dumps
  skip_pointers = true, -- Don't dump functions and userdata (they only show a hex address)

  unskilled_egos_usable = false,
  BrandBonus = {
    chaos = { factor = 1.15, offset = 2.0 }, -- Approximate weighted average
    distort = { factor = 1.0, offset = 6.0 },
    drain = { factor = 1.25, offset = 2.0 },
    elec = { factor = 1.0, offset = 4.5 },   -- 3.5 on avg; fudged up for AC pen
    flame = { factor = 1.25, offset = 0 },
    freeze = { factor = 1.25, offset = 0 },
    heavy = { factor = 1.8, offset = 0 },    -- Speed is accounted for elsewhere
    pain = { factor = 1.0, offset = you.skill("Necromancy") / 2 },
    spect = { factor = 1.7, offset = 0 },    -- Fudged down for increased incoming damage
    venom = { factor = 1.0, offset = 5.0 },  -- 5 dmg per poisoning

    subtle = { -- Values estimated for weapon comparisons
      antimagic = { factor = 1.1, offset = 0 },
      holy = { factor = 1.15, offset = 0 },
      penet = { factor = 1.3, offset = 0 },
      protect = { factor = 1.15, offset = 0 },
      reap = { factor = 1.3, offset = 0 },
      vamp = { factor = 1.2, offset = 0 },
    },
  },
} -- BRC.Data.Config (do not remove this comment)

---- Local constants ----
local RESTORE_TABLE = "_brc_persist_restore_table"

---- Local variables ----
local _failures = {}
local _persist_names = {}
local pushed_restore_table_creation = false

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

local function try_restore()
  if not is_usable_backup() then
    BRC.mpr.red("[BRC] Unable to restore from backup. Persistent data reset to defaults.")
    BRC.log.info("For detailed startup info, set BRC.Config.show_debug_messages=True.")
    return false
  end

  for _, name in ipairs(_failures) do
    _G[name] = BRC.Data.persist(name, c_persist.BRC.Backup[name])
  end
  BRC.mpr.green("[BRC] Restored data from backup.")
  _failures = {}
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
    BRC.log.error(string.format("Cannot persist %s. Default value is of type %s", name, t))
    return default_value
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
    BRC.log.debug(BRC.text.red(name .. " failed to restore from chk_lua_save."))
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
      return RESTORE_TABLE .. "." .. name .. " = " .. BRC.util.tostring(_G[name]) .. "\n"
    end)
  end

  return _G[name]
end

function BRC.Data.serialize()
  local tokens = { BRC.text.lightmagenta("\n---PERSISTENT VARIABLES---\n") }
  local sorted_keys = BRC.util.get_sorted_keys(_persist_names)
  for _, key in ipairs(sorted_keys) do
    tokens[#tokens + 1] = string.format("%s = %s\n", key, BRC.util.tostring(_G[key], true))
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
  BRC.log.warning("Erased persistent data and disabled BRC. Restart crawl to reload defaults.")
end

-- @return true if no persist errors, false if failed restore, nil for user-accepted errors
function BRC.Data.handle_reinit_errors()
  if #_failures == 0 then return true end
  local msg = "%s persistent variables did not restore: (%s)"
  BRC.log.error(msg:format(#_failures, table.concat(_failures, ", ")), true)

  for _ = 1, 5 do
    if BRC.mpr.yesno("Try restoring from backup?") then break end
    if BRC.mpr.yesno("Are you sure? Data will reset to defaults.") then return nil end
  end
  if try_restore() then return nil end
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
