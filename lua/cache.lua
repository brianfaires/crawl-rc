-- Cache of commonly pulled values, for increased performance
if loaded_cache then return end
loaded_cache = true
loadfile("crawl-rc/lua/constants.lua")

l_cache = {}

-- Once per game
l_cache.class = you.class()
l_cache.race = you.race()
if l_cache.race == "Spriggan" then l_cache.size_penalty = SIZE_PENALTY.LITTLE
elseif l_cache.race == "Kobold" then l_cache.size_penalty = SIZE_PENALTY.SMALL
elseif l_cache.race == "Armataur" or l_cache.race == "Naga" or
    l_cache.race == "Oni" or l_cache.race == "Troll" then l_cache.size_penalty = SIZE_PENALTY.LARGE
else l_cache.size_penalty = SIZE_PENALTY.NORMAL
end
l_cache.undead =  util.contains(all_undead_races, l_cache.race)
l_cache.poison_immune = you.res_poison() >= 3


-- Once per turn
function ready_l_cache()
  l_cache.turn = you.turns()
  l_cache.str = you.strength()
  l_cache.dex = you.dexterity()
  l_cache.int = you.intelligence()
  l_cache.will = you.willpower()
  
  l_cache.hp, l_cache.mhp = you.hp()
  l_cache.mp, l_cache.mmp = you.mp()

  l_cache.god = you.god()
  l_cache.xl = you.xl()

  l_cache.s_armour = you.skill("Armour")
  l_cache.s_shields = you.skill("Shields")
  l_cache.s_dodging = you.skill("Dodging")
  l_cache.s_fighting = you.skill("Fighting")
  l_cache.s_spellcasting = you.skill("Spellcasting")

  l_cache.rMut = you.res_mutation()
  l_cache.rPois = you.res_poison()
  l_cache.rElec = you.res_shock()
  l_cache.rCorr = you.res_corr()
  l_cache.rF = you.res_fire()
  l_cache.rC = you.res_cold()
  l_cache.rN = you.res_draining()

end
