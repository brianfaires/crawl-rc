--[[
Feature: safe-stairs
Description: Prevents accidental stairs use by warning about backtracking and dangerous locations like Vaults:5
Author: buehler, rypofalem
Dependencies: CONFIG, BRC.KEYS, view.feature_at, BRC.mpr.yesno
--]]

f_safe_stairs = {}
f_safe_stairs.BRC_FEATURE_NAME = "safe-stairs"

-- Persistent variables
ss_prev_location = BRC.data.create("ss_prev_location", "")
ss_cur_location = BRC.data.create("ss_cur_location", "")
ss_last_stair_turn = BRC.data.create("ss_last_stair_turn", 0)
ss_v5_unwarned = BRC.data.create("ss_v5_unwarned", true)

-- Local constants

-- Local functions
local function check_new_location(key)
  local feature = view.feature_at(0, 0)
  local one_way_stair = feature:find("escape_hatch", 1, true) or feature:find("shaft", 1, true)

  local turn_diff = you.turns() - ss_last_stair_turn
  if ss_prev_location ~= ss_cur_location and turn_diff > 0 and turn_diff < BRC.Config.warn_stairs_threshold then
    if key == ">" then
      if not (feature:find("down", 1, true) or feature:find("shaft", 1, true)) then
        crawl.sendkeys(key)
        return
      end
    else
      if not feature:find("up", 1, true) then
        crawl.sendkeys(key)
        return
      end
    end
    if not BRC.mpr.yesno("Really go right back?") then
      crawl.mpr("Okay, then.")
      return
    end
  elseif BRC.Config.warn_v5 and ss_v5_unwarned and ss_cur_location == "Vaults4" and key == ">" then
    -- V5 warning idea by rypofalem --
    if feature:find("down", 1, true) or feature:find("shaft", 1, true) then
      if not BRC.mpr.yesno("Really go to Vaults:5?") then
        crawl.mpr("Okay, then.")
        return
      end
      ss_v5_unwarned = false
    end
  end

  crawl.sendkeys(key)
  if not one_way_stair then ss_last_stair_turn = you.turns() end
end

function f_safe_stairs.macro_downstairs()
  check_new_location(">")
end

function f_safe_stairs.macro_upstairs()
  check_new_location("<")
end

-- Hook functions
function f_safe_stairs.init()
  ss_prev_location = you.branch() .. you.depth()
  ss_cur_location = you.branch() .. you.depth()
  ss_last_stair_turn = 0
  ss_v5_unwarned = true

  crawl.setopt("macros += M " .. BRC.KEYS.go_downstairs .. " ===f_safe_stairs.macro_downstairs")
  crawl.setopt("macros += M " .. BRC.KEYS.go_upstairs .. " ===f_safe_stairs.macro_upstairs")
end

function f_safe_stairs.ready()
  ss_prev_location = ss_cur_location
  ss_cur_location = you.branch() .. you.depth()
end
