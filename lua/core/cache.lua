-- Cache of commonly pulled values, for better performance
CACHE = {}

function dump_cache()
  local tokens = { "\n---CACHE---" }
  for k,v in pairs(CACHE) do
    if type(v) == "table" then
      tokens[#tokens+1] = string.format("  %s:", k)
      for k2,v2 in pairs(v) do
        tokens[#tokens+1] = string.format("    %s: %s", k2, v2)
      end
    else
      if v == true then v = "true" elseif v == false then v = "false" end
      tokens[#tokens+1] = string.format("  %s: %s", k, v)
    end
  end

  tokens[#tokens+1] = "\n"
  return table.concat(tokens, "\n")
end

function init_cache()
  if CONFIG.debug_init then crawl.mpr("Initializing cache") end

  CACHE = {}

  CACHE.class = you.class()
  CACHE.race = you.race()
  if util.contains(ALL_LITTLE_RACES, CACHE.race) then CACHE.size_penalty = SIZE_PENALTY.LITTLE
  elseif util.contains(ALL_SMALL_RACES, CACHE.race) then CACHE.size_penalty = SIZE_PENALTY.SMALL
  elseif util.contains(ALL_LARGE_RACES, CACHE.race) then CACHE.size_penalty = SIZE_PENALTY.LARGE
  else CACHE.size_penalty = SIZE_PENALTY.NORMAL
  end
  CACHE.undead =  util.contains(ALL_UNDEAD_RACES, CACHE.race)
  CACHE.poison_immune = you.res_poison() >= 3

  ready_cache()
end


------------------- Hooks -------------------
function ready_cache()
  CACHE.hp, CACHE.mhp = you.hp()
  CACHE.mp, CACHE.mmp = you.mp()
  CACHE.turn = you.turns()
  CACHE.str = you.strength()
  CACHE.dex = you.dexterity()
  CACHE.int = you.intelligence()
  CACHE.will = you.willpower()
  CACHE.xl = you.xl()
  CACHE.god = you.god()
  CACHE.have_orb = you.have_orb()
  CACHE.branch = you.branch()
  CACHE.depth = you.depth()

  CACHE.rMut = you.res_mutation()
  CACHE.rPois = you.res_poison()
  CACHE.rElec = you.res_shock()
  CACHE.rCorr = you.res_corr()
  CACHE.rF = you.res_fire()
  CACHE.rC = you.res_cold()
  CACHE.rN = you.res_draining()

  CACHE.s_armour = you.skill("Armour")
  CACHE.s_shields = you.skill("Shields")
  CACHE.s_dodging = you.skill("Dodging")
  CACHE.s_fighting = you.skill("Fighting")
  CACHE.s_spellcasting = you.skill("Spellcasting")
  CACHE.s_ranged = you.skill("Ranged Weapons")
  CACHE.s_polearms = you.skill("Polearms")

  CACHE.top_weap_skill = "Unarmed Combat"
  local max_weap_skill = get_skill(CACHE.top_weap_skill)
  for _,v in ipairs(ALL_WEAP_SCHOOLS) do
    if get_skill(v) > max_weap_skill then
      max_weap_skill = get_skill(v)
      CACHE.top_weap_skill = v
    end
  end
end
