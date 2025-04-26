---------------------------------------------
---- Skill menu on startup (by rwbarton) ----
---------------------------------------------
local need_skills_opened = true
if you.turns() == 0 and need_skills_opened then
  need_skills_opened = false
  crawl.sendkeys("m!!")
end
