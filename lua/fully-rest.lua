----- Fully rest off effects -----
local status_to_wait_off = { "berserk", "short of breath", "corroded", "vulnerable",
    "confused", "marked", "tree%-form", "sluggish" }

local waiting_for_recovery = false
local explore_after_recovery = false

crawl.setopt("runrest_ignore_message += recovery:.*")
crawl.setopt("runrest_ignore_message += duration:.*")

local function fully_recovered()
  -- Confirm sure HP and MP are full
  local hp, mhp = you.hp()
  if hp ~= mhp then return false end
  local mp, mmp = you.mp()
  if mp ~= mmp then return false end

  -- Statuses that will always rest off
  local status = you.status()

  for _,s in ipairs(status_to_wait_off) do
    if status:find(s) then return false end
  end

  -- If stat drain, don't wait for slow
  if status:find("slowed") then
    return l_cache.str <= 0 or l_cache.dex <= 0 or l_cache.int <= 0
  end

  return true
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
  if kind == "run" and not fully_recovered() then
    waiting_for_recovery = true
    crawl.setopt("message_colour += mute:You start waiting.")
  end
end

function c_message_fully_recover(text, _)
  if text:find("You start waiting.") or text:find("You start resting.") then
    if not fully_recovered() then
      waiting_for_recovery = true
      crawl.setopt("message_colour += mute:You start waiting.")
    end
  elseif waiting_for_recovery and channel == "timed_portal" then
    you.stop_activity()
    waiting_for_recovery = false
    crawl.setopt("message_colour -= mute:You start waiting.")
    explore_after_recovery = false
  end
end

function ready_fully_recover()
  if waiting_for_recovery then
    if fully_recovered() then
      you.stop_activity()
      crawl.setopt("message_colour -= mute:You start waiting.")
      waiting_for_recovery = false
      crawl.mpr("Fully recovered.")

      if explore_after_recovery then
        crawl.sendkeys("o")
        explore_after_recovery = false
      end
    elseif not you.feel_safe() then
      you.stop_activity()
      waiting_for_recovery = false
      explore_after_recovery = false
    else
      crawl.do_commands({"CMD_SAFE_WAIT"})
    end
  else
    explore_after_recovery = false
  end
end
