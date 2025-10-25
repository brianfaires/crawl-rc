--[[
Feature: startup
Description: Handles startup features like skill menu display and auto-setting skill targets
Author: rwbarton, buehler
Dependencies: core/constants.lua, core/util.lua
--]]

f_startup = {}
f_startup.BRC_FEATURE_NAME = "startup"
f_startup.Config = {
  show_skills_menu = false, -- Show skills menu on startup
  set_all_targets = true, -- Set all targets, even if only focusing one
  focus_one_skill = true, -- Focus one skill at a time, even if setting all targets
  auto_set_skill_targets = {
    { "Stealth", 2.0 }, -- First, focus stealth to 2.0
    { "Fighting", 2.0 }, -- If already have stealth, focus fighting to 2.0
  },

  -- For non-spellcasters, add preferred weapon type as 3rd skill target
  init = [[
    if you.skill("Spellcasting") == 0 then
      local t = f_startup.Config.auto_set_skill_targets
      t[#t + 1] = { BRC.you.top_wpn_skill(), 8.0 }
    end
  ]],
} -- f_startup.Config (do not remove this comment)

---- Local config alias ----
local Config = f_startup.Config

---- Hook functions ----
function f_startup.ready()
  if you.turns() == 0 then
    -- Disable all skills by default
    for _, s in ipairs(BRC.TRAINING_SKILLS) do
      if s ~= Config.auto_set_skill_targets[1][1] then you.train_skill(s, 0) end
    end

    -- Auto-set skill targets
    if Config.auto_set_skill_targets and you.race() ~= "Gnoll" then
      for i, skill_target in ipairs(Config.auto_set_skill_targets) do
        local skill, target = unpack(skill_target)
        if you.skill(skill) < target then
          you.set_training_target(skill, target)
          if i == 1 or not Config.focus_one_skill then you.train_skill(skill, 1) end
          if not Config.set_all_targets then break end
        end
      end
    end
  end

  -- Show skills menu: Disable for non-Wanderer Gnolls
  if Config.show_skills_menu and (you.race() ~= "Gnoll" or you.class() == "Wanderer") then
    BRC.util.do_cmd("CMD_DISPLAY_SKILLS")
  end
end
