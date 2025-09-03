--[[
BRC (Buehler RC) Core Module
This module serves as the central coordinator for all feature modules
It automatically loads any global table that contains `BRC_FEATURE_NAME`
It then manages the feature's lifecycle and hook dispatching
--]]

-- Global BRC table
BRC = {}
BRC.VERSION = "1.1.0"

-- Local configuration
local SHOW_DEBUG_MESSAGES = true

-- Local constants
local HOOK_FUNCTIONS = {
  "init",
  "c_answer_prompt",
  "c_assign_invletter",
  "c_message",
  "ready",
}

local MSG_COLORS = {
  error = "lightred",
  warning = "yellow",
  info = "lightgrey",
  debug = "lightblue",
}

-- Local state
local _features = {}
local _hooks = {}

-- Local functions
local function is_feature_module(module_table)
  return module_table and module_table.BRC_FEATURE_NAME and type(module_table.BRC_FEATURE_NAME) == "string"
end

local function log_message(message, context, color)
  message = message or "Unknown message"
  color = color or MSG_COLORS.info
  local msg = string.format("[BRC] %s", message)
  if context then msg = msg .. string.format(" (Context: %s)", context) end
  crawl.mpr(table.concat({ "<", color, ">", msg, "</", color, ">" }))
end

-- Prevent feature errors from crashing the entire system
local function safe_call(feature_name, func, ...)
  if not func then return end

  local success, result = pcall(func, ...)
  if not success then BRC.error("Function call failed for:" .. feature_name, result) end
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
    safe_call(hook_info.name, hook_info.func, ...)
  end
end

-- Public API
function BRC.register_feature(feature_name, feature_module)
  if not feature_name or not feature_module then
    BRC.error("Invalid feature registration: missing name or module")
    return false
  end

  if _features[feature_name] then
    BRC.error(string.format("Feature '%s' is already registered", feature_name))
    return false
  end

  -- Register the feature and its hooks
  _features[feature_name] = feature_module
  register_hooks(feature_name, feature_module)

  -- Initialize the feature
  if feature_module.init then safe_call(feature_name, feature_module.init) end

  return true
end

function BRC.unregister_feature(feature_name)
  if not _features[feature_name] then
    BRC.error(string.format("Feature '%s' is not registered", feature_name))
    return false
  end

  unregister_hooks(feature_name)
  _features[feature_name] = nil

  BRC.debug(string.format("Feature '%s' unregistered", feature_name))
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
        BRC.debug(string.format("Registered %s from _G.%s", feature_name, name))
      else
        BRC.error(string.format("Failed to register feature from: _G.%s", name))
      end
    end
  end

  BRC.debug(string.format("Feature loading complete. Loaded %d features.", loaded_count))
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

-- Logging methods
function BRC.error(message, context)
  log_message(message, context, MSG_COLORS.error)
end

function BRC.warn(message, context)
  log_message(message, context, MSG_COLORS.warning)
end

function BRC.log(message, context)
  log_message(message, context, MSG_COLORS.info)
end

function BRC.debug(message, context)
  if not SHOW_DEBUG_MESSAGES then return end
  log_message(message, context, MSG_COLORS.debug)
end
