---------------------------------------------------------------------------------------------------
-- BRC utility module
-- @module BRC.mpr
-- Wrappers around crawl.mpr for message printing : Colors, formatted messages, message queue, etc.
---------------------------------------------------------------------------------------------------

BRC.mpr = {}
BRC.mpr.brc_prefix = BRC.txt.darkgrey("[BRC] ")

---- mpr queue (displayed after all other messages for the turn) ----
local _mpr_queue = {}

--- Queue a message to dispay at the end of ready()
function BRC.mpr.que(msg, color, channel)
  BRC.mpr.que_optmore(false, msg, color, channel)
end

--- Queue msg w/ conditional force_more_message
-- send with empty msg for a delayed force_more_message
function BRC.mpr.que_optmore(show_more, msg, msg_color, channel)
  for _, q in ipairs(_mpr_queue) do
    if q.m == msg and q.ch == channel and q.more == show_more then return end
  end
  msg_color = msg_color or BRC.COL.lightgrey
  if not msg or #msg == 0 then
    msg = ""
  else
    msg = BRC.txt[msg_color](msg)
  end
  _mpr_queue[#_mpr_queue + 1] = { m = msg, ch = channel, more = show_more }
end

--- Display queued messages and clear the queue
function BRC.mpr.consume_queue()
  local do_more = util.exists(_mpr_queue, function(q) return q.more end)
  -- stop_activity() can generate more autopickups, and thus more queue'd messages
  if do_more then
    you.stop_activity()
  end

  for _, msg in ipairs(_mpr_queue) do
    if msg.m and #msg.m > 0 then
      crawl.mpr(tostring(msg.m), msg.ch)
      crawl.flush_prev_message()
    end
  end
  _mpr_queue = {}

  if do_more then
    crawl.redraw_screen()
    crawl.more()
  end
end


---- Color functions - Usage: BRC.mpr.white("Hello"), or BRC.mpr["15"]("Hello") ----
for k, color in pairs(BRC.COL) do
  BRC.mpr[k] = function(msg, channel)
    crawl.mpr(BRC.txt[color](msg), channel)
    crawl.flush_prev_message()
  end
  BRC.mpr[color] = BRC.mpr[k]
end


---- Pre-formatted logging functions ----
local function log_message(message, context, msg_color)
  -- Avoid referencing BRC, to stay robust during startup
  msg_color = msg_color or "lightgrey"
  local msg = BRC.mpr.brc_prefix .. tostring(message)
  if context then msg = string.format("%s (%s)", msg, tostring(context)) end
  crawl.mpr(string.format("<%s>%s</%s>", msg_color, msg, msg_color))
  crawl.flush_prev_message()
end

--- Primary function for displaying errors. Includes a force_more_message by default.
-- @param context (optional) Additional context. No context if params are (string, bool).
function BRC.mpr.error(message, context, skip_more)
  if type(context) == "boolean" and skip_more == nil then
    skip_more = context
    context = nil
  end

  log_message("(Error) " .. message, context, BRC.COL.lightred)
  you.stop_activity()

  if not skip_more then
    crawl.redraw_screen()
    crawl.more()
  end

  if BRC.Config.mpr.logs_to_stderr then
    crawl.stderr(BRC.mpr.brc_prefix .. "(Error) " .. message)
  end
end

function BRC.mpr.warning(message, context)
  log_message(message, context, BRC.COL.yellow)
  you.stop_activity()
  if BRC.Config.mpr.logs_to_stderr then
    crawl.stderr(BRC.mpr.brc_prefix .. "(Warning) " .. message)
  end
end

function BRC.mpr.info(message, context)
  log_message(message, context, BRC.COL.darkgrey)
end

function BRC.mpr.debug(message, context)
  if BRC.Config.mpr.show_debug_messages then
    log_message(message, context, BRC.COL.lightblue)
  end
  if BRC.Config.mpr.logs_to_stderr then
    crawl.stderr(BRC.mpr.brc_prefix .. "(Debug) " .. message)
  end
end

function BRC.mpr.okay(suffix)
  BRC.mpr.darkgrey("Okay, then." .. (suffix and " " .. suffix or ""))
end

--- Print a variable's stringified value
function BRC.mpr.tostr(v)
  crawl.mpr(BRC.txt.tostr(v, true))
end

---- Messages with stop or force_more ----
--- Message plus stop travel/activity
function BRC.mpr.stop(msg, color, channel)
  BRC.mpr[color or BRC.COL.lightgrey](msg, channel)
  you.stop_activity()
end

--- Message as a force_more_message
function BRC.mpr.more(msg, color, channel)
  BRC.mpr[color or BRC.COL.lightgrey](msg, channel)
  you.stop_activity()
  crawl.redraw_screen()
  crawl.more()
end

--- Conditional force_more_message
function BRC.mpr.optmore(show_more, msg, color, channel)
  if show_more then
    BRC.mpr.more(msg, color, channel)
  else
    BRC.mpr[color or BRC.COL.lightgrey](msg, channel)
  end
end


---- Prompts for user input ----
--- Get a selection from the user, from a list of options
function BRC.mpr.select(msg, options, color)
  if not (type(options) == "table" and #options > 0) then
    BRC.mpr.error("No options provided for BRC.mpr.select")
    return false
  end

  msg = msg .. ":\n"
  for i, option in ipairs(options) do
    msg = msg .. string.format("%s: %s\n", i, BRC.txt.white(option))
  end
  BRC.mpr[color or BRC.COL.lightcyan](msg, "prompt")
  for _ = 1, 10 do
    local res = crawl.getch()
    if res then
      local num = res - string.byte("0")
      if num > 0 and num <= #options then return options[num] end
    end
    BRC.mpr.magenta("Invalid option, try again.")
  end

  BRC.mpr.lightmagenta("Fine then. Using option 1: " .. options[1])
  return options[1]
end

--- Get a yes/no response
function BRC.mpr.yesno(msg, color, capital_only)
  msg = string.format("%s (%s)", msg, capital_only and "Y/N" or "y/n")

  for i = 1, 10 do
    BRC.mpr[color or BRC.COL.lightgrey](msg, "prompt")
    local res = crawl.getch()
    if res and res >= 0 and res <= 255 then
      local c = string.char(res)
      if c == "Y" or c == "y" and not capital_only then return true end
      if c == "N" or c == "n" and not capital_only then return false end
    end
    if i == 1 and capital_only then msg = "[CAPS ONLY] " .. msg end
  end

  BRC.mpr.lightmagenta("Feels like a no.")
  return false
end

