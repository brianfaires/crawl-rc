--[[
Feature: safe-stairs
Description: Prevent accidental stairs use and warn for Vaults:5 entry
Author: buehler, rypofalem (V5 warning idea)
Dependencies: core/data.lua, core/util.lua
--]]

f_safe_stairs = {}
f_safe_stairs.BRC_FEATURE_NAME = "safe-stairs"
f_safe_stairs.Config = {
  warn_backtracking = true, -- Warn if immediately taking stairs twice in a row
  warn_v5 = true, -- Prompt before entering Vaults:5
} -- f_safe_stairs.Config (do not remove this comment)

-- Persistent variables
ss_prev_location = BRC.data.persist("ss_prev_location", you.branch() .. you.depth())
ss_v5_warned = BRC.data.persist("ss_v5_warned", false)

-- Local config
local Config = f_safe_stairs.Config

-- Local variables
local ss_cur_location

-- Local functions
local function check_new_location(cmd)
  local feature = view.feature_at(0, 0)

  if Config.warn_backtracking and ss_prev_location ~= ss_cur_location then
    if cmd == "CMD_GO_DOWNSTAIRS" then
      if not (feature:contains("down") or feature:contains("shaft")) then return BRC.util.do_cmd(cmd) end
    elseif cmd == "CMD_GO_UPSTAIRS" then
      if not feature:contains("up") then return BRC.util.do_cmd(cmd) end
    else
      return BRC.log.error("Invalid command: " .. cmd)
    end

    if not BRC.mpr.yesno("Really go right back?") then return BRC.mpr.okay() end
  end

  if Config.warn_v5 and not ss_v5_warned and ss_cur_location == "Vaults4" and cmd == "CMD_GO_DOWNSTAIRS" then
    if feature:contains("down") or feature:contains("shaft") then
      if not BRC.mpr.yesno("Really go to Vaults:5?") then return BRC.mpr.okay() end
      ss_v5_warned = true
    end
  end

  BRC.util.do_cmd(cmd)
end

-- Macro functions
function macro_f_safe_stairs_down()
  if not BRC.active then return BRC.util.do_cmd("CMD_GO_DOWNSTAIRS") end
  check_new_location("CMD_GO_DOWNSTAIRS")
end

function macro_f_safe_stairs_up()
  if not BRC.active then return BRC.util.do_cmd("CMD_GO_UPSTAIRS") end
  check_new_location("CMD_GO_UPSTAIRS")
end

-- Hook functions
function f_safe_stairs.init()
  ss_cur_location = you.branch() .. you.depth()
  BRC.set.macro(BRC.get.command_key("CMD_GO_DOWNSTAIRS") or ">", "macro_f_safe_stairs_down")
  BRC.set.macro(BRC.get.command_key("CMD_GO_UPSTAIRS") or "<", "macro_f_safe_stairs_up")
end

function f_safe_stairs.ready()
  ss_prev_location = ss_cur_location
  ss_cur_location = you.branch() .. you.depth()
end
