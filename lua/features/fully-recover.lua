----- Fully rest off negative statuses -----
local recovery_start_turn
local explore_after_recovery

local function abort_fully_recover()
  recovery_start_turn = 0
  crawl.setopt("message_colour -= mute:You start waiting.")
  explore_after_recovery = false
  you.stop_activity()
end

local function finish_fully_recover()
  local turns = you.turns() - recovery_start_turn
  local msg = with_color(COLORS.lightgreen, "Fully recovered") .. string.format(" (%d turns)", turns)
  crawl.mpr(msg)
  
  recovery_start_turn = 0
  crawl.setopt("message_colour -= mute:You start waiting.")
  you.stop_activity()

  if explore_after_recovery then
    explore_after_recovery = false
    crawl.sendkeys("o")
  end
end

local function fully_recovered()
  local hp, mhp = you.hp()
  local mp, mmp = you.mp()
  if hp ~= mhp then return false end
  if mp ~= mmp then return false end

  -- Statuses that will always rest off
  local status = you.status()

  for _,s in ipairs(CONFIG.rest_off_statuses) do
    if status:find(s) then return false end
  end

  -- If stat drain, don't wait for slow
  if status:find("slowed", 1, true) then
    return you.strength() <= 0 or you.dexterity() <= 0 or you.intelligence() <= 0
  end

  return true
end

local function start_fully_recover()
  recovery_start_turn = you.turns()
  crawl.setopt("message_colour += mute:You start waiting.")
end


function init_fully_recover()
  if CONFIG.debug_init then crawl.mpr("Initializing fully-recover") end

  recovery_start_turn = 0
  explore_after_recovery = false
  util.remove(CONFIG.rest_off_statuses, "slowed") -- special case handled elsewhere
  
  crawl.setopt("runrest_ignore_message += recovery:.*")
  crawl.setopt("runrest_ignore_message += duration:.*")
  crawl.setopt("macros += M o ===macro_explore_fully_recover")
end

-- Attach full recovery to auto-explore
function macro_explore_fully_recover()
  if fully_recovered() then
    crawl.do_commands({"CMD_EXPLORE"})
  else
    explore_after_recovery = true
    crawl.do_commands({"CMD_REST"})
  end
end


------------------- Hooks -------------------
function c_message_fully_recover(text, channel)
  if channel == "plain" then
    if text:find("ou start waiting", 1, true) or text:find("ou start resting", 1, true) then
      if not fully_recovered() then start_fully_recover() end
    end
  elseif recovery_start_turn > 0 then
    if channel == "timed_portal" then abort_fully_recover()
    elseif fully_recovered() then finish_fully_recover()
    end
  end
end

function ch_stop_running_fully_recover(kind)
  if kind == "run" and not fully_recovered() then start_fully_recover() end
end

function ready_fully_recover()
  if recovery_start_turn > 0 then
    if fully_recovered() then finish_fully_recover()
    elseif not you.feel_safe() then abort_fully_recover()
    else crawl.do_commands({"CMD_SAFE_WAIT"})
    end
  else
    explore_after_recovery = false
  end
end
