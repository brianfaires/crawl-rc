---------------------------------------------------------------------------------------------------
-- BRC feature module: fully-recover
-- @module f_fully_recover
-- Rests until no negative duration statuses. Doesn't stop rest on each status expiration.
-- @todo Can remove when crawl's explore_auto_rest_status setting reaches feature parity.
---------------------------------------------------------------------------------------------------

f_fully_recover = {}
f_fully_recover.BRC_FEATURE_NAME = "fully-recover"

---- Persistent variables ----
fr_bad_durations = BRC.Data.persist("fr_bad_durations", util.copy_table(BRC.BAD_DURATIONS))

---- Local constants ----
local MAX_TURNS_TO_WAIT = 500

---- Local variables ----
local recovery_start_turn
local explore_after_recovery

---- Initialization ----
function f_fully_recover.init()
  recovery_start_turn = 0
  explore_after_recovery = false

  BRC.opt.macro(BRC.util.get_cmd_key("CMD_EXPLORE") or "o", "macro_brc_explore")
  BRC.opt.macro(BRC.util.get_cmd_key("CMD_REST") or "5", "macro_brc_rest")
  BRC.opt.runrest_ignore_message("recovery:.*", true)
  BRC.opt.runrest_ignore_message("duration:.*", true)
  BRC.opt.message_mute("^HP restored", true)
  BRC.opt.message_mute("Magic restored", true)
end

---- Local functions ----
local function abort_fully_recover()
  recovery_start_turn = 0
  explore_after_recovery = false
  you.stop_activity()
end

local function finish_fully_recover()
  local turns = you.turns() - recovery_start_turn
  recovery_start_turn = 0
  if turns > 0 then BRC.mpr.lightgreen(string.format("Fully recovered (%d turns)", turns)) end

  you.stop_activity()

  if explore_after_recovery then
    explore_after_recovery = false
    BRC.util.do_cmd("CMD_EXPLORE")
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
  if you.contamination() > 0 then return false end
  local hp, mhp = you.hp()
  local mp, mmp = you.mp()
  if hp ~= mhp then return false end
  if mp ~= mmp then return false end

  local status = you.status()
  for _, s in ipairs(BRC.BAD_DURATIONS) do
    if status:find(s) and not should_ignore_status(s) then return false end
  end

  return true
end

local function start_fully_recover(cmd)
  if BRC.active == false or f_fully_recover.Config.disabled or not you.feel_safe() then
    return BRC.util.do_cmd(cmd)
  end

  if fully_recovered() then
    if recovery_start_turn > 0 then
      finish_fully_recover()
    else
      recovery_start_turn = you.turns()
      BRC.util.do_cmd(cmd)
    end
  else
    if not you.feel_safe() then
      BRC.mpr.lightred("A monster is nearby!")
    else
      explore_after_recovery = cmd == "CMD_EXPLORE"
      recovery_start_turn = you.turns()
      BRC.util.do_cmd("CMD_REST")
    end
  end
end

local function remove_statuses_from_list()
  local status = you.status()
  local to_remove = {}
  for _, s in ipairs(fr_bad_durations) do
    if status:find(s) then table.insert(to_remove, s) end
  end
  for _, s in ipairs(to_remove) do
    util.remove(fr_bad_durations, s)
    BRC.mpr.error("  Removed: " .. s)
  end
end

---- Macro function: Attach full recovery to auto-explore ----
function macro_brc_explore()
  start_fully_recover("CMD_EXPLORE")
end

---- Macro function: Attach full recovery to auto-rest ----
function macro_brc_rest()
  start_fully_recover("CMD_REST")
end

---- Crawl hook functions ----
function f_fully_recover.c_message(_, channel)
  if not fully_recovered() then return end
  if recovery_start_turn > 0 then
    finish_fully_recover()
  elseif channel ~= "duration" and channel ~= "recovery" then
    abort_fully_recover()
  end
end

function f_fully_recover.ready()
  if recovery_start_turn <= 0 then
    explore_after_recovery = false
    return
  end

  if fully_recovered() then
    finish_fully_recover()
  elseif not you.feel_safe() then
    abort_fully_recover()
  elseif you.turns() - recovery_start_turn > MAX_TURNS_TO_WAIT then
    BRC.mpr.error("fully-recover timed out after " .. MAX_TURNS_TO_WAIT .. " turns.", true)
    BRC.mpr.error("fr_bad_durations:")
    remove_statuses_from_list()
    abort_fully_recover()
  else
    BRC.util.do_cmd("CMD_REST")
  end
end
