-- Manages persistent data across games and saves --

local persistent_var_names
local persistent_table_names

-- Creates a persistent global variable or table, initialized to the default value
-- Once initialized, the variable is persisted across saves without re-init
function create_persistent_data(name, default_value)
  if _G[name] == nil then _G[name] = default_value end

  table.insert(chk_lua_save, function()
    local type = BRC.data.typeof(_G[name])
    if type == BRC.TYPES.unknown then return "" end
    return name .. " = " .. BRC.data.tostring(_G[name]) .. KEYS.LF
  end)

  local var_type = BRC.data.typeof(_G[name])
  if var_type == BRC.TYPES.list or var_type == BRC.TYPES.dict then
    persistent_table_names[#persistent_table_names + 1] = name
  else
    persistent_var_names[#persistent_var_names + 1] = name
  end
end

function dump_persistent_data(char_dump)
  BRC.dump.text(serialize_persistent_data(), char_dump)
end

function serialize_persistent_data()
  local tokens = { "\n---PERSISTENT TABLES---\n" }
  for _, name in ipairs(persistent_table_names) do
    tokens[#tokens + 1] = name
    tokens[#tokens + 1] = ":\n"
    if BRC.data.typeof(_G[name]) == BRC.TYPES.list then
      for _, item in ipairs(_G[name]) do
        tokens[#tokens + 1] = "  "
        tokens[#tokens + 1] = item
        tokens[#tokens + 1] = "\n"
      end
    else
      for k, v in pairs(_G[name]) do
        tokens[#tokens + 1] = "  "
        tokens[#tokens + 1] = k
        tokens[#tokens + 1] = " = "
        tokens[#tokens + 1] = tostring(v)
        tokens[#tokens + 1] = "\n"
      end
    end
  end

  tokens[#tokens + 1] = "\n---PERSISTENT VARIABLES---\n"
  for _, name in ipairs(persistent_var_names) do
    tokens[#tokens + 1] = name
    tokens[#tokens + 1] = " = "
    tokens[#tokens + 1] = tostring(_G[name])
    tokens[#tokens + 1] = "\n"
  end

  return table.concat(tokens)
end



function init_persistent_data(full_reset)
  -- Clear persistent data (data is created via create_persistent_data)
  if full_reset then
    if persistent_var_names then
      for _, name in ipairs(persistent_var_names) do
        _G[name] = nil
      end
    end

    if persistent_table_names then
      for _, name in ipairs(persistent_table_names) do
        _G[name] = nil
      end
    end
  end

  persistent_var_names = {}
  persistent_table_names = {}
end

-- Verify 1. data is from same game, 2. all persistent data was reloaded
-- This should be called after all features have run init(), to declare their data
function verify_data_reinit()
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
    create_persistent_data("prev_" .. k, v)
  end
  create_persistent_data("successful_data_reload", false)

  if you.turns() > 0 then
    for k, v in pairs(GAME_CHANGE_MONITORS) do
      local prev = _G["prev_" .. k]
      if prev ~= v then
        failed_reinit = true
        local msg = string.format("Unexpected change to %s: %s -> %s", k, prev, v)
        BRC.mpr.col(msg, COLORS.lightred)
      end
    end

    if not successful_data_reload then
      failed_reinit = true
      local fail_message = string.format("Failed to load persistent data for buehler.rc v%s!", BUEHLER_RC_VERSION)
      BRC.mpr.col("\n" .. fail_message, COLORS.lightred)
      BRC.mpr.col("Try restarting, or set BRC.DEBUG_MESSAGES=True for more info.", COLORS.darkgrey)
    end

    if failed_reinit and BRC.mpr.yesno("Deactivate buehler.rc?", COLORS.yellow) then return false end
  end

  for k, v in pairs(GAME_CHANGE_MONITORS) do
    _G["prev_" .. k] = v
  end
  successful_data_reload = true

  return true
end
