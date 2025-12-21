---------------------------------------------------------------------------------------------------
-- BRC utility module
-- @module BRC.opt
-- Functions for setting crawl options and macros.
---------------------------------------------------------------------------------------------------

BRC.opt = {}

---- Single turn mutes: Mute a message for the current turn only ----
local _single_turn_mutes = {}
local _claimed_macro_keys = {}

function BRC.opt.single_turn_mute(pattern)
  BRC.opt.message_mute(pattern, true)
  _single_turn_mutes[#_single_turn_mutes + 1] = pattern
end

function BRC.opt.clear_single_turn_mutes()
  util.foreach(_single_turn_mutes, function(m) BRC.opt.message_mute(m, false) end)
  _single_turn_mutes = {}
end

---- crawl.setopt() wrappers ----
function BRC.opt.autopickup_exceptions(pattern, create)
  local op = create and "^=" or "-="
  crawl.setopt(string.format("autopickup_exceptions %s %s", op, pattern))
end

function BRC.opt.explore_stop(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("explore_stop %s %s", op, pattern))
end

function BRC.opt.explore_stop_pickup_ignore(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("explore_stop_pickup_ignore %s %s", op, pattern))
end

function BRC.opt.flash_screen_message(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("flash_screen_message %s %s", op, pattern))
end

function BRC.opt.force_more_message(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("force_more_message %s %s", op, pattern))
end

--- Bind a macro to a key. Function must be global and not a member of a module.
-- If key is a number, it is converted to a keycode string.
-- Passing an invalid function name will clear the macro for that key.
function BRC.opt.macro(key, function_name, overwrite_existing)
  -- Format msg for debugging and keycode for crawl.setopt()
  local key_str = nil
  if type(key) == "number" then
    -- Try to convert to key name for better debug msg
    for k, v in pairs(BRC.KEYS) do
      if v == key then
        key_str = "<<< " .. k .. " >>"
        break
      end
    end
    -- Format keycode string for crawl.setopt()
    key = "\\{" .. key .. "}"
    if key_str == nil then key_str = "<<< \\" .. key .. " >>" end
  end

  -- The << >> formatting protects against crawl thinking '<' is a tag
  if key_str == nil then key_str = "<<< '" .. key .. "' >>" end

  if type(_G[function_name]) == "function" then
    if _claimed_macro_keys[key] and not overwrite_existing then
      BRC.mpr.debug("Macro key %s is already assigned to %s", key_str, _claimed_macro_keys[key])
      return
    end
    crawl.setopt(string.format("macros += M %s ===%s", key, function_name))
    _claimed_macro_keys[key] = function_name
    BRC.mpr.debug(
      string.format(
        "Assigned macro %s to key: %s",
        BRC.txt.magenta(function_name .. "()"),
        BRC.txt.lightred(key_str)
      )
    )
  else
    function_name = _claimed_macro_keys[key]
    if not function_name then
      crawl.mpr("no function name found for key: " .. key)
      return
    end
    crawl.setopt(string.format("macros += M %s %s", key, key))
    _claimed_macro_keys[key] = nil
    BRC.mpr.debug(
      string.format(
        "Cleared macro %s from key: %s",
        BRC.txt.magenta(function_name .. "()"),
        BRC.txt.lightred(key_str)
      )
    )
  end
end

function BRC.opt.clear_macros()
  for key, function_name in pairs(_claimed_macro_keys) do
    BRC.opt.macro(key, nil, true)
  end
  _claimed_macro_keys = {}
end

function BRC.opt.message_mute(pattern, create)
  local op = create and "^=" or "-="
  crawl.setopt(string.format("message_colour %s mute:%s", op, pattern))
end

function BRC.opt.runrest_ignore_message(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("runrest_ignore_message %s %s", op, pattern))
end

function BRC.opt.runrest_ignore_monster(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("runrest_ignore_monster %s %s", op, pattern))
end

function BRC.opt.runrest_stop_message(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("runrest_stop_message %s %s", op, pattern))
end
