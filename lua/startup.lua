loadfile("lua/config.lua")
loadfile("lua/constants.lua")

if you.turns() == 0 then
  ---- Skill menu on startup (by rwbarton, edits by buehler) ----
  if CONFIG.show_skills_on_startup then
    local show_skills_on_startup = (you.race() ~= "Gnoll" or you.class() == "Wanderer")
    if show_skills_on_startup then
      crawl.sendkeys("m")
    end
  end

  ---- Auto-set default skill targets ----
  if CONFIG.auto_set_skill_targets then
    for _, skill_target in ipairs(CONFIG.auto_set_skill_targets) do
      local skill, target = unpack(skill_target)
      if you.skill(skill) < target then
        for _, s in ipairs(all_training_skills) do
          you.train_skill (s, 0)
        end
        you.set_training_target (skill, target)
        you.train_skill (skill, 2)
        break
      end
    end
  end

end