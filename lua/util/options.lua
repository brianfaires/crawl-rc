---------------------------------------------------------------------------------------------------
-- BRC utility module
-- @module BRC.opt
-- Functions for setting crawl options and macros.
---------------------------------------------------------------------------------------------------

BRC.opt = {}

---- Single turn mutes: Mute a message for the current turn only ----
local _single_turn_mutes = {}

function BRC.opt.single_turn_mute(pattern)
  BRC.opt.message_mute(pattern, true)
  _single_turn_mutes[#_single_turn_mutes + 1] = pattern
end

function BRC.clear_single_turn_mutes()
  util.foreach(_single_turn_mutes, function(m) BRC.opt.message_mute(m, false) end)
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

-- Bind a macro to a key. Function must be global and not a member of a module.
function BRC.opt.macro(key, function_name)
  if type(_G[function_name]) ~= "function" then
    BRC.mpr.error("Function %s is not a global function", function_name)
    return
  end
  BRC.mpr.debug(
    string.format(
      "Assigning macro: %s to key: %s",
      BRC.txt.magenta(function_name .. "()"),
      BRC.txt.lightred("<<< '" .. key .. "' >>")
    )
  )
  crawl.setopt(string.format("macros += M %s ===%s", key, function_name))
end

function BRC.opt.message_mute(pattern, create)
  local op = create and "^=" or "-="
  crawl.setopt(string.format("message_colour %s mute:%s", op, pattern))
end

function BRC.opt.runrest_ignore_message(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("runrest_ignore_message %s %s", op, pattern))
end

function BRC.opt.runrest_stop_message(pattern, create)
  local op = create and "+=" or "-="
  crawl.setopt(string.format("runrest_stop_message %s %s", op, pattern))
end
