--[[
BRC (Buehler RC) Core Module
This module serves as the central coordinator for all feature modules
It automatically loads any global module/table that defines `BRC_FEATURE_NAME`
It then manages the feature's lifecycle and hook dispatching
Author: buehler
Dependencies: core/config.lua, core/constants.lua, core/data.lua, core/util.lua
--]]

---- Initialize BRC namespace and non-persistent public variables
BRC = BRC or {}
BRC.VERSION = "1.2.0"
BRC.active = false
BRC.single_turn_mutes = {}

---- Persistent variables ----
brc_config_full = BRC.Data.persist("brc_config_full", nil)
brc_config_name = BRC.Data.persist("brc_config_name", nil)

---- Local constants ----
local HOOK_FUNCTIONS = {
  autopickup = "autopickup",
  c_answer_prompt = "c_answer_prompt",
  c_assign_invletter = "c_assign_invletter",
  c_message = "c_message",
  init = "init",
  ready = "ready",
} -- HOOK_FUNCTIONS (do not remove this comment)

---- Local variables ----
local _features
local _hooks
local turn_count
local cur_location

---- Local functions ----
local function feature_is_disabled(f)
  return f.Config and f.Config.disabled
    or BRC.Config[f.BRC_FEATURE_NAME] and BRC.Config[f.BRC_FEATURE_NAME].disabled
end

local function handle_feature_error(feature_name, hook_name, result)
  BRC.log.error(string.format("Failure in %s.%s", feature_name, hook_name), result, true)
  if BRC.mpr.yesno(string.format("Deactivate %s?", feature_name), BRC.COL.yellow) then
    BRC.unregister(feature_name)
  else
    BRC.mpr.okay()
  end
end

local function handle_core_error(hook_name, result, ...)
  local params = { hook_name }
  for i = 1, select("#", ...) do
    local param = select(i, ...)
    if param and type(param.name) == "function" then
      params[#params + 1] = "[" .. param.name() .. "]"
    else
      params[#params + 1] = BRC.util.tostring(param, true)
    end
  end

  local msg = "BRC failure in safe_call_all_hooks(" .. table.concat(params, ", ") .. ")"
  BRC.log.error(msg, result, true)
  if BRC.mpr.yesno("Deactivate BRC." .. hook_name .. "?", BRC.COL.yellow) then
    _hooks[hook_name] = nil
    BRC.mpr.brown("Unregistered hook: " .. tostring(hook_name))
  else
    BRC.mpr.okay("Returning nil to " .. hook_name .. ".")
  end
end

-- Config management
local function get_validated_config_name(input_name)
  if type(input_name) ~= "string" then
    BRC.log.warning("Non-string config name: " .. tostring(input_name))
  else
    local config_name = input_name:lower()
    if config_name == "ask" then
      if you.turns() > 0 and brc_config_name then
        return get_validated_config_name(brc_config_name)
      end
    elseif config_name == "previous" then
      if c_persist.BRC and c_persist.BRC.current_config then
        return get_validated_config_name(c_persist.BRC.current_config)
      else
        BRC.log.warning("No previous config found.")
      end
    else
      for k, _ in pairs(BRC.Profiles) do
        if config_name == k:lower() then return k end
      end
      BRC.log.warning("Could not load config: " .. tostring(input_name))
    end
  end

  return BRC.mpr.select("Select a config", util.keys(BRC.Profiles))
end

local function safe_call_string(str, module_name)
  local chunk, err = loadstring(str)
  if not chunk then
    BRC.log.error("Error loading " .. module_name .. ".Config.init string: ", err)
  else
    local success, result = pcall(chunk)
    if not success then
      BRC.log.error("Error executing " .. module_name .. ".Config.init string: ", result)
    end
  end
end

local function override_feature_config_table(source, dest)
  if type(source) ~= "table" then return end

  for key, value in pairs(source) do
    if BRC.is.map(value) then
      if not dest[key] then dest[key] = {} end
      override_feature_config_table(value, dest[key])
    elseif key ~= "init" then
      dest[key] = value
    end
  end
end

local function process_feature_config(feature_name)
  local f = _features[feature_name]
  if not f.Config then
    f.Config = {}
  elseif type(f.Config.init) == "function" then
    f.Config.init()
  elseif type(f.Config.init) == "string" then
    safe_call_string(f.Config.init, feature_name)
  end

  override_feature_config_table(BRC.Config[feature_name], f.Config)
end

-- Hook management
local function call_all_hooks(hook_name, ...)
  local last_return_value = nil
  local returning_feature = nil

  for i = #_hooks[hook_name], 1, -1 do
    local hook_info = _hooks[hook_name][i]
    if not feature_is_disabled(_features[hook_info.feature_name]) then
      if hook_name == HOOK_FUNCTIONS.init then
        BRC.log.debug(string.format("Initialize %s...", BRC.text.lightcyan(hook_info.feature_name)))
      end
      local success, result = pcall(hook_info.func, ...)
      if not success then
        handle_feature_error(hook_info.feature_name, hook_name, result)
      else
        if last_return_value and result and last_return_value ~= result then
          BRC.log.warning(
            string.format(
              "Return value mismatch in %s:\n  (first) %s -> %s\n  (final) %s -> %s",
              hook_name,
              returning_feature,
              BRC.util.tostring(last_return_value, true),
              hook_info.feature_name,
              BRC.util.tostring(result, true)
            )
          )
        end

        last_return_value = result
        returning_feature = hook_info.feature_name
      end
    end
  end

  return last_return_value
end

--- Errors in this function won't show up in crawl, so it's kept simple and safe.
local function safe_call_all_hooks(hook_name, ...)
  if not (_hooks and _hooks[hook_name] and #_hooks[hook_name] > 0) then return end

  local success, result = pcall(call_all_hooks, hook_name, ...)
  if success then return result end

  success, result = pcall(handle_core_error, hook_name, result, ...)
  if success then return end

  -- This is a serious error. Failed in the hook, and when we tried to report it.
  BRC.log.error("Failed to handle BRC core error!", result, true)
  if BRC.mpr.yesno("Dump char and deactivate BRC?", BRC.COL.yellow) then
    BRC.active = false
    BRC.mpr.brown("BRC deactivated.", "Error in hook: " .. tostring(hook_name))
    pcall(BRC.dump.char, true)
  else
    BRC.mpr.okay()
  end
end

local function register_all_features()
  -- Find all feature modules
  local feature_names = {}
  for name, value in pairs(_G) do
    if BRC.is_feature_module(value) then feature_names[#feature_names + 1] = name end
  end

  -- Sort alphabetically (for reproducable behavior)
  table.sort(feature_names)

  -- Register features
  local loaded_count = 0
  for _, name in ipairs(feature_names) do
    local success = BRC.register(_G[name])
    if success then
      loaded_count = loaded_count + 1
    elseif success == false then
      BRC.log.error("Failed to register feature: " .. name .. ". Aborting bulk registration.")
      return loaded_count
    end
  end

  return loaded_count
end

---- Public API ----
function BRC.get_registered_features()
  return _features
end

function BRC.is_feature_module(f)
  return f
    and type(f) == "table"
    and f.BRC_FEATURE_NAME
    and type(f.BRC_FEATURE_NAME) == "string"
    and #f.BRC_FEATURE_NAME > 0
end

-- BRC.register(): Return true if success, false if error, nil if feature is disabled
function BRC.register(f)
  if not BRC.is_feature_module(f) then
    BRC.log.error("Tried to register a non-feature module! Module contents:")
    BRC.dump.var(f)
    return false
  elseif _features[f.BRC_FEATURE_NAME] then
    BRC.log.warning(BRC.text.lightcyan(f.BRC_FEATURE_NAME) .. " already registered! Repeating...")
    BRC.unregister(f.BRC_FEATURE_NAME)
  end

  if feature_is_disabled(f) then
    BRC.log.debug(BRC.text.lightcyan(f.BRC_FEATURE_NAME) .. " is disabled. Skipped registration.")
    return nil
  else
    if not BRC.Config[f.BRC_FEATURE_NAME] then BRC.Config[f.BRC_FEATURE_NAME] = {} end
    if not f.Config then f.Config = {} end
    f.Config.disabled = false
  end

  BRC.log.debug(string.format("Registering %s...", BRC.text.lightcyan(f.BRC_FEATURE_NAME)))
  _features[f.BRC_FEATURE_NAME] = f

  -- Register hooks
  for _, hook_name in pairs(HOOK_FUNCTIONS) do
    if f[hook_name] then
      if not _hooks[hook_name] then _hooks[hook_name] = {} end
      table.insert(_hooks[hook_name], {
        feature_name = f.BRC_FEATURE_NAME,
        hook_name = hook_name,
        func = f[hook_name],
      })
    end
  end

  process_feature_config(f.BRC_FEATURE_NAME)

  return true
end

function BRC.unregister(name)
  if not _features[name] then
    BRC.log.error(BRC.text.yellow(name) .. " is not registered. Cannot unregister.")
    return false
  end

  _features[name] = nil
  local hooks_removed = {}
  for hook_name, hooks in pairs(_hooks) do
    for i = #hooks, 1, -1 do
      if hooks[i].feature_name == name then
        table.remove(hooks, i)
        hooks_removed[#hooks_removed + 1] = hook_name
      end
    end
  end

  BRC.log.info(string.format("Unregistered %s.", BRC.text.lightcyan(name)))
  BRC.log.debug(string.format("Unregistered hooks: (%s)", table.concat(hooks_removed, ", ")))
  return true
end

function BRC.init()
  _features = {}
  _hooks = {}
  turn_count = -1
  cur_location = you.where()
  if type(c_persist.BRC) ~= "table" then c_persist.BRC = {} end

  BRC.log.debug("Load config...")
  local config_name
  if BRC.config_memory and BRC.config_memory:lower() == "full" then
    config_name = BRC.load_config(brc_config_full or brc_config_name or BRC.config_to_use)
    brc_config_full = BRC.Config
  elseif BRC.config_memory and BRC.config_memory:lower() == "name" then
    config_name = BRC.load_config(brc_config_name or BRC.config_to_use)
  else
    config_name = BRC.load_config(BRC.config_to_use)
  end
  brc_config_name = config_name

  BRC.log.debug("Register features...")
  BRC.register(BRC.Data) -- Data must be the first feature registered (so it's last to initialize)
  register_all_features()

  BRC.log.debug("Initialize features...")
  safe_call_all_hooks(HOOK_FUNCTIONS.init)
  local suffix = BRC.text.blue(string.format(" (%s features)", #util.keys(_features)))

  BRC.log.debug("Add non-feature hooks...")
  add_autopickup_func(BRC.autopickup)
  BRC.set.macro(BRC.get.command_key("CMD_CHARACTER_DUMP") or "#", "macro_brc_dump_character")
  BRC.set.macro("\\{5}", "macro_brc_cntl_e")

  BRC.log.debug("Verify persistent data reload...")
  local success = BRC.Data.handle_persist_errors()
  if success then
    BRC.Data.backup() -- Only backup after a clean startup
    local msg = string.format("Successfully initialized BRC v%s!%s", BRC.VERSION, suffix)
    BRC.mpr.lightgreen("\n" .. BRC.text.wrap(msg, BRC.EMOJI.SUCCESS) .. "\n")
  else
    -- success == nil if errors were resolved, false if tried restore but failed
    if success == false and BRC.mpr.yesno("Deactivate BRC?" .. suffix, BRC.COL.yellow) then
      BRC.active = false
      BRC.mpr.lightred("\nBRC is off.\n")
      return false
    end
    BRC.mpr.magenta(string.format("\nInitialized BRC v%s with warnings!%s\n", BRC.VERSION, suffix))
  end

  -- We're a go!
  BRC.active = true
  BRC.ready()
  return true
end

function BRC.load_config(input_config)
  local config_name
  if type(input_config) == "table" then
    BRC.Config = input_config
    config_name = brc_config_name or "Unknown"
  else
    config_name = get_validated_config_name(input_config)
    BRC.Config = util.copy_table(BRC.Profiles.Default)
    for k, v in pairs(BRC.Profiles[config_name]) do
      BRC.Config[k] = v
    end
  end

  -- Do config init() and feature overrides
  if type(BRC.Config.init) == "function" then
    BRC.Config.init()
  elseif type(BRC.Config.init) == "string" then
    safe_call_string(BRC.Config.init, "BRC")
  end
  for name, _ in pairs(_features) do
    process_feature_config(name)
  end

  BRC.log.info("Using config: " .. BRC.text.lightcyan(config_name))
  return config_name
end

function BRC.reset()
  BRC.active = false
  BRC.single_turn_mutes = {}
  BRC.Data.reset()
  BRC.init()
end

---- Crawl hooks ----
function BRC.autopickup(it, _)
  return safe_call_all_hooks(HOOK_FUNCTIONS.autopickup, it)
end

function BRC.ready()
  if not BRC.active then return end
  crawl.redraw_screen()

  -- Unmute single-turn mutes
  util.foreach(BRC.single_turn_mutes, function(m) BRC.set.message_mute(m, false) end)

  if you.turns() > turn_count then
    turn_count = you.turns()

    if you.where() ~= cur_location and not you.have_orb() then
      cur_location = you.where()
      BRC.Data.backup()
    end

    safe_call_all_hooks(HOOK_FUNCTIONS.ready)
  end

  -- Always do this, even if same turn
  BRC.mpr.consume_queue()
end

function BRC.c_message(text, channel)
  if not BRC.active then return end
  safe_call_all_hooks(HOOK_FUNCTIONS.c_message, text, channel)
end

function BRC.c_answer_prompt(prompt)
  if not BRC.active then return end
  if not prompt then return end -- This fires from crawl, e.g. Shop purchase confirmation
  return safe_call_all_hooks(HOOK_FUNCTIONS.c_answer_prompt, prompt)
end

function BRC.c_assign_invletter(it)
  if not BRC.active then return end
  return safe_call_all_hooks(HOOK_FUNCTIONS.c_assign_invletter, it)
end
