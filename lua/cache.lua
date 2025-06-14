-- Cache of commonly pulled values, for increased performance
if loaded_cache then return end
loaded_cache = true
loadfile("crawl-rc/lua/constants.lua")

CACHE = {}

-- Once per game
CACHE.class = you.class()
CACHE.race = you.race()
if CACHE.race == "Spriggan" then CACHE.size_penalty = SIZE_PENALTY.LITTLE
elseif CACHE.race == "Kobold" then CACHE.size_penalty = SIZE_PENALTY.SMALL
elseif CACHE.race == "Armataur" or CACHE.race == "Naga" or
    CACHE.race == "Oni" or CACHE.race == "Troll" then CACHE.size_penalty = SIZE_PENALTY.LARGE
else CACHE.size_penalty = SIZE_PENALTY.NORMAL
end
CACHE.undead =  util.contains(all_undead_races, CACHE.race)
CACHE.poison_immune = you.res_poison() >= 3


-- Once per turn
function ready_CACHE()
  CACHE.turn = you.turns()
  CACHE.str = you.strength()
  CACHE.dex = you.dexterity()
  CACHE.int = you.intelligence()
  CACHE.will = you.willpower()
  
  CACHE.hp, CACHE.mhp = you.hp()
  CACHE.mp, CACHE.mmp = you.mp()

  CACHE.god = you.god()
  CACHE.xl = you.xl()

  CACHE.s_armour = you.skill("Armour")
  CACHE.s_shields = you.skill("Shields")
  CACHE.s_dodging = you.skill("Dodging")
  CACHE.s_fighting = you.skill("Fighting")
  CACHE.s_spellcasting = you.skill("Spellcasting")

  CACHE.rMut = you.res_mutation()
  CACHE.rPois = you.res_poison()
  CACHE.rElec = you.res_shock()
  CACHE.rCorr = you.res_corr()
  CACHE.rF = you.res_fire()
  CACHE.rC = you.res_cold()
  CACHE.rN = you.res_draining()

end
