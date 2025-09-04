--[[
Feature: fully-recover
Description: Automatically rests until fully recovered from negative statuses, with smart recovery logic
Author: buehler
Dependencies: CONFIG, COLORS, KEYS, BRC.util.color, util.remove, BRC.you.by_slimy_wall, BRC.you.zero_stat
--]]

f_fully_recover = {}
f_fully_recover.BRC_FEATURE_NAME = "fully-recover"

-- Persistent variables
fr_start_turn = BRC.data.create("fr_start_turn", 0)
fr_explore_after = BRC.data.create("fr_explore_after", false)

-- Local constants / configuration
local MAX_TURNS_TO_WAIT = 500

-- Local functions
local function abort_fully_recover()
  fr_start_turn = 0
  fr_explore_after = false
  crawl.setopt("message_colour -= mute:You start waiting.")
  you.stop_activity()
end

local function finish_fully_recover()
  local turns = you.turns() - fr_start_turn
  BRC.mpr.col("Fully recovered" .. string.format(" (%d turns)", turns), COLORS.lightgreen)

  fr_start_turn = 0
  crawl.setopt("message_colour -= mute:You start waiting.")
  you.stop_activity()

  if fr_explore_after then
    fr_explore_after = false
    crawl.sendkeys("o")
  end
end

local function fully_recovered()
  local hp, mhp = you.hp()
  local mp, mmp = you.mp()
  if hp ~= mhp then return false end
  if mp ~= mmp then return false end

  local status = you.status()
  for _, s in ipairs(CONFIG.rest_off_statuses) do
    if status:find(s) then
      if not should_ignore_status(s) then return false end
    end
  end

  return true
end

local function remove_statuses_from_config()
  local status = you.status()
  local to_remove = {}
  for _, s in ipairs(CONFIG.rest_off_statuses) do
    if status:find(s) then table.insert(to_remove, s) end
  end
  for _, s in ipairs(to_remove) do
    util.remove(CONFIG.rest_off_statuses, s)
    crawl.mpr("  Removed: " .. s)
  end
end

function should_ignore_status(s)
  if s == "corroded" then
    return BRC.you.by_slimy_wall() or you.branch() == "Dis"
  elseif s == "slowed" then
    return BRC.you.zero_stat()
  end
  return false
end

local function start_fully_recover()
  fr_start_turn = you.turns()
  crawl.setopt("message_colour += mute:You start waiting.")
end

-- Attach full recovery to auto-explore
function f_fully_recover.macro_explore()
  if fully_recovered() then
    crawl.do_commands({ "CMD_EXPLORE" })
  else
    fr_explore_after = true
    crawl.do_commands({ "CMD_REST" })
  end
end

-- Hook functions
function f_fully_recover.init()
  fr_start_turn = 0
  fr_explore_after = false
  util.remove(CONFIG.rest_off_statuses, "slowed") -- special case handled elsewhere

  crawl.setopt("runrest_ignore_message += recovery:.*")
  crawl.setopt("runrest_ignore_message += duration:.*")
  crawl.setopt("macros += M " .. KEYS.explore .. " ===f_fully_recover.macro_explore")
end

function f_fully_recover.c_message(text, channel)
  if channel == "plain" then
    if text:find("ou start waiting", 1, true) or text:find("ou start resting", 1, true) then
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
      BRC.mpr.col("Fully recover timed out after " .. MAX_TURNS_TO_WAIT .. " turns.", COLORS.lightred)
      BRC.mpr.col("Adjusting CONFIG.rest_off_statuses:", COLORS.lightred)
      remove_statuses_from_config()
      abort_fully_recover()
    else
      crawl.do_commands({ "CMD_SAFE_WAIT" })
    end
  else
    fr_explore_after = false
  end
end
