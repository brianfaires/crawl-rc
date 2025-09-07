--[[
Feature: after-shaft
Description: Automatically stops exploration on stairs after falling into a shaft
Author: buehler
Dependencies: core/config.lua, core/data.lua, core/constants.lua, core/util.lua
--]]

f_after_shaft = {}
f_after_shaft.BRC_FEATURE_NAME = "after-shaft"

-- Persistent variables
as_shaft_depth = BRC.data.persist("as_shaft_depth", 0)
as_shaft_branch = BRC.data.persist("as_shaft_branch", "NA")

-- Hook functions
function f_after_shaft.init()
  if not BRC.Config.stop_on_stairs_after_shaft then return end

  if you.turns() == 0 and you.class() == "Delver" then
    as_shaft_depth = 1
    as_shaft_branch = you.branch()
  end

  BRC.set.explore_stop("stairs", as_shaft_depth ~= 0)
end

function f_after_shaft.c_message(text, channel)
  if not BRC.Config.stop_on_stairs_after_shaft then return end
  if channel ~= "plain" or BRC.you.in_hell() then return end
  if as_shaft_depth ~= 0 and you.branch() == as_shaft_branch then return end

  local text_fall = "ou fall into a shaft"
  local text_sucked = "ou are sucked into a shaft"
  if text:find(text_fall, 1, true) or text:find(text_sucked, 1, true) then
    as_shaft_depth = you.depth()
    as_shaft_branch = you.branch()
    BRC.set.explore_stop("stairs", true)
  end
end

function f_after_shaft.ready()
  if not BRC.Config.stop_on_stairs_after_shaft then return end
  if you.depth() == as_shaft_depth and you.branch() == as_shaft_branch then
    BRC.set.explore_stop("stairs", false)
    as_shaft_depth = 0
    as_shaft_branch = "NA"
  end
end
