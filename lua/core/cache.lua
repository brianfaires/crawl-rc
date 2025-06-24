-- Cache of commonly pulled values, for better performance
CACHE = {}

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

  -- Mutations
  CACHE.mutations = {}
  for _,v in ipairs(crawl.split(you.mutation_overview(), ",")) do
    local key = v:sub(1, -3)
    local value = tonumber(v:sub(-2))
    CACHE.mutations[key] = value
  end

  CACHE.temp_mutations = {} -- Placeholder for now
end
