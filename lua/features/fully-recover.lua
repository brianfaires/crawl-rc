----- Fully rest off negative statuses -----
local recovery_start_turn
local explore_after_recovery
local MAX_TURNS_TO_WAIT = 500

local function abort_fully_recover()
  recovery_start_turn = 0
  crawl.setopt("message_colour -= mute:You start waiting.")
  explore_after_recovery = false
  you.stop_activity()
end

local function finish_fully_recover()
  local turns = you.turns() - recovery_start_turn
  crawl.mpr(with_color(COLORS.lightgreen, "Fully recovered") .. string.format(" (%d turns)", turns))
  
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

  local status = you.status()
  for _,s in ipairs(CONFIG.rest_off_statuses) do
    if status:find(s) then
      if not should_ignore_status(s) then return false end
    end
  end

  return true
end

local function remove_statuses_from_config()
  local status = you.status()
  local to_remove = {}
  for _,s in ipairs(CONFIG.rest_off_statuses) do
    if status:find(s) then
      table.insert(to_remove, s)
    end
  end
  for _,s in ipairs(to_remove) do
    util.remove(CONFIG.rest_off_statuses, s)
    crawl.mpr("  Removed: " ..s)
  end
end

function should_ignore_status(s)
  if s == "corroded" then
    return next_to_slimy_wall() or you.branch() == "Dis"
  elseif s == "slowed" then
    return have_zero_stat()
  end
  return false
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
  crawl.setopt("macros += M " .. KEYS.explore .. " ===macro_explore_fully_recover")
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

function ready_fully_recover()
  if recovery_start_turn > 0 then
    if fully_recovered() then finish_fully_recover()
    elseif not you.feel_safe() then abort_fully_recover()
    elseif you.turns() - recovery_start_turn > MAX_TURNS_TO_WAIT then
      crawl.mpr(with_color(COLORS.lightred, "Fully recover timed out after " .. MAX_TURNS_TO_WAIT .. " turns."))
      crawl.mpr(with_color(COLORS.lightred, "Adjusting CONFIG.rest_off_statuses:"))
      remove_statuses_from_config()
      abort_fully_recover()
    else crawl.do_commands({"CMD_SAFE_WAIT"})
    end
  else
    explore_after_recovery = false
  end
end
