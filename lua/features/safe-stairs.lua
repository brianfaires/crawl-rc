--[[
Feature: safe-stairs
Description: Prevents accidental stairs use by warning about backtracking and dangerous locations like Vaults:5
Author: buehler, rypofalem (V5 warning idea)
Dependencies: core/config.lua, core/data.lua, core/constants.lua, core/util.lua
--]]

f_safe_stairs = {}
f_safe_stairs.BRC_FEATURE_NAME = "safe-stairs"

-- Persistent variables
ss_prev_location = BRC.data.persist("ss_prev_location", "")
ss_cur_location = BRC.data.persist("ss_cur_location", "")
ss_last_stair_turn = BRC.data.persist("ss_last_stair_turn", 0)
ss_v5_unwarned = BRC.data.persist("ss_v5_unwarned", true)

-- Local functions
local function check_new_location(cmd)
  local feature = view.feature_at(0, 0)
  local one_way_stair = feature:find("escape_hatch", 1, true) or feature:find("shaft", 1, true)

  local turn_diff = you.turns() - ss_last_stair_turn
  if ss_prev_location ~= ss_cur_location and turn_diff > 0 and turn_diff < BRC.Config.warn_stairs_threshold then
    if cmd == "CMD_GO_DOWNSTAIRS" then
      if not (feature:find("down", 1, true) or feature:find("shaft", 1, true)) then
        BRC.util.do_cmd(cmd)
        return
      end
    else
      if not feature:find("up", 1, true) then
        BRC.util.do_cmd(cmd)
        return
      end
    end

    if not BRC.mpr.yesno("Really go right back?") then
      crawl.mpr("Okay, then.")
      return
    end
  elseif BRC.Config.warn_v5 and ss_v5_unwarned and ss_cur_location == "Vaults4" and cmd == "CMD_GO_DOWNSTAIRS" then
    if feature:find("down", 1, true) or feature:find("shaft", 1, true) then
      if not BRC.mpr.yesno("Really go to Vaults:5?") then
        crawl.mpr("Okay, then.")
        return
      end
      ss_v5_unwarned = false
    end
  end

  BRC.util.do_cmd(cmd)
  if not one_way_stair then ss_last_stair_turn = you.turns() end
end

-- Macro functions
function macro_f_safe_stairs_down()
  check_new_location("CMD_GO_DOWNSTAIRS")
end

function macro_f_safe_stairs_up()
  check_new_location("CMD_GO_UPSTAIRS")
end

-- Hook functions
function f_safe_stairs.init()
  ss_prev_location = you.branch() .. you.depth()
  ss_cur_location = you.branch() .. you.depth()
  ss_last_stair_turn = 0
  ss_v5_unwarned = true

  BRC.set.macro(BRC.get.command_key("CMD_GO_DOWNSTAIRS") or ">", "macro_f_safe_stairs_down")
  BRC.set.macro(BRC.get.command_key("CMD_GO_UPSTAIRS") or "<", "macro_f_safe_stairs_up")
end

function f_safe_stairs.ready()
  ss_prev_location = ss_cur_location
  ss_cur_location = you.branch() .. you.depth()
end
