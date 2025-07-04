-- Manages persistent data across games and saves --

local persistent_var_names
local persistent_table_names
local PERSISTENT_DATA_TYPE_HANDLERS = {
    str = function(name)
        return name .. " = \"" .. _G[name] .. "\"" .. KEYS.LF
    end,

    int = function(name)
        return name .. " = " .. _G[name] .. KEYS.LF
    end,

    bool = function(name)
        return name .. " = " .. (_G[name] and "true" or "false") .. KEYS.LF
    end,

    list = function(name)
        local cmd_init = name .. " = {"
        local tokens = {}
        for _,v in ipairs(_G[name]) do
            tokens[#tokens+1] = "\"" .. v .. "\""
        end
        return name .. " = {" .. table.concat(tokens, ", ") .. "}" .. KEYS.LF
    end,

    dict = function(name)
        local tokens = {}
        for k,v in pairs(_G[name]) do
          tokens[#tokens+1] = string.format("[\"%s\"]=\"%s\"", k, v) .. KEYS.LF
        end
        return name .. " = {" .. table.concat(tokens, ", ") .. "}" .. KEYS.LF
    end
} -- PERSISTENT_DATA_TYPE_HANDLERS (do not remove this comment)


-- Creates a persistent global variable or table, initialized to the default value
-- Once initialized, the variable is persisted across saves without re-init
function create_persistent_data(name, default_value)
  if _G[name] == nil then
      _G[name] = default_value
  end

  table.insert(chk_lua_save,
      function()
          local type = get_var_type(_G[name])
          if not PERSISTENT_DATA_TYPE_HANDLERS[type] then
              crawl.mpr("Unknown persistence type: " .. type)
              return
          end
          return PERSISTENT_DATA_TYPE_HANDLERS[type](name)
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
        tokens[#tokens+1] = v
        tokens[#tokens+1] = "\n"
      end
    end
  end

  tokens[#tokens+1] = "\n---PERSISTENT VARIABLES---\n"
  for _,name in ipairs(persistent_var_names) do
    tokens[#tokens+1] = name
    tokens[#tokens+1] = " = "
    tokens[#tokens+1] = _G[name]
    tokens[#tokens+1] = "\n"
  end

  local msg = table.concat(tokens)
  crawl.mpr(msg)
  return msg
end

function get_var_type(value)
  if type(value) == "string" then return "str"
  elseif type(value) == "number" then return "int"
  elseif type(value) == "boolean" then return "bool"
  elseif type(value) == "table" then
      if #value > 0 then return "list"
      else return "dict"
      end
  end
  crawl.mpr("Unsupported type: " .. type(value))
end


function init_persistent_data()
  if CONFIG.debug_init then crawl.mpr("Initializing persistent-data") end

  persistent_var_names = {}
  persistent_table_names = {}
end
