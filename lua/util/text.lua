---------------------------------------------------------------------------------------------------
-- BRC utility module
-- @module BRC.txt
-- Text and string functions.
-- Creates string:contains() for all strings
---------------------------------------------------------------------------------------------------

BRC.txt = {}

---- Text parsing ----
--- Search for text within a string, without Lua pattern matching.
-- @return (bool) True if text is found, false otherwise.
function BRC.txt.contains(self, text)
  return self:find(text, 1, true) ~= nil
end
--- Connect string:contains() to BRC.txt.contains()
getmetatable("").__index.contains = BRC.txt.contains

--- Parse the slot and item name from an item pickup message (e.g. "w - a +0 short sword")
-- @return (string, int) The item name and slot index
function BRC.txt.get_pickup_info(text)
  local cleaned = BRC.txt.clean(text)
  if cleaned:sub(2, 4) ~= " - " then return nil end
  return cleaned:sub(5, #cleaned), items.letter_to_index(cleaned:sub(1, 1))
end


---- Color functions - Usage: BRC.txt.white("Hello"), or BRC.txt["15"]("Hello") ----
for k, color in pairs(BRC.COL) do
  BRC.txt[k] = function(text)
    return string.format("<%s>%s</%s>", color, tostring(text), color)
  end
  BRC.txt[color] = BRC.txt[k]
end


---- String manipulation ----
function BRC.txt.capitalize(s)
  if not s or s == "" then return s end
  return string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2))
end

--- Remove newlines and tags from text
function BRC.txt.clean(text)
  if type(text) ~= "string" then return text end
  return text:gsub("\n", ""):gsub("<[^>]*>", "")
end

function BRC.txt.wrap(text, wrapper, no_space)
  if not wrapper then return text end
  return table.concat({ wrapper, text, wrapper }, no_space and "" or " ")
end


---- Conversion to string ----
function BRC.txt.int2char(num)
  return string.char(string.byte("a") + num)
end

function BRC.txt.serialize_chk_lua_save()
  local tokens = { BRC.txt.lightblue("\n---CHK_LUA_SAVE---") }
  for _, func in ipairs(chk_lua_save) do
    local result = func()
    if result and #result > 0 then tokens[#tokens + 1] = util.trim(result) end
  end

  return table.concat(tokens, "\n")
end

function BRC.txt.serialize_inventory()
  local tokens = { BRC.txt.lightcyan("\n---INVENTORY---\n") }
  for _, inv in ipairs(items.inventory()) do
    local base = inv.name("base") or "N/A"
    local cls = inv.class(true) or "N/A"
    local st = inv.subtype() or "N/A"
    tokens[#tokens + 1] = string.format("%s: (%s) Qual: %s", inv.slot, inv.quantity, inv.name())
    tokens[#tokens + 1] = string.format("  Base: %s Class: %s, Subtype: %s\n", base, cls, st)
  end

  return table.concat(tokens)
end

---- BRC.txt.tostr() local helper functions ----
local function limit_lines(str)
  if not str or str == "" then return str end
  if BRC.Config.dump.max_lines_per_table and BRC.Config.dump.max_lines_per_table > 0 then
    local lines = 1
    str:gsub("\n", function() lines = lines + 1 end)
    if lines > BRC.Config.dump.max_lines_per_table then
      return string.format("{ %s lines... }", lines)
    end
  end

  return str
end

local function tostr_string(var, pretty)
  local s
  if var:contains("\n") then
    s = string.format("[[\n%s]]", var)
  else
    s = '"' .. var:gsub('"', "") .. '"'
  end

  if not pretty then return s end
  -- Replace > and < to display the color tags instead of colored text
  return s:gsub(">", "TempGT"):gsub("<", "TempLT"):gsub("TempGT", "<gt>"):gsub("TempLT", "<lt>")
end

local function tostr_list(var, pretty, indents)
  local tokens = {}
  for _, v in ipairs(var) do
    tokens[#tokens + 1] = limit_lines(BRC.txt.tostr(v, pretty, indents + 1))
  end
  if #tokens < 4 and not util.exists(var, function(t) return type(t) == "table" end) then
    return "{ " .. table.concat(tokens, ", ") .. " }"
  else
    local INDENT = string.rep("  ", indents)
    local CHILD_INDENT = string.rep("  ", indents + 1)
    local LIST_SEP = ",\n" .. CHILD_INDENT
    return "{\n" .. CHILD_INDENT .. table.concat(tokens, LIST_SEP) .. "\n" .. INDENT .. "}"
  end
end

local function tostr_map(var, pretty, indents)
  local tokens = {}

  if pretty then
    local keys = BRC.util.get_sorted_keys(var)
    local contains_table = false
    for i = 1, #keys do
      local v = limit_lines(BRC.txt.tostr(var[keys[i]], true, indents + 1))
      if v then
        if type(var[keys[i]]) == "table" then
          contains_table = true
          tokens[#tokens + 1] = string.format('["%s"] = %s', keys[i], v)
        else
          tokens[#tokens + 1] = string.format("%s = %s", keys[i], v)
        end
      end
    end
    if #tokens <= 2 and not contains_table then
      return "{ " .. table.concat(tokens, ", ") .. " }"
    end
  else
    for k, v in pairs(var) do
      local val_str = BRC.txt.tostr(v, pretty, indents + 1)
      if val_str then
        tokens[#tokens + 1] = '["' .. k .. '"] = ' .. val_str
      end
    end
  end

  local INDENT = string.rep("  ", indents)
  local CHILD_INDENT = string.rep("  ", indents + 1)
  local LIST_SEP = ",\n" .. CHILD_INDENT
  return "{\n" .. CHILD_INDENT .. table.concat(tokens, LIST_SEP) .. "\n" .. INDENT .. "}"
end

--- Serializes a variable to a string, for chk_lua_save or data dumps.
-- @param pretty (optional bool) format for human readability
-- @param _indents (optional int) Used internally to format multi-line tables
function BRC.txt.tostr(var, pretty, _indents)
  local var_type = type(var)
  if var_type == "string" then
    return tostr_string(var, pretty)
  elseif var_type == "table" then
    _indents = _indents or 0
    if BRC.util.is_list(var) then
      return tostr_list(var, pretty, _indents)
    elseif BRC.util.is_map(var) then
      return tostr_map(var, pretty, _indents)
    else
      return "{}"
    end
  end

  if BRC.Config.dump.omit_pointers and (var_type == "function" or var_type == "userdata") then
    return nil
  end

  return tostring(var) -- fallback to tostring()
end
