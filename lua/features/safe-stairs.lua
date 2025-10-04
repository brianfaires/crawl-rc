--[[
Feature: safe-stairs
Description: Prevents accidental stairs use by warning about backtracking and dangerous locations like Vaults:5
Author: buehler, rypofalem (V5 warning idea)
Dependencies: core/data.lua, core/util.lua
--]]

f_safe_stairs = {}
f_safe_stairs.BRC_FEATURE_NAME = "safe-stairs"
f_safe_stairs.Config = {
  warn_v5 = true, -- Prompt before entering Vaults:5
  warn_stairs_threshold = 5, -- Warn if taking stairs back within # turns; 0 to disable
} -- f_safe_stairs.Config (do not remove this comment)

-- Persistent variables
ss_prev_location = BRC.data.persist("ss_prev_location", "")
ss_cur_location = BRC.data.persist("ss_cur_location", "")
ss_last_stair_turn = BRC.data.persist("ss_last_stair_turn", 0)
ss_v5_unwarned = BRC.data.persist("ss_v5_unwarned", true)

-- Local config
local Config = f_safe_stairs.Config

-- Local functions
local function check_new_location(cmd)
  local feature = view.feature_at(0, 0)
  local one_way_stair = feature:contains("escape_hatch") or feature:contains("shaft")

  local turn_diff = you.turns() - ss_last_stair_turn
  if ss_prev_location ~= ss_cur_location and turn_diff > 0 and turn_diff < Config.warn_stairs_threshold then
    if cmd == "CMD_GO_DOWNSTAIRS" then
      if not (feature:contains("down") or feature:contains("shaft")) then return BRC.util.do_cmd(cmd) end
    elseif cmd == "CMD_GO_UPSTAIRS" then
      if not feature:contains("up") then return BRC.util.do_cmd(cmd) end
    else
      return BRC.log.error("Invalid command: " .. cmd)
    end

    if not BRC.mpr.yesno("Really go right back?") then return BRC.mpr.okay() end
  elseif Config.warn_v5 and ss_v5_unwarned and ss_cur_location == "Vaults4" and cmd == "CMD_GO_DOWNSTAIRS" then
    if feature:contains("down") or feature:contains("shaft") then
      if not BRC.mpr.yesno("Really go to Vaults:5?") then
        BRC.mpr.okay()
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
  local cmd = "CMD_GO_DOWNSTAIRS"
  if not BRC.active then return BRC.util.do_cmd(cmd) end
  check_new_location(cmd)
end

function macro_f_safe_stairs_up()
  local cmd = "CMD_GO_UPSTAIRS"
  if not BRC.active then return BRC.util.do_cmd(cmd) end
  check_new_location(cmd)
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
