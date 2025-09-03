--[[
Feature: pickup-alert-weapons
Description: Weapon pickup logic, caching, and alert system for the pickup-alert system
Author: buehler
Dependencies: CONFIG, COLORS, EMOJI, with_color, enqueue_mpr_opt_more, get_ego, has_ego, get_hands, is_polearm, is_ranged, get_weap_damage, get_weap_dps, get_weap_score, get_weap_delay, get_skill, util.contains, pa_alert_item, already_contains, add_to_pa_table, get_pa_keys, offhand_is_free, TUNING, has_risky_ego, get_mut, MUTS, iter.invent_iterator, have_shield, ALL_WEAP_SCHOOLS
--]]

f_pickup_alert_weapons = {}
--f_pickup_alert_weapons.BRC_FEATURE_NAME = "pickup-alert-weapons"

-- Local constants + config
local FIRST_WEAPON_XL_CUTOFF = 4 -- Stop looking for first weapon after this XL
local RANGED_XL_THRESHOLD = 3 -- At this skill level, don't bother alerting for polearms

---- Cache weapons in inventory ----
WEAP_CACHE = {}
local top_attack_skill

function WEAP_CACHE.get_primary_key(it)
  local tokens = {}
  tokens[1] = it.is_ranged and "range_" or "melee_"
  tokens[2] = tostring(it.hands)
  if it.branded then tokens[3] = "b"
  return table.concat({tokens})
end

-- Get all categories this weapon fits into
function WEAP_CACHE.get_keys(is_ranged, hands, branded)
  local base_types = {is_ranged and "range_" or "melee_"}
  local hand_types = {tostring(hands)}
  local brand_types = {branded and "b" or ""}
  
  -- Add variations for the less restrictive versions
  if hands == 1 then hand_types[2] = "2" end
  if branded then brand_types[2] = "" end
  
  -- Generate all combinations
  local keys = {}
  for _, base in ipairs(base_types) do
    for _, hand in ipairs(hand_types) do
      for _, brand in ipairs(brand_types) do
        keys[#keys+1] = table.concat({base, hand, brand})
      end
    end
  end
  
  return keys
end

function WEAP_CACHE.add_weapon(it)
  local weap_data = {}
  weap_data.is_weapon = it.is_weapon
  weap_data.basename = it.name("base")
  weap_data.subtype = it.subtype()
  weap_data.weap_skill = it.weap_skill
  weap_data.skill_lvl = get_skill(it.weap_skill)
  weap_data.is_ranged = it.is_ranged
  weap_data.hands = get_hands(it)
  weap_data.artefact = it.artefact
  weap_data.ego = get_ego(it)
  weap_data.branded = weap_data.ego ~= nil
  weap_data.plus = it.plus or 0
  weap_data.acc = it.accuracy + weap_data.plus
  weap_data.damage = it.damage
  weap_data.dps = get_weap_dps(it)
  weap_data.score = get_weap_score(it)
  weap_data.unbranded_score = get_weap_score(it, true)
  
  -- Track unique egos
  if weap_data.branded and not util.contains(WEAP_CACHE.egos, weap_data.ego) then
    WEAP_CACHE.egos[#WEAP_CACHE.egos+1] = weap_data.ego
  end

  -- Track max damage for applicable weapon categories
  local keys = WEAP_CACHE.get_keys(weap_data.is_ranged, weap_data.hands, weap_data.branded)

  -- Update the max DPS for each category
  for _, key in ipairs(keys) do
    if weap_data.dps > WEAP_CACHE.max_dps[key].dps then
      WEAP_CACHE.max_dps[key].dps = weap_data.dps
      WEAP_CACHE.max_dps[key].acc = weap_data.acc
    end
  end

  WEAP_CACHE.weapons[#WEAP_CACHE.weapons+1] = weap_data
  return weap_data
end

function WEAP_CACHE.is_empty()
    return WEAP_CACHE.max_dps["melee_2"].dps == 0 -- The most restrictive category
end

function WEAP_CACHE.serialize()
  local tokens = { "\n---INVENTORY WEAPONS---" }
  for _, weap in ipairs(WEAP_CACHE.weapons) do
    tokens[#tokens+1] = string.format("\n%s\n", weap.basename)
    for k,v in pairs(weap) do
      if k ~= "basename" then
        tokens[#tokens+1] = string.format("  %s: %s\n", k, tostring(v))
      end
    end
  end
  return table.concat(tokens, "")
end

---- Weapon pickup ----
local function is_weapon_upgrade(it, cur)
  -- `cur` comes from WEAP_CACHE
  if it.subtype() == cur.subtype then
    -- Exact weapon type match
    if it.artefact then return true end
    if cur.artefact then return false end
    if has_ego(cur) and not has_ego(it) then return false end
    if has_ego(it) and it.is_identified and not has_ego(cur) then
      return get_weap_score(it) / cur.score > TUNING.weap.pickup.add_ego
    end
    return get_ego(it) == cur.ego and get_weap_score(it) > cur.score
  elseif it.weap_skill == cur.weap_skill or you.race() == "Gnoll" then
    -- Return false if no clear upgrade possible
    if get_hands(it) > cur.hands then return false end
    if cur.is_ranged ~= it.is_ranged then return false end
    if is_polearm(cur) ~= is_polearm(it) then return false end

    if it.artefact then return true end
    if cur.artefact then return false end
    
    local min_ratio = it.is_ranged and TUNING.weap.pickup.same_type_ranged or TUNING.weap.pickup.same_type_melee
    return get_weap_score(it) / cur.score > min_ratio
  end

  return false
end

local function need_first_weapon()
    return you.xl() < FIRST_WEAPON_XL_CUTOFF and WEAP_CACHE.is_empty()
        and you.skill("Unarmed Combat") == 0
        and get_mut(MUTS.claws, true) == 0
end

function pa_pickup_weapon(it)
  -- Check if we need the first weapon of the game
  if need_first_weapon() then
    -- Staves don't go into WEAP_CACHE; check if we're carrying just a staff
    for inv in iter.invent_iterator:new(items.inventory()) do
      if inv.is_weapon then return false end -- fastest way to check if it's a staff
    end
    return true
  end

  if has_risky_ego(it) then return false end
  if already_contains(pa_items_picked, it) then return false end
  for _,inv in ipairs(WEAP_CACHE.weapons) do
    if is_weapon_upgrade(it, inv) then return true end
  end
end


---- Alert types ----
local lowest_num_hands_alerted = {
  "Ranged Weapons" = 3, -- Start with 3 (will fire both 1 and 2-handed alerts)
  "Polearms" = 3        -- Start with 3 (will fire both 1 and 2-handed alerts)
}

local function alert_first_of_skill(it)
  local skill = it.weap_skill
  if not lowest_num_hands_alerted[skill] then return false end

  local hands = get_hands(it)
  if lowest_num_hands_alerted[skill] > hands then
    -- Some early checks to skip alerts
    if hands == 2 and have_shield() then return false end
    if skill == "Polearms" and you.skill("Ranged Weapons") >= RANGED_XL_THRESHOLD then return false end

    -- Update lowest # hands alerted, and alert
    lowest_num_hands_alerted[skill] = hands
    local msg = "First " .. string.sub(skill, 1, -2) -- Trim the trailing "s"
    if hands == 1 then msg = msg .. " (1-handed)" end
    return pa_alert_item(it, msg, EMOJI.WEAPON, CONFIG.fm_alert.early_weap)
  end
  return false
end

local function alert_early_weapons(it)
  -- Alert really good usable ranged weapons
  if you.xl() <= TUNING.weap.alert.early_ranged.xl then
    if it.is_identified and it.is_ranged then
      if it.plus >= TUNING.weap.alert.early_ranged.min_plus and has_ego(it) or
         it.plus >= TUNING.weap.alert.early_ranged.branded_min_plus then
          if get_hands(it) == 1 or not have_shield() or
            you.skill("Shields") <= TUNING.weap.alert.early_ranged.max_shields then
              return pa_alert_item(it, "Ranged weapon", EMOJI.RANGED, CONFIG.fm_alert.early_weap)
          end
      end
    end
  end

  if you.xl() <= TUNING.weap.alert.early.xl then
    -- Skip items if we're clearly going another route
    local skill_diff = get_skill(top_attack_skill) - get_skill(it.weap_skill)
    local max_skill_diff = you.xl() * TUNING.weap.alert.early.skill.factor + TUNING.weap.alert.early.skill.offset
    if skill_diff > max_skill_diff then return false end

    if has_ego(it) or it.plus and it.plus >= TUNING.weap.alert.early.branded_min_plus then
      return pa_alert_item(it, "Early weapon", EMOJI.WEAPON, CONFIG.fm_alert.early_weap)
    end
  end

  return false
end

-- Check if weapon is worth alerting for, informed by a weapon currently in inventory
-- `cur` comes from WEAP_CACHE
local function alert_interesting_weapon(it, cur)
  if it.artefact and it.is_identified then
    return pa_alert_item(it, "Artefact weapon", EMOJI.ARTEFACT)
  end

  local inv_best = WEAP_CACHE.max_dps[WEAP_CACHE.get_primary_key(it)]
  local best_dps = math.max(cur.dps, inv_best and inv_best.dps or 0)
  local best_score = math.max(cur.score, inv_best and get_weap_score(inv_best) or 0)

  if cur.subtype == it.subtype() then
    -- Exact weapon type match; alert new egos or higher DPS/weap_score
    if not cur.artefact and has_ego(it, true) and get_ego(it) ~= cur.ego then
      return pa_alert_item(it, "Diff ego", EMOJI.EGO, CONFIG.fm_alert.weap_ego)
    elseif get_weap_score(it) > best_score or get_weap_dps(it) > best_dps then
      return pa_alert_item(it, "Weapon upgrade", EMOJI.WEAPON, CONFIG.fm_alert.upgrade_weap)
    end
    return false
  end
  
  if cur.is_ranged ~= it.is_ranged then return false end
  if is_polearm(cur) ~= is_polearm(it) then return false end
  if 2 * get_skill(it.weap_skill) < get_skill(cur.weap_skill) then return false end
  
  -- Penalize lower-trained skills
  local damp = TUNING.weap.alert.low_skill_penalty_damping
  local penalty = (get_skill(it.weap_skill) + damp) / (get_skill(top_attack_skill) + damp)
  local score_ratio = penalty * get_weap_score(it) / best_score

  if get_hands(it) > cur.hands then
    if offhand_is_free() or (you.skill("Shields") < TUNING.weap.alert.add_hand.ignore_sh_lvl) then
      if has_ego(it) and not util.contains(WEAP_CACHE.egos, get_ego(it)) and score_ratio > TUNING.weap.alert.new_ego then
        return pa_alert_item(it, "New ego (2-handed)", EMOJI.EGO, CONFIG.fm_alert.weap_ego)
      elseif score_ratio > TUNING.weap.alert.add_hand.not_using then
        return pa_alert_item(it, "2-handed weapon", EMOJI.TWO_HANDED, CONFIG.fm_alert.upgrade_weap)
      end
    elseif has_ego(it) and not has_ego(cur) and score_ratio > TUNING.weap.alert.add_hand.add_ego_lose_sh then
      return pa_alert_item(it, "2-handed weapon (Gain ego)", EMOJI.TWO_HANDED, CONFIG.fm_alert.weap_ego)
    end
  else -- No extra hand required
    if cur.artefact then return false end
    if has_ego(it, true) then
      local it_ego = get_ego(it)
      if not has_ego(cur) then
        if score_ratio > TUNING.weap.alert.gain_ego then
          return pa_alert_item(it, "Gain ego", EMOJI.EGO, CONFIG.fm_alert.weap_ego)
        end
      elseif not util.contains(WEAP_CACHE.egos, it_ego) and score_ratio > TUNING.weap.alert.new_ego then
        return pa_alert_item(it, "New ego", EMOJI.EGO, CONFIG.fm_alert.weap_ego)
      end
    end
    if score_ratio > TUNING.weap.alert.pure_dps then
      return pa_alert_item(it, "Weapon upgrade", EMOJI.WEAPON, CONFIG.fm_alert.upgrade_weap)
    end
  end
  
  return false
end

local function alert_interesting_weapons(it)
  for _,inv in ipairs(WEAP_CACHE.weapons) do
    if alert_interesting_weapon(it, inv) then return true end
  end
  return false
end

local function alert_weap_high_scores(it)
  local category = update_high_scores(it)
  if not category then return false end
  return pa_alert_item(it, category, EMOJI.WEAPON, CONFIG.fm_alert.high_score_weap)
end

function pa_alert_weapon(it)
  if alert_interesting_weapons(it) then return true end
  if alert_first_of_skill(it) then return true end
  if alert_early_weapons(it) then return true end

  -- Skip high score alerts if not using weapons
  if WEAP_CACHE.is_empty() then return false end
  return alert_weap_high_scores(it)
end


-- Hook functions
function f_pickup_alert_weapons.init()
  WEAP_CACHE.weapons = {}
  WEAP_CACHE.egos = {}
  
  -- Track max DPS by weapon category
  WEAP_CACHE.max_dps = {}
  local keys = {
    "melee_1", "melee_1b", "melee_2", "melee_2b",
    "range_1", "range_1b", "range_2", "range_2b"
  } -- WEAP_CACHE.max_dps (do not remove this comment)
  for _, key in ipairs(keys) do
    WEAP_CACHE.max_dps[key] = { dps = 0, acc = 0 }
  end

  -- Set top weapon skill
  top_attack_skill = "Unarmed Combat"
  local max_weap_skill = get_skill(top_attack_skill)
  for _,v in ipairs(ALL_WEAP_SCHOOLS) do
    if get_skill(v) > max_weap_skill then
      max_weap_skill = get_skill(v)
      top_attack_skill = v
    end
  end
end


-------- Hooks --------
function f_pickup_alert_weapons.ready()
  f_pickup_alert_weapons:init()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.is_weapon and not is_magic_staff(inv) then
      WEAP_CACHE.add_weapon(inv)
      update_high_scores(inv)
    end
  end
end
