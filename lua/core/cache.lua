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


------ Weapon data helpers ------
local function enforce_dmg_floor(target, floor)
  if CACHE.Inv.max_dps[target].dps < CACHE.Inv.max_dps[floor].dps then
    CACHE.Inv.max_dps[target] = CACHE.Inv.max_dps[floor]
  end
end

local function make_weapon_struct(it)
  local weap_data = {}

  weap_data.dps = get_weap_dps(it)
  weap_data.acc = it.accuracy + it.plus
  weap_data.ego = get_ego(it)
  weap_data.branded = has_ego(it)
  weap_data.basename = it.name("base")
  weap_data.subtype = it.subtype()

  weap_data.is_ranged = it.is_ranged
  weap_data.hands = get_hands(it)
  weap_data.artefact = it.artefact
  weap_data.plus = it.plus
  weap_data.weap_skill = it.weap_skill
  weap_data.skill_lvl = get_skill(it.weap_skill)

  return weap_data
end

function get_weap_tag(it)
  local ret_val = it.is_ranged and "ranged_" or "melee_"
  ret_val = ret_val .. get_hands(it)
  if has_ego(it) then ret_val = ret_val .. "b" end
  return ret_val
end

function generate_inv_weap_table()
  CACHE.Inv.weapons = {}
  
  for k, _ in pairs(CACHE.Inv.max_dps) do
    CACHE.Inv.max_dps[k] = { dps = 0, acc = 0 }
  end

  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_weapon(inv) and not is_staff(inv) then
      update_high_scores(inv)
      CACHE.Inv.weapons[#CACHE.Inv.weapons+1] = make_weapon_struct(inv)
      if has_ego(inv) then CACHE.Inv.weap_egos[#CACHE.Inv.weap_egos+1] = get_ego(inv) end

      local inv_dps = CACHE.Inv.weapons[#CACHE.Inv.weapons].dps
      local weap_type = get_weap_tag(inv)
      if inv_dps > CACHE.Inv.max_dps[weap_type].dps then
        CACHE.Inv.max_dps[weap_type].dps = inv_dps
        local inv_plus = inv.plus
        if not inv_plus then inv_plus = 0 end
        CACHE.Inv.max_dps[weap_type].acc = inv.accuracy + inv_plus
      end
    end
  end

  -- Copy max_dmg from more restrictive categories to less restrictive
  enforce_dmg_floor("ranged_1", "ranged_1b")
  enforce_dmg_floor("ranged_2", "ranged_2b")
  enforce_dmg_floor("melee_1", "melee_1b")
  enforce_dmg_floor("melee_2", "melee_2b")

  enforce_dmg_floor("melee_1", "ranged_1")
  enforce_dmg_floor("melee_1b", "ranged_1b")
  enforce_dmg_floor("melee_2", "ranged_2")
  enforce_dmg_floor("melee_2b", "ranged_2b")

  enforce_dmg_floor("melee_2", "melee_1")
  enforce_dmg_floor("melee_2b", "melee_1b")
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

  CACHE.top_weap_skill = "unarmed combat"
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

  -- Weapons in inventory
  CACHE.Inv = {}
  CACHE.Inv.weapons = {}
  CACHE.Inv.weap_egos = {}
  CACHE.Inv.max_dps = {
    melee_1 = {}, melee_1b = {}, melee_2 = {}, melee_2b = {},
    ranged_1 = {}, ranged_1b = {}, ranged_2 = {}, ranged_2b = {}
  }

  generate_inv_weap_table()

end
