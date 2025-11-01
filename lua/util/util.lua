---------------------------------------------------------------------------------------------------
-- BRC utility module
-- @module BRC.util
-- General utility functions.
---------------------------------------------------------------------------------------------------

BRC.util = {}

--- Get the keycode for Cntl+char
function BRC.util.cntl(c)
  return string.byte(c:upper()) - 64
end

--- Get key assigned to a crawl command (e.g. "CMD_EXPLORE")
function BRC.util.get_cmd_key(cmd)
  local key = crawl.get_command(cmd)
  if not key or key == "NULL" then return nil end
  -- get_command returns things like "Uppercase Ctrl-S"; we just want 'S'
  local char_key = key:sub(-1)
  return key:contains("Ctrl") and BRC.util.cntl(char_key) or char_key
end

--- Tries sendkeys() first, fallback to do_commands() (which isn't always immediate)
-- @param cmd (string) The command to execute like "CMD_EXPLORE"
function BRC.util.do_cmd(cmd)
  local key = BRC.util.get_cmd_key(cmd)
  if key then
    crawl.sendkeys({ key })
    crawl.flush_input()
  else
    crawl.do_commands({ cmd })
  end
end

---- Lua table helpers ----
--- Sorts the keys of a dictionary/map: vars before tables, then alphabetically by key
-- If a list is passed, will assume it's a list of global variable names
function BRC.util.get_sorted_keys(map_or_list)
  local keys_vars = {}
  local keys_tables = {}

  if BRC.util.is_map(map_or_list) then
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

function BRC.util.is_list(value)
  return value and type(value) == "table" and #value > 0
end

function BRC.util.is_map(value)
  return value and type(value) == "table" and next(value) ~= nil and #value == 0
end
