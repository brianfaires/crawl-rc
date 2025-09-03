--[[
Feature: safe-stairs
Description: Prevents accidental stairs use by warning about backtracking and dangerous locations like Vaults:5
Author: buehler, rypofalem
Dependencies: CONFIG, KEYS, view.feature_at, mpr_yesno
--]]

f_safe_stairs = {}
f_safe_stairs.BRC_FEATURE_NAME = "safe-stairs"

-- Local state
local prev_location
local cur_location
local last_stair_turn
local v5_unwarned

-- Local functions
local function check_new_location(key)
  local feature = view.feature_at(0, 0)
  local one_way_stair = feature:find("escape_hatch", 1, true) or feature:find("shaft", 1, true)

  local turn_diff = you.turns() - last_stair_turn
  if prev_location ~= cur_location and turn_diff > 0 and turn_diff < CONFIG.warn_stairs_threshold then
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
    if not mpr_yesno("Really go right back?") then
      crawl.mpr("Okay, then.")
      return
    end
  elseif CONFIG.warn_v5 and v5_unwarned and cur_location == "Vaults4" and key == ">" then
    -- V5 warning idea by rypofalem --
    if feature:find("down", 1, true) or feature:find("shaft", 1, true) then
      if not mpr_yesno("Really go to Vaults:5?") then
        crawl.mpr("Okay, then.")
        return
      end
      v5_unwarned = false
    end
  end

  crawl.sendkeys(key)
  if not one_way_stair then last_stair_turn = you.turns() end
end

function macro_do_safe_downstairs() check_new_location(">") end

function macro_do_safe_upstairs() check_new_location("<") end

-- Hook functions
function f_safe_stairs.init()
  prev_location = you.branch() .. you.depth()
  cur_location = you.branch() .. you.depth()
  last_stair_turn = 0
  v5_unwarned = true

  crawl.setopt("macros += M " .. KEYS.go_downstairs .. " ===macro_do_safe_downstairs")
  crawl.setopt("macros += M " .. KEYS.go_upstairs .. " ===macro_do_safe_upstairs")
end

function f_safe_stairs.ready()
  prev_location = cur_location
  cur_location = you.branch() .. you.depth()
end
