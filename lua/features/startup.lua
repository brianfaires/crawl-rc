--[[
Feature: startup
Description: Handles startup features like skill menu display and auto-setting skill targets
Author: rwbarton, buehler
Dependencies: CONFIG
--]]

f_startup = {}
f_startup.BRC_FEATURE_NAME = "startup"

-- Hook functions
function f_startup.ready()
  if you.turns() == 0 then
    if BRC.Config.show_skills_on_startup then
      local show_skills_on_startup = (you.race() ~= "Gnoll" or you.class() == "Wanderer")
      if show_skills_on_startup then crawl.sendkeys("m") end
    end

    ---- Auto-set default skill targets ----
    if BRC.Config.auto_set_skill_targets then
      for _, skill_target in ipairs(BRC.Config.auto_set_skill_targets) do
        local skill, target = unpack(skill_target)
        if you.skill(skill) < target then
          for _, s in ipairs(BRC.ALL_TRAINING_SKILLS) do
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
