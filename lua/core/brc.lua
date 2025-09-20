--[[
BRC (Buehler RC) Core Module
This module serves as the central coordinator for all feature modules
It automatically loads any global table that contains `BRC_FEATURE_NAME`
It then manages the feature's lifecycle and hook dispatching
Author: buehler
Dependencies: core/data.lua, core/util.lua
--]]

-- Initialize
BRC = BRC or {}
BRC.VERSION = "1.1.0"
BRC.active = false

-- Local constants
local HOOK_FUNCTIONS = {
  autopickup = "autopickup",
  init = "init",
  c_answer_prompt = "c_answer_prompt",
  c_assign_invletter = "c_assign_invletter",
  c_message = "c_message",
  ready = "ready",
}

-- Local variables
local _features = {}
local _hooks = {}
local prev_turn

-- Local functions
local function is_feature_module(maybe_feature_module)
  return maybe_feature_module and type(maybe_feature_module) == "table"
    and maybe_feature_module.BRC_FEATURE_NAME and type(maybe_feature_module.BRC_FEATURE_NAME) == "string"
end

local function ask_to_deactivate(feature_name)
  if BRC.mpr.yesno(string.format("Deactivate %s?", feature_name), BRC.COLORS.yellow) then
    BRC.unregister_feature(feature_name)
  else
    crawl.mpr("Okay, then.")
  end
end

-- Hook management
local function register_hooks(feature_name, feature_module)
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
end

local function unregister_hooks(feature_name)
  for _, hook_list in pairs(_hooks) do
    for i = #hook_list, 1, -1 do
      if hook_list[i].feature_name == feature_name then
        BRC.log.info(string.format("Unregistered hook: %s.%s", hook_list[i].feature_name, hook_list[i].hook_name))
        table.remove(hook_list, i)
      end
    end
  end
end

local function call_all_hooks(hook_name, ...)
  if not _hooks[hook_name] then return end

  local last_return_value = nil
  local returning_feature = nil

  for i = #_hooks[hook_name], 1, -1 do
    local hook_info = _hooks[hook_name][i]
    local success, result = pcall(hook_info.func, ...)
    if not success then
      BRC.log.error(string.format("Failure in %s.%s", hook_info.feature_name, hook_name), result)
      ask_to_deactivate(hook_info.feature_name, hook_name)
    else
      if last_return_value and result and last_return_value ~= result then
        BRC.log.warning(string.format("Return value mismatch in hook %s:\n  (first) %s -> %s\n  (final) %s -> %s",
          hook_name, returning_feature, BRC.data.BRC.data.val2str(last_return_value),
          hook_info.feature_name, BRC.data.BRC.data.val2str(result))
        )
      end

      last_return_value = result
      returning_feature = hook_info.feature_name
    end
  end

  return last_return_value
end

local function register_all_features(parent_module)
  local loaded_count = 0

  -- Scan the namespace for feature modules and load them
  for name, value in pairs(parent_module) do
    if is_feature_module(value) then
      local feature_name = value.BRC_FEATURE_NAME
      local success = BRC.register_feature(feature_name, value)

      if success then
        loaded_count = loaded_count + 1
      else
        BRC.log.error(string.format('Failed to register feature: %s. Aborting bulk registration.', name))
        return loaded_count
      end
    end
  end

  return loaded_count
end

-- Public API
function BRC.init(parent_module)
  -- Default to scanning the global namespace for modules
  parent_module = parent_module or _G
  if type(parent_module) ~= "table" then
    BRC.log.warning("Invalid parent module (must be a table). Using global namespace instead.")
    parent_module = _G
  end

  -- Handle stale data (ie switching characters on a local instance)
  _features = {}
  _hooks = {}

  -- Load all features, then the data module last
  local loaded_count = register_all_features(parent_module)
  if loaded_count == 0 then
    BRC.mpr.lightred("No features loaded. BRC is inactive.")
    return false
  end
  BRC.log.debug(string.format("Loaded %d features.", loaded_count, parent_module))

  -- Init features
  BRC.log.debug(BRC.text.green("Initializing features..."))
  call_all_hooks(HOOK_FUNCTIONS.init)
  if not BRC.data.init() then
    BRC.log.error("Failed to initialize data module. BRC is inactive.")
    return false
  end

  -- Add the autopickup function
  add_autopickup_func(function(it, _) return BRC.autopickup(it) end)

  -- Register the char_dump macro
  if BRC.Config.debug_notes_on_char_dump then
    BRC.set.macro(BRC.get.command_key("CMD_CHARACTER_DUMP") or "#", "macro_brc_dump_character")
  end

  -- Success!
  local success_emoji = BRC.Config.emojis and BRC.Emoji.SUCCESS or ""
  local success_text = string.format("Successfully initialized BRC system v%s!", BRC.VERSION)
  BRC.mpr.lightgreen(string.format("\n%s %s %s", success_emoji, success_text, success_emoji))

  prev_turn = -1
  BRC.active = true
  BRC.ready()
  return true
end

function BRC.register_feature(feature_name, feature_module)
  if not feature_name or not feature_module then
    BRC.log.error("Invalid feature registration: missing name or module")
    return false
  end

  if _features[feature_name] then
    BRC.log.error(string.format("Feature '%s' is already registered", BRC.text.yellow(feature_name)))
    return false
  end

  _features[feature_name] = feature_module
  register_hooks(feature_name, feature_module)

  BRC.log.debug(string.format("Feature '%s' registered", BRC.text.lightcyan(feature_name)))
  return true
end

function BRC.unregister_feature(feature_name)
  if not _features[feature_name] then
    BRC.log.error(string.format("Feature '%s' is not registered", BRC.text.yellow(feature_name)))
    return false
  end

  unregister_hooks(feature_name)
  _features[feature_name] = nil

  BRC.log.debug(string.format("Feature '%s' unregistered", BRC.text.lightcyan(feature_name)))
  return true
end

-- Hook methods
function BRC.autopickup(it, _)
  return call_all_hooks(HOOK_FUNCTIONS.autopickup, it)
end

function BRC.ready(ignore_turn_check)
  if not BRC.active then return end

  crawl.redraw_screen()
  if you.turns() == prev_turn and not ignore_turn_check then return end
  prev_turn = you.turns()

  call_all_hooks(HOOK_FUNCTIONS.ready)
  BRC.mpr.consume_queue()
end

function BRC.c_message(text, channel)
  if not BRC.active then return end
  call_all_hooks(HOOK_FUNCTIONS.c_message, text, channel)
end

function BRC.c_answer_prompt(prompt)
  if not prompt then return end
  if not BRC.active then return end
  return call_all_hooks(HOOK_FUNCTIONS.c_answer_prompt, prompt)
end

function BRC.c_assign_invletter(it)
  if not BRC.active then return end
  return call_all_hooks(HOOK_FUNCTIONS.c_assign_invletter, it)
end
