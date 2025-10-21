--[[
Feature: after-shaft
Description: Automatically stops exploration on stairs after falling into a shaft
Author: buehler
Dependencies: core/data.lua, core/util.lua
--]]

f_after_shaft = {}
f_after_shaft.BRC_FEATURE_NAME = "after-shaft"

---- Persistent variables ----
as_shaft_location = BRC.Data.persist("as_shaft_location", nil)

---- Hook functions ----
function f_after_shaft.init()
  if you.turns() == 0 and you.class() == "Delver" then as_shaft_location = "D:1" end
  BRC.set.explore_stop("stairs", as_shaft_location ~= nil)
end

function f_after_shaft.c_message(text, channel)
  if channel ~= "plain" or as_shaft_location then return end
  if text:contains("ou fall into a shaft") or text:contains("ou are sucked into a shaft") then
    as_shaft_location = you.where()
    BRC.set.explore_stop("stairs", true)
  end
end

function f_after_shaft.ready()
  if you.where() == as_shaft_location then
    BRC.set.explore_stop("stairs", false)
    as_shaft_location = nil
  end
end
