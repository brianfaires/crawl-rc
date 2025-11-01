---------------------------------------------------------------------------------------------------
-- BRC utility module
-- @module BRC.you
-- Utilities for checking character attributes and state
---------------------------------------------------------------------------------------------------

BRC.you = {}

--- Get mutation level, explicitly specifying crawl's optional params.
-- @param innate_only boolean (optional) True to count only innate mutations, else count all.
function BRC.you.mut_lvl(mutation, innate_only)
  return you.get_base_mutation_level(mutation, true, not innate_only, not innate_only)
end


---- Boolean attributes ----
function BRC.you.by_slimy_wall()
  for x = -1, 1 do
    for y = -1, 1 do
      if view.feature_at(x, y) == "slimy_wall" then return true end
    end
  end
  return false
end

function BRC.you.free_offhand()
  if BRC.you.mut_lvl("missing a hand") > 0 then return true end
  return not items.equipped_at("offhand")
end

function BRC.you.have_shield()
  return BRC.it.is_shield(items.equipped_at("offhand"))
end

function BRC.you.in_hell(exclude_vestibule)
  local branch = you.branch()
  if exclude_vestibule and branch == "Hell" then return false end
  return util.contains(BRC.HELL_BRANCHES, branch)
end

function BRC.you.miasma_immune()
  if util.contains(BRC.UNDEAD_RACES, you.race()) then return true end
  if util.contains(BRC.NONLIVING_RACES, you.race()) then return true end
  return false
end

function BRC.you.mutation_immune()
  return util.contains(BRC.UNDEAD_RACES, you.race())
end

function BRC.you.shapeshifting_skill()
  local skill = you.skill("Shapeshifting")
  local AMU = "amulet of wildshape"
  if util.exists(items.inventory(), function(i) return i.name("qual") == AMU end) then
    return skill + 5
  end
  return skill
end

function BRC.you.size_penalty()
  if util.contains(BRC.LITTLE_RACES, you.race()) then
    return BRC.SIZE_PENALTY.LITTLE
  elseif util.contains(BRC.SMALL_RACES, you.race()) then
    return BRC.SIZE_PENALTY.SMALL
  elseif util.contains(BRC.LARGE_RACES, you.race()) then
    return BRC.SIZE_PENALTY.LARGE
  else
    return BRC.SIZE_PENALTY.NORMAL
  end
end

function BRC.you.zero_stat()
  return you.strength() <= 0 or you.dexterity() <= 0 or you.intelligence() <= 0
end


---- Equipment slot functions ----
--- The number of equipment slots available for the item (usually 1)
function BRC.you.num_eq_slots(it)
  local player_race = you.race()
  if it.is_weapon then return player_race == "Coglin" and 2 or 1 end
  if BRC.it.is_aux_armour(it) then
    if player_race == "Formicid" then return it.subtype() == "gloves" and 2 or 1 end
    return player_race == "Poltergeist" and 6 or 1
  end

  return 1
end

--- Get all equipped items in the slot type for the item
-- @return (table, int) - items, and num_slots (max size the list can be)
-- This is usually a list of length 1, with num_slots==1
function BRC.you.equipped_at(it)
  local all_aux = {}
  local num_slots = BRC.you.num_eq_slots(it)
  local slot_name = it.is_weapon and "weapon"
    or BRC.it.is_body_armour(it) and "armour"
    or it.subtype()

  for i = 1, num_slots do
    local eq = items.equipped_at(slot_name, i)
    all_aux[#all_aux + 1] = eq
  end

  return all_aux, num_slots
end

---- Skill attributes ----
function BRC.you.top_wpn_skill()
  local max_weap_skill = 0
  local pref = nil
  for _, v in ipairs(BRC.WEAP_SCHOOLS) do
    if BRC.you.skill(v) > max_weap_skill then
      max_weap_skill = BRC.you.skill(v)
      pref = v
    end
  end
  return pref
end

function BRC.you.skill(skill)
  if skill and not skill:contains(",") then return you.skill(skill) end

  local skills = crawl.split(skill, ",")
  local sum = 0
  local count = 0
  for _, s in ipairs(skills) do
    sum = sum + you.skill(s)
    count = count + 1
  end

  return sum / count
end

function BRC.you.skill_with(it)
  if BRC.it.is_magic_staff(it) then
    return math.max(BRC.you.skill(BRC.it.get_staff_school(it)), BRC.you.skill("Staves"))
  end
  if it.is_weapon then return BRC.you.skill(it.weap_skill) end
  if BRC.it.is_body_armour(it) then return BRC.you.skill("Armour") end
  if BRC.it.is_shield(it) then return BRC.you.skill("Shields") end
  if BRC.it.is_talisman(it) then return BRC.you.shapeshifting_skill() end

  return nil
end
