--[[
Feature: startup
Description: Handles startup features like skill menu display and auto-setting skill targets
Author: rwbarton, buehler
Dependencies: core/constants.lua, core/util.lua
--]]

f_startup = {}
f_startup.BRC_FEATURE_NAME = "startup"
f_startup.Config = {
  show_skills_on_startup = true, -- Show skills menu on startup
  auto_set_skill_targets = {
    { "Stealth", 2.0 }, -- First, focus stealth to 2.0
    { "Fighting", 2.0 }, -- If already have stealth, focus fighting to 2.0
  },
} -- f_startup.Config (do not remove this comment)

-- Local config
local Config = f_startup.Config

-- Hook functions
function f_startup.ready()
  if you.turns() == 0 then
    if f_startup.Config.show_skills_on_startup then
      local show_skills_on_startup = (you.race() ~= "Gnoll" or you.class() == "Wanderer")
      if show_skills_on_startup then BRC.util.do_cmd("CMD_DISPLAY_SKILLS") end
    end

    ---- Auto-set default skill targets ----
    if f_startup.Config.auto_set_skill_targets and you.race() ~= "Gnoll" then
      for _, skill_target in ipairs(Config.auto_set_skill_targets) do
        local skill, target = unpack(skill_target)
        if you.skill(skill) < target then
          for _, s in ipairs(BRC.TRAINING_SKILLS) do
            you.train_skill(s, 0)
          end
          you.set_training_target(skill, target)
          you.train_skill(skill, 2)
          break
        end
      end
    end
  end
end
