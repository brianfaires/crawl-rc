--[[
Feature: fully-recover
Description: Automatically rests until fully recovered from negative statuses, with smart recovery logic
Author: buehler
Dependencies: core/config.lua, core/data.lua, core/util.lua
--]]

f_fully_recover = {}
f_fully_recover.BRC_FEATURE_NAME = "fully-recover"

-- Persistent variables
fr_start_turn = BRC.data.persist("fr_start_turn", 0)
fr_explore_after = BRC.data.persist("fr_explore_after", false)

-- Local constants / configuration
local MAX_TURNS_TO_WAIT = 500
local WAITING_MESSAGE = "You start waiting."

-- Local functions
local function abort_fully_recover()
  fr_start_turn = 0
  fr_explore_after = false
  BRC.set.message_mute(WAITING_MESSAGE, false)
  you.stop_activity()
end

local function finish_fully_recover()
  local turns = you.turns() - fr_start_turn
  BRC.mpr.color(string.format("Fully recovered (%d turns)", turns), BRC.COLORS.lightgreen)

  fr_start_turn = 0
  BRC.set.message_mute(WAITING_MESSAGE, false)
  you.stop_activity()

  if fr_explore_after then
    fr_explore_after = false
    crawl.do_commands({ "CMD_EXPLORE" })
  end
end

local function should_ignore_status(s)
  if s == "corroded" then
    return BRC.you.by_slimy_wall() or you.branch() == "Dis"
  elseif s == "slowed" then
    return BRC.you.zero_stat()
  end
  return false
end

local function fully_recovered()
  local hp, mhp = you.hp()
  local mp, mmp = you.mp()
  if hp ~= mhp then return false end
  if mp ~= mmp then return false end

  local status = you.status()
  for _, s in ipairs(BRC.Config.rest_off_statuses) do
    if status:find(s) then
      if not should_ignore_status(s) then return false end
    end
  end

  return true
end

local function remove_statuses_from_config()
  local status = you.status()
  local to_remove = {}
  for _, s in ipairs(BRC.Config.rest_off_statuses) do
    if status:find(s) then table.insert(to_remove, s) end
  end
  for _, s in ipairs(to_remove) do
    util.remove(BRC.Config.rest_off_statuses, s)
    crawl.error(string.format("  Removed: %s", s))
  end
end

local function start_fully_recover()
  fr_start_turn = you.turns()
  BRC.set.message_mute(WAITING_MESSAGE, true)
end

-- Macro function: Attach full recovery to auto-explore
function macro_f_fully_recover_explore()
  if fully_recovered() then
    if fr_start_turn > 0 then
      finish_fully_recover()
    else
      crawl.do_commands({ "CMD_EXPLORE" })
    end
  else
    fr_explore_after = true
    crawl.do_commands({ "CMD_REST" })
  end
end

-- Hook functions
function f_fully_recover.init()
  fr_start_turn = 0
  fr_explore_after = false
  util.remove(BRC.Config.rest_off_statuses, "slowed") -- special case handled elsewhere

  BRC.set.runrest_ignore_message("recovery:.*", true)
  BRC.set.runrest_ignore_message("duration:.*", true)
  BRC.set.macro(BRC.get.command_key("CMD_EXPLORE", "o"), "macro_f_fully_recover_explore")
end

function f_fully_recover.c_message(text, channel)
  if channel == "plain" then
    if text:find(WAITING_MESSAGE, 1, true) or text:find("ou start resting", 1, true) then
      if not fully_recovered() then start_fully_recover() end
    end
  elseif fr_start_turn > 0 then
    if channel == "timed_portal" then
      abort_fully_recover()
    elseif fully_recovered() then
      finish_fully_recover()
    end
  end
end

function f_fully_recover.ready()
  if fr_start_turn > 0 then
    if fully_recovered() then
      finish_fully_recover()
    elseif not you.feel_safe() then
      abort_fully_recover()
    elseif you.turns() - fr_start_turn > MAX_TURNS_TO_WAIT then
      BRC.log.error(string.format("fully-recover timed out after %s turns.", MAX_TURNS_TO_WAIT))
      BRC.log.error("Adjusting BRC.Config.rest_off_statuses:")
      remove_statuses_from_config()
      abort_fully_recover()
    else
      crawl.do_commands({ "CMD_SAFE_WAIT" })
    end
  else
    fr_explore_after = false
  end
end
