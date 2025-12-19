---------------------------------------------------------------------------------------------------
-- BRC utility module
-- @module BRC.util
-- General utility functions.
---------------------------------------------------------------------------------------------------

BRC.util = {}

--- Get the keycode for Cntl+char
function BRC.util.cntl(c)
  if c >= '0' and c <= '9' or c >= 'a' and c <= 'z' then
    return string.byte(c) - 96
  elseif c >= 'A' and c <= 'Z' then
    return string.byte(c) - 64
  end

  BRC.mpr.error("Unsupported character sent to BRC.util.cntl: %s", c)
  return nil
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
--- Add or remove an item from a list
function BRC.util.add_or_remove(list, item, add)
  if add then
    list[#list + 1] = item
  else
    util.remove(list, item)
  end
end

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

--- Compare version (x.y) to crawl version. Return true if v1 <= crawl version.
function BRC.util.version_is_valid(v1)
  local crawl_v = crawl.version("major")
  local cv_parts = { string.match(crawl_v, "([0-9]+)%.([0-9]+)" ) }
  local v1_parts = { string.match(v1, "([0-9]+)%.([0-9]+)" ) }
  return v1_parts[1] < cv_parts[1]
    or (v1_parts[1] == cv_parts[1] and v1_parts[2] <= cv_parts[2])
end
