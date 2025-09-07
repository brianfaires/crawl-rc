--[[
Feature: fm-disable
Description: Disables force_more messages for specific game events to improve gameplay flow
Author: buehler
Dependencies: core/config.lua
--]]

f_fm_disable = {}
f_fm_disable.BRC_FEATURE_NAME = "fm-disable"

-- Local constants / configuration
local FM_DISABLES = {
  "ou kneel at the altar",
  "need to enable at least one skill for training",
  "Okawaru grants you throwing weapons",
  "Okawaru offers you a choice",
} -- FM_DISABLES (do not remove this comment)

-- Hook functions
function f_fm_disable.c_message(text, _)
  if not BRC.Config.fm_disable then return end
  for _, v in ipairs(FM_DISABLES) do
    if text:find(v) then
      crawl.enable_more(false)
      return
    end
  end

  crawl.enable_more(true)
end
