----- Fully rest off negative statuses -----
loadfile("crawl-rc/lua/cache.lua")
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/util.lua")

local status_to_wait_off = { "berserk", "short of breath", "corroded", "vulnerable",
    "confused", "marked", "tree%-form", "sluggish" } -- "slowed" is a special case below

local recovery_start_turn = 0
local explore_after_recovery = false

crawl.setopt("runrest_ignore_message += recovery:.*")
crawl.setopt("runrest_ignore_message += duration:.*")

local function fully_recovered()
  if CACHE.hp ~= CACHE.mhp then return false end
  if CACHE.mp ~= CACHE.mmp then return false end

  -- Statuses that will always rest off
  local status = you.status()

  for _,s in ipairs(status_to_wait_off) do
    if status:find(s) then return false end
  end

  -- If stat drain, don't wait for slow
  if status:find("slowed") then
    return CACHE.str <= 0 or CACHE.dex <= 0 or CACHE.int <= 0
  end

  return true
end

local function start_full_recovery()
  recovery_start_turn = CACHE.turn
  crawl.setopt("message_colour += mute:You start waiting.")
end

local function abort_full_recovery()
  recovery_start_turn = 0
  crawl.setopt("message_colour -= mute:You start waiting.")
  explore_after_recovery = false
  you.stop_activity()
end

local function finish_full_recovery()
  local turns = CACHE.turn - recovery_start_turn
  local msg = with_color(COLORS.lightgreen, "Fully recovered") .. string.format(" (%d turns)", turns)
  enqueue_mpr(msg)
  
  recovery_start_turn = 0
  crawl.setopt("message_colour -= mute:You start waiting.")
  you.stop_activity()

  if explore_after_recovery then
    explore_after_recovery = false
    crawl.sendkeys("o")
  end
end

-- Attach full recovery to auto-explore
function macro_explore_full_recovery()
  if fully_recovered() then
    crawl.do_commands({"CMD_EXPLORE"})
  else
    explore_after_recovery = true
    crawl.do_commands({"CMD_REST"})
  end
end
crawl.setopt("macros += M o ===macro_explore_full_recovery")


function ch_stop_running_full_recovery(kind)
  if kind == "run" and not fully_recovered() then start_full_recovery() end
end

function c_message_fully_recover(text, channel)
  if channel == "plain" then
    if text:find("You start waiting.") or text:find("You start resting.") then
      if not fully_recovered() then start_full_recovery() end
    end
  elseif recovery_start_turn > 0 then
    if channel == "timed_portal" then abort_full_recovery()
    elseif fully_recovered() then finish_full_recovery()
    end
  end
end

function ready_fully_recover()
  if recovery_start_turn > 0 then
    if fully_recovered() then finish_full_recovery()
    elseif not you.feel_safe() then abort_full_recovery()
    else crawl.do_commands({"CMD_SAFE_WAIT"})
    end
  else
    explore_after_recovery = false
  end
end
