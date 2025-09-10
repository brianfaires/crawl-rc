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

-- Local constants
local HOOK_FUNCTIONS = {
  "init",
  "c_answer_prompt",
  "c_assign_invletter",
  "c_message",
  "ready",
}

-- Local variables
local _features = {}
local _hooks = {}
local prev_turn

-- Local functions
local function is_feature_module(module_table)
  return module_table and module_table.BRC_FEATURE_NAME and type(module_table.BRC_FEATURE_NAME) == "string"
end

-- Prevent feature errors from crashing the entire system
local function safe_call(feature_name, func, ...)
  if not func then return end

  local success, result = pcall(func, ...)
  if not success then
    BRC.log.error(string.format("Failure in %s", feature_name), result)
  end
end

-- Hook management
local function register_hooks(feature_name, feature_module)
  for _, hook_name in ipairs(HOOK_FUNCTIONS) do
    if feature_module[hook_name] then
      if not _hooks[hook_name] then _hooks[hook_name] = {} end
      table.insert(_hooks[hook_name], {
        name = feature_name,
        func = feature_module[hook_name],
      })
    end
  end
end

local function unregister_hooks(feature_name)
  for _, hook_list in pairs(_hooks) do
    for i = #hook_list, 1, -1 do
      if hook_list[i].name == feature_name then table.remove(hook_list, i) end
    end
  end
end

local function call_hook(hook_name, ...)
  if not _hooks[hook_name] then return end
  for _, hook_info in ipairs(_hooks[hook_name]) do
    safe_call(hook_info.name .. "." .. hook_name, hook_info.func, ...)
  end
end

-- Public API
function BRC.init()
  -- Handle stale data (switching characters on local instance)
  _features = {}
  _hooks = {}

  BRC.set.macro(BRC.get.command_key("CMD_CHARACTER_DUMP", "#"), "macro_brc_dump_character")

  local loaded_count = BRC.load_all_features()
  if loaded_count == 0 then
    BRC.mpr.lightred("No features loaded. BRC system is inactive.")
    return false
  end

  if not BRC.data.init() then return false end

  -- Success!
  local success_emoji = BRC.Config.emojis and BRC.Emoji.SUCCESS or ""
  local success_text = string.format("Successfully initialized BRC system v%s!", BRC.VERSION)
  crawl.mpr(string.format("\n%s %s %s", success_emoji, BRC.text.lightgreen(success_text), success_emoji))

  prev_turn = -1
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
  if feature_module.init then safe_call(feature_name .. ".init", feature_module.init) end

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
  if _features[feature_name].cleanup then safe_call(feature_name .. ".cleanup", _features[feature_name].cleanup) end

  BRC.log.debug(string.format("Feature '%s' unregistered", BRC.text.lightcyan(feature_name)))
  return true
end

function BRC.load_all_features()
  local loaded_count = 0

  -- Scan the global namespace for feature modules and load them
  for name, value in pairs(_G) do
    if type(value) == "table" and is_feature_module(value) then
      local feature_name = value.BRC_FEATURE_NAME
      local success = BRC.register_feature(feature_name, value)

      if success then
        loaded_count = loaded_count + 1
      else
        BRC.log.error(string.format('Failed to register feature from: _G["%s"]', name))
      end
    end
  end

  BRC.log.debug(string.format("Feature loading complete. Loaded %d features.", loaded_count))
  return loaded_count
end

-- Hook methods
function BRC.ready()
  crawl.redraw_screen()
  if you.turns() == prev_turn then return end
  prev_turn = you.turns()

  call_hook("ready")
  BRC.mpr.consume_queue()
end

function BRC.c_message(text, channel)
  call_hook("c_message", text, channel)
end

function BRC.c_answer_prompt(prompt)
  call_hook("c_answer_prompt", prompt)
end

function BRC.c_assign_invletter(it)
  call_hook("c_assign_invletter", it)
end
