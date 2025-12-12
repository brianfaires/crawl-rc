---------------------------------------------------------------------------------------------------
-- BRC core module
-- @module BRC
-- @author buehler
-- Serves as the central coordinator for all feature modules.
-- Automatically loads any global module/table that defines `BRC_FEATURE_NAME`
-- and manages the feature's lifecycle and hook dispatching.
---------------------------------------------------------------------------------------------------

---- Local constants ----
BRC.VERSION = "1.2.0"
BRC.MIN_CRAWL_VERSION = "0.34"

local HOOK_FUNCTIONS = {
  autopickup = "autopickup",
  c_answer_prompt = "c_answer_prompt",
  c_assign_invletter = "c_assign_invletter",
  c_message = "c_message",
  ch_start_running = "ch_start_running",
  init = "init",
  ready = "ready",
} -- HOOK_FUNCTIONS (do not remove this comment)

---- Local variables ----
local _features
local _hooks
local turn_count = -1 -- Do not reset this in init()

---- Local functions ----
local function char_dump(add_debug_info)
  if add_debug_info then
    crawl.take_note(BRC.dump(true, true))
    BRC.mpr.info("Debug info added to character dump.")
  else
    BRC.mpr.info("No debug info added.")
  end

  BRC.util.do_cmd("CMD_CHARACTER_DUMP")
end

local function feature_is_disabled(f)
  local main = BRC.Config[f.BRC_FEATURE_NAME]
  if main and main.disabled == false then return false end -- catch override not yet applied
  return (f.Config and f.Config.disabled) or (main and main.disabled)
end

local function handle_feature_error(feature_name, hook_name, result)
  BRC.mpr.error(string.format("Failure in %s.%s", feature_name, hook_name), result, true)
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
      params[#params + 1] = BRC.txt.tostr(param, true)
    end
  end

  local msg = "BRC failure in safe_call_all_hooks(" .. table.concat(params, ", ") .. ")"
  BRC.mpr.error(msg, result, true)
  if BRC.mpr.yesno("Deactivate BRC." .. hook_name .. "?", BRC.COL.yellow) then
    _hooks[hook_name] = nil
    BRC.mpr.brown("Unregistered hook: " .. tostring(hook_name))
  else
    BRC.mpr.okay("Returning nil to " .. hook_name .. ".")
  end
end

-- Hook management
local function call_all_hooks(hook_name, ...)
  local last_return_value = nil
  local returning_feature = nil

  for i = #_hooks[hook_name], 1, -1 do
    local hook_info = _hooks[hook_name][i]
    if not feature_is_disabled(_features[hook_info.feature_name]) then
      if hook_name == HOOK_FUNCTIONS.init then
        BRC.mpr.debug(string.format("Initialize %s...", BRC.txt.lightcyan(hook_info.feature_name)))
      end
      local success, result = pcall(hook_info.func, ...)
      if not success then
        handle_feature_error(hook_info.feature_name, hook_name, result)
      elseif result ~= nil and last_return_value ~= result then
        -- Only track non-nil return values. This actually matters for autopickup
        if hook_name == HOOK_FUNCTIONS.autopickup then
          -- Unique case. One false will block autopickup.
          if result == false or last_return_value == nil then
            last_return_value = result
            returning_feature = hook_info.feature_name
          end
        else
          if last_return_value ~= nil then
            BRC.mpr.warning(
              string.format(
                "Return value mismatch in %s:\n  (first) %s -> %s\n  (final) %s -> %s",
                hook_name,
                returning_feature,
                BRC.txt.tostr(last_return_value, true),
                hook_info.feature_name,
                BRC.txt.tostr(result, true)
              )
            )
          end
          last_return_value = result
          returning_feature = hook_info.feature_name
        end
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
  BRC.mpr.error("Failed to handle BRC core error!", result, true)
  if BRC.mpr.yesno("Dump char and deactivate BRC?", BRC.COL.yellow) then
    BRC.active = false
    BRC.mpr.brown("BRC deactivated.", "Error in hook: " .. tostring(hook_name))
    pcall(char_dump, true)
  else
    BRC.mpr.okay()
  end
end

-- Register all features in the global namespace
local function register_all_features()
  -- Find all feature modules
  local feature_names = {}
  for name, value in pairs(_G) do
    if BRC.is_feature_module(value) then feature_names[#feature_names + 1] = name end
  end

  -- Sort alphabetically (for reproducable behavior)
  util.sort(feature_names)

  -- Register features
  local loaded_count = 0
  for _, name in ipairs(feature_names) do
    local success = BRC.register(_G[name])
    if success then
      loaded_count = loaded_count + 1
    elseif success == false then
      BRC.mpr.error("Failed to register feature: " .. name .. ". Aborting bulk registration.")
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
    BRC.mpr.error("Tried to register a non-feature module! Module contents:\n" .. BRC.txt.tostr(f))
    return false
  elseif _features[f.BRC_FEATURE_NAME] then
    BRC.mpr.warning(BRC.txt.lightcyan(f.BRC_FEATURE_NAME) .. " already registered! Repeating...")
    BRC.unregister(f.BRC_FEATURE_NAME)
  end

  if feature_is_disabled(f) then
    BRC.mpr.debug(BRC.txt.lightcyan(f.BRC_FEATURE_NAME) .. " is disabled. Skipped registration.")
    return nil
  else
    if not BRC.Config[f.BRC_FEATURE_NAME] then BRC.Config[f.BRC_FEATURE_NAME] = {} end
    if not f.Config then f.Config = {} end
  end

  BRC.mpr.debug(string.format("Registering %s...", BRC.txt.lightcyan(f.BRC_FEATURE_NAME)))
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

  BRC.process_feature_config(f)

  return true
end

function BRC.unregister(name)
  if not _features[name] then
    BRC.mpr.error(BRC.txt.yellow(name) .. " is not registered. Cannot unregister.")
    return false
  end

  _features[name] = nil
  local removed = {}
  for hook_name, hooks in pairs(_hooks) do
    for i = #hooks, 1, -1 do
      if hooks[i].feature_name == name then
        table.remove(hooks, i)
        removed[#removed + 1] = hook_name
      end
    end
  end

  BRC.mpr.info(string.format("Unregistered %s.", name))
  BRC.mpr.debug(string.format("Unregistered %s hooks: (%s)", name, table.concat(removed, ", ")))
  return true
end

-- @param config table of config values, or string name of a config
function BRC.reset(config)
  BRC.active = false
  BRC.Data.reset()
  BRC.init(config)
end

-- @param config table of config values, or string name of a config
function BRC.init(config)
  BRC.active = false
  _features = {}
  _hooks = {}

  if not BRC.util.version_is_valid(BRC.MIN_CRAWL_VERSION) then
    BRC.mpr.error(string.format(
      "BRC v%s requires crawl v%s or higher. You are running %s.",
      BRC.VERSION,
      BRC.txt.yellow(BRC.MIN_CRAWL_VERSION),
      BRC.txt.yellow(crawl.version("major"))
    ))
    if not BRC.mpr.yesno("Continue loading BRC anyway?", BRC.COL.yellow) then
      BRC.mpr.brown("BRC deactivated.")
      return false
    end
  end

  BRC.init_config(config)
  BRC.mpr.debug("Config loaded.")

  BRC.mpr.debug("Register core features...")
  BRC.register(BRC.Data)
  BRC.register(BRC.Hotkey)

  BRC.mpr.debug("Register features...")
  register_all_features()

  BRC.mpr.debug("Initialize features...")
  safe_call_all_hooks(HOOK_FUNCTIONS.init)
  local suffix = BRC.txt.blue(string.format(" (%s features)", #util.keys(_features)))

  BRC.mpr.debug("Add non-feature hooks...")
  add_autopickup_func(BRC.autopickup)
  BRC.opt.macro(BRC.util.get_cmd_key("CMD_CHARACTER_DUMP") or "#", "macro_brc_dump_character")

  BRC.mpr.debug("Verify persistent data reload...")
  local success = BRC.Data.handle_persist_errors()
  if success then
    BRC.Data.backup() -- Only backup after a clean startup
    local msg = string.format("Successfully initialized BRC v%s!%s", BRC.VERSION, suffix)
    BRC.mpr.lightgreen("\n" .. BRC.txt.wrap(msg, BRC.EMOJI.SUCCESS) .. "\n")
  else
    -- success == nil if errors were resolved, false if tried restore but failed
    if success == false and BRC.mpr.yesno("Deactivate BRC?" .. suffix, BRC.COL.yellow) then
      BRC.active = false
      BRC.mpr.lightred("\nBRC is off.\n")
      return false
    end
    BRC.mpr.magenta(string.format("\nInitialized BRC v%s with warnings!%s\n", BRC.VERSION, suffix))
  end

  -- Avoid weird effects from autopickup before first turn
  BRC.active = you.turns() > 0
  return true
end

--- Pull debug info. Print to mpr() and return as string
-- @param skip_mpr (optional bool) Used in char_dump to just return the string
function BRC.dump(verbose, skip_mpr)
  local tokens = {}
  tokens[#tokens + 1] = BRC.Data.serialize()
  if verbose then
    tokens[#tokens + 1] = BRC.txt.serialize_chk_lua_save()
    tokens[#tokens + 1] = BRC.txt.serialize_inventory()
    util.append(tokens, BRC.serialize_config())
  end

  if not skip_mpr then
    for _, token in ipairs(tokens) do
      BRC.mpr.white(token)
    end
  end

  return table.concat(tokens, "\n")
end

---- Macros ----
function macro_brc_dump_character()
  if not BRC.active then BRC.util.do_cmd("CMD_CHARACTER_DUMP") end
  char_dump(BRC.mpr.yesno("Add BRC debug info to character dump?", BRC.COL.lightcyan))
end

---- Crawl hooks ----
function BRC.autopickup(it, _)
  return safe_call_all_hooks(HOOK_FUNCTIONS.autopickup, it)
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

function BRC.c_message(text, channel)
  if not BRC.active then return end
  safe_call_all_hooks(HOOK_FUNCTIONS.c_message, text, channel)
end

function BRC.ch_start_running(kind)
  if not BRC.active then return end
  safe_call_all_hooks(HOOK_FUNCTIONS.ch_start_running, kind)
end

function BRC.ready()
  if you.turns() == 0 then BRC.active = true end
  if not BRC.active then return end
  BRC.opt.clear_single_turn_mutes()

  if you.turns() > turn_count then
    turn_count = you.turns()
    safe_call_all_hooks(HOOK_FUNCTIONS.ready)
  end

  -- Always display messages, even if same turn
  BRC.mpr.consume_queue()
end
