---- Skill menu on startup (orig by rwbarton) ----
local show_skills_on_startup = (you.race() ~= Gnoll or you.class() == "Wanderer")
if you.turns() == 0 and show_skills_on_startup then
  crawl.sendkeys("m!!")
end
