-- Manages persistent data across games and saves --

local persistent_var_names
local persistent_table_names
local GET_VAL_STRING = {}
GET_VAL_STRING = {
  str = function(value)
      return "\"" .. value .. "\""
  end,
  int = function(value)
      return value
  end,
  bool = function(value)
      return value and "true" or "false"
  end,
  list = function(value)
      local tokens = {}
      for _,v in ipairs(value) do
          tokens[#tokens+1] = GET_VAL_STRING[get_var_type(v)](v)
      end
      return "{" .. table.concat(tokens, ", ") .. "}"
  end,
  dict = function(value)
      local tokens = {}
      for k,v in pairs(value) do
        tokens[#tokens+1] = string.format("[\"%s\"]=%s", k, GET_VAL_STRING[get_var_type(v)](v))
      end
      return "{" .. table.concat(tokens, ", ") .. "}"
  end
}

-- Creates a persistent global variable or table, initialized to the default value
-- Once initialized, the variable is persisted across saves without re-init
function create_persistent_data(name, default_value)
  if _G[name] == nil then
      _G[name] = default_value
  end

  table.insert(chk_lua_save,
      function()
          local type = get_var_type(_G[name])
          if not GET_VAL_STRING[type] then
              crawl.mpr("Unknown persistence type: " .. type)
              return
          end
          return name .. " = " ..GET_VAL_STRING[type](_G[name]) .. KEYS.LF
      end)

  local var_type = get_var_type(_G[name])
  if var_type == "list" or var_type == "dict" then
    persistent_table_names[#persistent_table_names+1] = name
  else
    persistent_var_names[#persistent_var_names+1] = name
  end
end

-- For debugging: dump all persistent data
function dump_persistent_data()
  local tokens = { "\n---PERSISTENT TABLES---\n" }
  for _,name in ipairs(persistent_table_names) do
    tokens[#tokens+1] = name
    tokens[#tokens+1] = ":\n"
    if get_var_type(_G[name]) == "list" then
      for _,item in ipairs(_G[name]) do
        tokens[#tokens+1] = "  "
        tokens[#tokens+1] = item
        tokens[#tokens+1] = "\n"
      end
    else
      for k,v in pairs(_G[name]) do
        tokens[#tokens+1] = "  "
        tokens[#tokens+1] = k
        tokens[#tokens+1] = " = "
        tokens[#tokens+1] = tostring(v)
        tokens[#tokens+1] = "\n"
      end
    end
  end

  tokens[#tokens+1] = "\n---PERSISTENT VARIABLES---\n"
  for _,name in ipairs(persistent_var_names) do
    tokens[#tokens+1] = name
    tokens[#tokens+1] = " = "
    tokens[#tokens+1] = tostring(_G[name])
    tokens[#tokens+1] = "\n"
  end

  return table.concat(tokens)
end

function get_var_type(value)
  local t = type(value)
  if t == "string" then return "str"
  elseif t == "number" then return "int"
  elseif t == "boolean" then return "bool"
  elseif t == "table" then
      if #value > 0 then return "list"
      else return "dict"
      end
  end
  crawl.mpr("Unsupported type for value: " .. tostring(value) .. " (" .. t .. ")")
end

function init_persistent_data()
  if CONFIG.debug_init then crawl.mpr("Initializing persistent-data") end

  persistent_var_names = {}
  persistent_table_names = {}
end

function clear_persistent_data()
  if persistent_var_names then
    for _,name in ipairs(persistent_var_names) do
      _G[name] = nil
    end
  end

  if persistent_table_names then
    for _,name in ipairs(persistent_table_names) do
      _G[name] = nil
    end
  end

  persistent_var_names = {}
  persistent_table_names = {}
end
