-- BRC (Buehler RC) Core Module
-- This module serves as the central coordinator for all feature modules
-- It automatically manages feature lifecycle and hook dispatching

-- Global BRC table
BRC = {}

-- Private state
local _features = {}
local _hooks = {}

-- Hook function names that features can implement
local HOOK_FUNCTIONS = {
    "ready",
    "ch_message", 
    "c_answer_prompt",
    "init"
}

-- Error handling constants
local ERROR_COLORS = {
    error = "lightred",
    warning = "yellow",
    info = "lightgrey"
}

-- Private helper functions
local function _log_error(feature_name, error_msg, context)
    local error_text = string.format("[BRC Error] %s: %s", feature_name or "Unknown", error_msg or "Unknown error")
    if context then
        error_text = error_text .. string.format(" (Context: %s)", context)
    end
    
    -- Display error to user
    crawl.mpr(error_text, ERROR_COLORS.error)
end

local function _safe_call(feature_name, func, ...)
    if not func then return end
    
    local success, result = pcall(func, ...)
    if not success then
        _log_error(feature_name, result, "Function call failed")
        return nil
    end
    
    return result
end

local function _register_hooks(feature_name, feature_module)
    for _, hook_name in ipairs(HOOK_FUNCTIONS) do
        if feature_module[hook_name] then
            if not _hooks[hook_name] then
                _hooks[hook_name] = {}
            end
            table.insert(_hooks[hook_name], {
                name = feature_name,
                func = feature_module[hook_name]
            })
        end
    end
end

local function _unregister_hooks(feature_name)
    for hook_name, hook_list in pairs(_hooks) do
        for i = #hook_list, 1, -1 do
            if hook_list[i].name == feature_name then
                table.remove(hook_list, i)
            end
        end
    end
end

-- Public API
function BRC:register_feature(feature_name, feature_module)
    if not feature_name or not feature_module then
        _log_error("BRC", "Invalid feature registration: missing name or module")
        return false
    end
    
    if _features[feature_name] then
        _log_error("BRC", string.format("Feature '%s' is already registered", feature_name))
        return false
    end
    
    -- Store the feature
    _features[feature_name] = feature_module
    
    -- Register its hooks
    _register_hooks(feature_name, feature_module)
    
    -- Initialize immediately
    if feature_module.init then
        _safe_call(feature_name, feature_module.init)
    end
    
    return true
end

function BRC:unregister_feature(feature_name)
    if not _features[feature_name] then
        return false
    end
    
    -- Remove hooks
    _unregister_hooks(feature_name)
    
    -- Remove feature
    _features[feature_name] = nil
    
    return true
end

function BRC:get_feature(feature_name)
    return _features[feature_name]
end

function BRC:list_features()
    local names = {}
    for name, _ in pairs(_features) do
        table.insert(names, name)
    end
    return names
end

function BRC:call_hook(hook_name, ...)
    if not _hooks[hook_name] then
        return
    end
    
    for _, hook_info in ipairs(_hooks[hook_name]) do
        _safe_call(hook_info.name, hook_info.func, ...)
    end
end

function BRC:get_version()
    return "1.0.0"
end

-- Convenience methods for common hooks
function BRC:ready()
    self:call_hook("ready")
end

function BRC:ch_message(text, channel)
    self:call_hook("ch_message", text, channel)
end

function BRC:c_answer_prompt(prompt)
    self:call_hook("c_answer_prompt", prompt)
end

-- Public error logging method
function BRC:log_error(message, context)
    local error_text = string.format("[BRC] %s", message or "Unknown error")
    if context then
        error_text = error_text .. string.format(" (Context: %s)", context)
    end
    
    -- Display error to user
    crawl.mpr(error_text, ERROR_COLORS.error)
end
