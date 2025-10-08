--[[
BRC (Buehler RC) Core Module
This module serves as the central coordinator for all feature modules
It automatically loads any global module/table that defines `BRC_FEATURE_NAME`
It then manages the feature's lifecycle and hook dispatching
Author: buehler
Dependencies: core/config.lua, core/constants.lua, core/data.lua, core/util.lua
--]]

-- Initialize BRC namespace and non-persistent public variables
BRC = BRC or {}
BRC.VERSION = "1.2.0"
BRC.active = nil

-- Local constants
local HOOK_FUNCTIONS = {
  autopickup = "autopickup",
  c_answer_prompt = "c_answer_prompt",
  c_assign_invletter = "c_assign_invletter",
  c_message = "c_message",
  init = "init",
  ready = "ready",
} -- HOOK_FUNCTIONS (do not remove this comment)

-- Local variables
local _features = {}
local _hooks = {}
local turn_count = nil
local depth = nil

-- Local functions
local function feature_is_disabled(feature_module)
  return feature_module and feature_module.Config and feature_module.Config.disabled
    or BRC.Config[feature_module.BRC_FEATURE_NAME] and BRC.Config[feature_module.BRC_FEATURE_NAME].disabled
end

local function handle_feature_error(feature_name, hook_name, result)
  BRC.log.error(string.format("Failure in %s.%s", feature_name, hook_name), result)
  if BRC.mpr.yesno(string.format("Deactivate %s?", feature_name), BRC.COLOR.yellow) then
    BRC.unregister_feature(feature_name)
  else
    BRC.mpr.okay()
  end
end

local function handle_core_error(hook_name, result, ...)
  local params = {}
  for i = 1, select("#", ...) do
    local param = select(i, ...)
    if param and param.name and type(param.name) == "function" then
      params[#params + 1] = param.name()
    else
      params[#params + 1] = BRC.util.tostring(param):gsub("<", "<_")
    end
  end
  local param_str = table.concat(params, ", ")

  BRC.log.error("BRC failure in safe_call_all_hooks(" .. hook_name .. ", " .. param_str .. ")", result)
  if BRC.mpr.yesno("Deactivate BRC." .. hook_name .. "?", BRC.COLOR.yellow) then
    _hooks[hook_name] = nil
    BRC.mpr.brown("Unregistered hook: " .. tostring(hook_name))
  else
    BRC.mpr.okay("Returning nil to " .. hook_name .. ".")
  end
end

local function override_feature_config_table(source, dest)
  for key, value in pairs(source) do
    if BRC.is.map(value) then
      if not dest[key] then dest[key] = {} end
      override_feature_config_table(value, dest[key])
    else
      dest[key] = value
    end
  end
end

local function override_feature_config(feature_name)
  if not BRC.Config[feature_name] then return end
  if not _features[feature_name].Config then _features[feature_name].Config = {} end
  override_feature_config_table(BRC.Config[feature_name], _features[feature_name].Config)
  if type(_features[feature_name].Config.init) == "function" then _features[feature_name].Config:init() end
end

-- Hook dispatching
local function call_all_hooks(hook_name, ...)
  local last_return_value = nil
  local returning_feature = nil

  for i = #_hooks[hook_name], 1, -1 do
    local hook_info = _hooks[hook_name][i]
    if not feature_is_disabled(_features[hook_info.feature_name]) then
      local success, result = pcall(hook_info.func, ...)
      if not success then
        handle_feature_error(hook_info.feature_name, hook_name, result)
      else
        if last_return_value and result and last_return_value ~= result then
          BRC.log.warning(string.format("Return value mismatch in %s:\n  (first) %s -> %s\n  (final) %s -> %s",
              hook_name,
              returning_feature,
              BRC.util.tostring(last_return_value),
              hook_info.feature_name,
              BRC.util.tostring(result)
          ))
        end

        last_return_value = result
        returning_feature = hook_info.feature_name
      end
    end
  end

  return last_return_value
end

-- safe_call_all_hooks() - Errors in this function won't show up in crawl, so it is kept very simple + protected.
-- Errors in call_all_hooks() or handle_core_error() are caught by this function.
local function safe_call_all_hooks(hook_name, ...)
  if not BRC.active and hook_name ~= HOOK_FUNCTIONS.init then return end
  if not _hooks or not _hooks[hook_name] then return end

  local success, result = pcall(call_all_hooks, hook_name, ...)
  if success then return result end

  success, result = pcall(handle_core_error, hook_name, result, ...)
  if success then return end

  -- This is a serious error. Failed in the hook, and when we tried to report it.
  BRC.log.error("Failed to report BRC core error!", result)
  if BRC.mpr.yesno("Dump char and deactivate BRC?", BRC.COLOR.yellow) then
    BRC.active = false
    BRC.mpr.brown("BRC deactivated.", "Error in hook: " .. tostring(hook_name))
    pcall(BRC.dump.char, true)
  else
    BRC.mpr.okay()
  end
end

-- Hook management
local function register_all_features(parent_module)
  local loaded_count = 0

  -- Default to scanning the global namespace for modules
  parent_module = parent_module or _G
  if type(parent_module) ~= "table" then
    BRC.log.warning("Invalid parent module (must be a table). Using global namespace instead.")
    parent_module = _G
  end

  -- Scan the namespace for feature modules and load them
  for name, value in pairs(parent_module) do
    if BRC.is_feature_module(value) then
      local feature_name = value.BRC_FEATURE_NAME
      local success = BRC.register_feature(feature_name, value)

      if success then
        BRC.log.debug(string.format("Feature '%s' registered", BRC.text.lightcyan(feature_name)))
        loaded_count = loaded_count + 1
      elseif success == false then
        BRC.log.error(string.format("Failed to register feature: %s. Aborting bulk registration.", name))
        return loaded_count
      end
    end
  end

  return loaded_count
end

-- Public API
function BRC.is_feature_module(maybe_feature_module)
  return maybe_feature_module
    and type(maybe_feature_module) == "table"
    and maybe_feature_module.BRC_FEATURE_NAME
    and type(maybe_feature_module.BRC_FEATURE_NAME) == "string"
    and #maybe_feature_module.BRC_FEATURE_NAME > 0
end

-- BRC.register_feature(): Return true if success, false if error, nil if feature is disabled
function BRC.register_feature(feature_name, feature_module)
  if not feature_name or not feature_module then
    BRC.log.error("Invalid feature registration: missing name or module")
    return false
  elseif _features[feature_name] then
    BRC.log.error(BRC.text.yellow(feature_name) .. " is already registered")
    return false
  elseif feature_is_disabled(feature_name) then
    BRC.log.debug(string.format("Feature '%s' is disabled", BRC.text.lightcyan(feature_name)))
    return nil
  end

  _features[feature_name] = feature_module

  -- Register hooks
  for _, hook_name in pairs(HOOK_FUNCTIONS) do
    if feature_module[hook_name] then
      if not _hooks[hook_name] then _hooks[hook_name] = {} end
      table.insert(_hooks[hook_name], {
        feature_name = feature_name,
        hook_name = hook_name,
        func = feature_module[hook_name],
      })
    end
  end

  -- Handle config init() and overrides
  if type(feature_module.Config) == "table" and type(feature_module.Config.init) == "function" then
    feature_module.Config:init()
  end
  override_feature_config(feature_name)
  return true
end

function BRC.unregister_feature(feature_name)
  if not _features[feature_name] then
    BRC.log.error(string.format("Feature '%s' is not registered", BRC.text.yellow(feature_name)))
    return false
  end

  _features[feature_name] = nil
  for _, hook_list in pairs(_hooks) do
    for i = #hook_list, 1, -1 do
      if hook_list[i].feature_name == feature_name then
        BRC.log.info(string.format("Unregistered hook: %s.%s", hook_list[i].feature_name, hook_list[i].hook_name))
        table.remove(hook_list, i)
      end
    end
  end

  BRC.log.debug(string.format("Feature '%s' unregistered", BRC.text.lightcyan(feature_name)))
  return true
end

function BRC.get_registered_features()
  return _features
end

function BRC.init(parent_module)
  _features = {}
  _hooks = {}

  -- Load and log config
  if BRC.load_config(BRC.config_to_use) then
    BRC.log.info(string.format("Using config: %s", BRC.text.lightcyan(BRC.config_to_use or "Default")))
  elseif type(BRC.config_to_use ~= nil) then
    BRC.log.error(string.format("Failed to load config: %s", BRC.text.red(BRC.config_to_use)))
    return false
  end

  -- Register all features
  local loaded_count = register_all_features(parent_module)
  if loaded_count == 0 then
    BRC.mpr.lightred("No features loaded. BRC is inactive.")
    return false
  end
  BRC.log.debug(string.format("Loaded %d features.", loaded_count, parent_module))

  -- Init all features
  BRC.log.debug(BRC.text.green("Initializing features..."))
  safe_call_all_hooks(HOOK_FUNCTIONS.init)

  -- Add the autopickup hook
  add_autopickup_func(BRC.autopickup)

  -- Register the char_dump macro
  if BRC.Config.offer_debug_notes_on_char_dump then
    BRC.set.macro(BRC.get.command_key("CMD_CHARACTER_DUMP") or "#", "macro_brc_dump_character")
  end

  -- Init and verify persistent data
  BRC.Data.init()
  local reinit_success = BRC.Data.verify_reinit()
  if reinit_success == true then
    BRC.Data.backup() -- Only backup on clean success
    local msg = string.format("Successfully initialized BRC v%s!", BRC.VERSION)
    msg = msg .. BRC.text.blue(string.format(" (%s features loaded)", loaded_count))
    if BRC.EMOJI.SUCCESS then msg = string.format("%s %s %s", BRC.EMOJI.SUCCESS, msg, BRC.EMOJI.SUCCESS) end
    BRC.mpr.lightgreen(string.format("\n%s\n", msg))
  elseif reinit_success == false then
    if not BRC.Data.try_backup_restore() then
      if BRC.mpr.yesno("Deactivate BRC?", BRC.COLOR.yellow) then
        BRC.active = false
        BRC.mpr.lightred("\nBRC is off.\n")
        return false
      end
    end
  end

  if not reinit_success then
    local msg = string.format("Initialized BRC v%s with warnings", BRC.VERSION)
    msg = msg .. BRC.text.blue(string.format(" (%s features loaded)", loaded_count))
    BRC.mpr.magenta(string.format("\n%s\n", msg))
  end

  -- We're a go!
  turn_count = -1
  depth = you.depth()
  BRC.active = true
  BRC.ready()
  return true
end

function BRC.load_config(config_name)
  if type(config_name) ~= "string" or type(BRC.Configs[config_name]) ~= "table" then
    BRC.log.error(string.format("Config '%s' not found", config_name))
    return false
  end

  BRC.config_to_use = config_name
  BRC.Config = BRC.Configs.Default
  for k, v in pairs(BRC.Configs[config_name]) do
    BRC.Config[k] = v
  end

  if type(BRC.Config.init) == "function" then BRC.Config:init() end

  for name, _ in pairs(_features) do
    override_feature_config(name)
  end

  return true
end

-- Hook methods
function BRC.autopickup(it, _)
  return safe_call_all_hooks(HOOK_FUNCTIONS.autopickup, it)
end

function BRC.ready()
  crawl.redraw_screen()

  if you.turns() == turn_count then return end
  turn_count = you.turns()

  if you.depth() ~= depth and not you.have_orb() then
    depth = you.depth()
    BRC.Data.backup()
  end

  safe_call_all_hooks(HOOK_FUNCTIONS.ready)
  BRC.mpr.consume_queue()
end

function BRC.c_message(text, channel)
  safe_call_all_hooks(HOOK_FUNCTIONS.c_message, text, channel)
end

function BRC.c_answer_prompt(prompt)
  if not prompt then return end -- This fires from crawl, e.g. Shop purchase confirmation
  return safe_call_all_hooks(HOOK_FUNCTIONS.c_answer_prompt, prompt)
end

function BRC.c_assign_invletter(it)
  return safe_call_all_hooks(HOOK_FUNCTIONS.c_assign_invletter, it)
end
