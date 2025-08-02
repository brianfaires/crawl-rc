---- Cache weapons in inventory ----
INV_WEAP = {}

function INV_WEAP.get_key(it)
  local ret_val = it.is_ranged and "range_" or "melee_"
  ret_val = ret_val .. get_hands(it)
  if has_ego(it) then ret_val = ret_val .. "b" end
  return ret_val
end

function INV_WEAP.add_weapon(it)
  local weap_data = {}
  weap_data.is_weapon = it.is_weapon
  weap_data.ego = get_ego(it)
  weap_data.branded = weap_data.ego ~= nil
  weap_data.plus = it.plus or 0
  weap_data.acc = it.accuracy + weap_data.plus
  weap_data.damage = it.damage
  weap_data.dps = get_weap_dps(it)
  weap_data.score = get_weap_score(it)
  weap_data.unbranded_score = get_weap_score(it, true)

  weap_data.basename = it.name("base")
  weap_data.subtype = it.subtype()
  weap_data.is_ranged = it.is_ranged
  weap_data.hands = get_hands(it)
  weap_data.artefact = it.artefact
  weap_data.weap_skill = it.weap_skill
  weap_data.skill_lvl = get_skill(it.weap_skill)
 
  -- Track unique egos
  if weap_data.branded and not util.contains(INV_WEAP.egos, weap_data.ego) then
    INV_WEAP.egos[#INV_WEAP.egos+1] = weap_data.ego
  end

  -- Track max damage weapons of each type
  local keys = { INV_WEAP.get_key(it) }
  -- Also track less-restrictive versions of the key
  if weap_data.is_ranged then keys[#keys+1] = keys[1]:gsub("range", "melee") end
  if weap_data.branded then
    local len = #keys
    for i = 1, len do
      keys[len+i] = keys[i]:sub(1, -2)
    end
  end
  if weap_data.hands == 1 then
    local len = #keys
    for i = 1, len do
      keys[len+i] = keys[i]:gsub("1", "2")
    end
  end
  -- Update the max DPS for each category
  for _, key in ipairs(keys) do
    if weap_data.dps > INV_WEAP.max_dps[key].dps then
      INV_WEAP.max_dps[key].dps = weap_data.dps
      INV_WEAP.max_dps[key].acc = weap_data.acc
    end
  end

  INV_WEAP.weapons[#INV_WEAP.weapons+1] = weap_data
  return weap_data
end

function INV_WEAP.is_empty()
  return INV_WEAP.max_dps["melee_2"].dps == 0
end

function INV_WEAP.serialize()
  local tokens = { "\n---INVENTORY WEAPONS---" }
  for _, weap in ipairs(INV_WEAP.weapons) do
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
  -- `cur` comes from INV_WEAP
  if it.subtype() == cur.subtype then
    -- Exact weapon type match
    if it.artefact then return true end
    if cur.artefact then return false end
    if has_ego(cur) and not has_ego(it) then return false end
    if has_ego(it) and it.is_identified and not has_ego(cur) then
      return get_weap_score(it) / cur.score > TUNING.weap.pickup.add_ego
    end
    return get_ego(it) == cur.ego and get_weap_score(it) > cur.score
  elseif it.weap_skill == cur.weap_skill or CACHE.race == "Gnoll" then
    -- Return false if no clear upgrade possible
    if get_hands(it) > cur.hands then return false end
    if it.is_ranged ~= cur.is_ranged then return false end
    if is_polearm(cur) and not is_polearm(it) then return false end

    if it.artefact then return true end
    if cur.artefact then return false end
    
    local min_ratio = it.is_ranged and TUNING.weap.pickup.same_type_ranged or TUNING.weap.pickup.same_type_melee
    return get_weap_score(it) / cur.score > min_ratio
  end

  return false
end

function pa_pickup_weapon(it)
  -- Check if we need the first weapon of the game
  if CACHE.xl < 5 and INV_WEAP.is_empty() and you.skill("Unarmed Combat") + get_mut(MUTS.claws, true) == 0 then
    -- Staves don't go into INV_WEAP; check if we're carrying just a staff
    for inv in iter.invent_iterator:new(items.inventory()) do
      if inv.is_weapon then return false end -- fastest way to check if it's a staff
    end
    return true
  end

  if has_risky_ego(it) then return false end

  for _,inv in ipairs(INV_WEAP.weapons) do
    if is_weapon_upgrade(it, inv) then return true end
  end
end


---- Alert types ----
local function alert_first_ranged(it)
  if alerted_first_ranged_1h then return false end
  if not it.is_ranged then return false end

  if get_hands(it) == 1 then
    alerted_first_ranged = true
    alerted_first_ranged_1h = true
    return pa_alert_item(it, "First ranged weapon (1-handed)", EMOJI.RANGED, CONFIG.fm_alert.early_weap)
  else
    if alerted_first_ranged then return false end
    if have_shield() then return false end
    alerted_first_ranged = true
    return pa_alert_item(it, "First ranged weapon", EMOJI.RANGED, CONFIG.fm_alert.early_weap)
  end
end

local function alert_first_polearm(it)
  if alerted_first_polearm_1h then return false end
  if not is_polearm(it) then return false end
  if CACHE.s_ranged > 2 then return false end -- Don't bother if learning ranged

  if get_hands(it) == 1 then
    alerted_first_polearm = true
    alerted_first_polearm_1h = true
    return pa_alert_item(it, "First 1-handed polearm", EMOJI.POLEARM, CONFIG.fm_alert.early_weap)
  else
    if alerted_first_polearm then return false end
    if have_shield() then return false end
    alerted_first_polearm = true
    return pa_alert_item(it, "First polearm", EMOJI.POLEARM, CONFIG.fm_alert.early_weap)
  end
end

local function alert_early_weapons(it)
  -- Alert really good usable ranged weapons
  if CACHE.xl <= TUNING.weap.alert.early_ranged.xl then
    if it.is_identified and it.is_ranged then
      if it.plus >= TUNING.weap.alert.early_ranged.min_plus and has_ego(it) or
         it.plus >= TUNING.weap.alert.early_ranged.branded_min_plus then
          if get_hands(it) == 1 or not have_shield() or
            CACHE.s_shields <= TUNING.weap.alert.early_ranged.max_shields then
              return pa_alert_item(it, "Ranged weapon", EMOJI.RANGED, CONFIG.fm_alert.early_weap)
          end
      end
    end
  end

  if CACHE.xl <= TUNING.weap.alert.early.xl then
    -- Skip items if we're clearly going another route
    local skill_diff = get_skill(CACHE.top_weap_skill) - get_skill(it.weap_skill)
    local max_skill_diff = CACHE.xl * TUNING.weap.alert.early.skill.factor + TUNING.weap.alert.early.skill.offset
    if skill_diff > max_skill_diff then return false end

    if has_ego(it) or it.plus and it.plus >= TUNING.weap.alert.early.branded_min_plus then
      return pa_alert_item(it, "Early weapon", EMOJI.WEAPON, CONFIG.fm_alert.early_weap)
    end
  end

  return false
end

-- Check if weapon is worth alerting for, informed by a weapon currently in inventory
-- `cur` comes from INV_WEAP
local function alert_interesting_weapon(it, cur)
  if it.artefact and it.is_identified then
    return pa_alert_item(it, "Artefact weapon", EMOJI.ARTEFACT, CONFIG.fm_alert.new_weap)
  end

  local inv_best = INV_WEAP.max_dps[INV_WEAP.get_key(it)]
  local best_dps = math.max(cur.dps, inv_best and inv_best.dps or 0)
  local best_score = math.max(cur.score, inv_best and get_weap_score(inv_best) or 0)

  if cur.subtype == it.subtype() then
    -- Exact weapon type match; alert new egos or higher DPS/weap_score
    if not cur.artefact and has_ego(it, true) and get_ego(it) ~= cur.ego then
      return pa_alert_item(it, "Diff ego", EMOJI.EGO, CONFIG.fm_alert.new_weap)
    elseif get_weap_score(it) > best_score or get_weap_dps(it) > best_dps then
      return pa_alert_item(it, "Higher DPS", EMOJI.WEAPON, CONFIG.fm_alert.new_weap)
    end
    return false
  end
  
  if it.is_ranged ~= cur.is_ranged then return false end
  if 2 * get_skill(it.weap_skill) < get_skill(cur.weap_skill) then return false end
  
  -- Penalize lower-trained skills
  local damp = TUNING.weap.alert.low_skill_penalty_damping
  local penalty = (get_skill(it.weap_skill) + damp) / (get_skill(CACHE.top_weap_skill) + damp)
  local score_ratio = penalty * get_weap_score(it) / best_score

  if get_hands(it) > cur.hands then
    if offhand_is_free() or (CACHE.s_shields < TUNING.weap.alert.add_hand.ignore_sh_lvl) then
      if has_ego(it) and not util.contains(INV_WEAP.egos, get_ego(it)) and score_ratio > TUNING.weap.alert.new_ego then
        return pa_alert_item(it, "New ego (2-handed)", EMOJI.EGO, CONFIG.fm_alert.new_weap)
      elseif score_ratio > TUNING.weap.alert.add_hand.not_using then
        return pa_alert_item(it, "2-handed weapon", EMOJI.TWO_HANDED, CONFIG.fm_alert.new_weap)
      end
    elseif has_ego(it) and not has_ego(cur) and score_ratio > TUNING.weap.alert.add_hand.add_ego_lose_sh then
      return pa_alert_item(it, "2-handed weapon (Gain ego)", EMOJI.TWO_HANDED, CONFIG.fm_alert.new_weap)
    end
  else -- No extra hand required
    if cur.artefact then return false end
    if has_ego(it, true) then
      local it_ego = get_ego(it)
      if not has_ego(cur) then
        if score_ratio > TUNING.weap.alert.gain_ego then
          return pa_alert_item(it, "Gain ego", EMOJI.EGO, CONFIG.fm_alert.new_weap)
        end
      elseif not util.contains(INV_WEAP.egos, it_ego) and score_ratio > TUNING.weap.alert.new_ego then
        return pa_alert_item(it, "New ego", EMOJI.EGO, CONFIG.fm_alert.new_weap)
      end
    end
    if score_ratio > TUNING.weap.alert.pure_dps then
      return pa_alert_item(it, "Higher DPS", EMOJI.WEAPON, CONFIG.fm_alert.new_weap)
    end
  end
  
  return false
end

local function alert_interesting_weapons(it)
  for _,inv in ipairs(INV_WEAP.weapons) do
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
  if alert_first_ranged(it) then return true end
  if alert_first_polearm(it) then return true end
  if alert_early_weapons(it) then return true end

  -- Skip high score alerts if not using weapons
  if INV_WEAP.is_empty() then return false end
  return alert_weap_high_scores(it)
end


function init_pa_weapons()
  INV_WEAP.weapons = {}
  INV_WEAP.egos = {}
  
  -- Track max DPS by weapon category
  INV_WEAP.max_dps = {}
  local keys = {
    "melee_1", "melee_1b", "melee_2", "melee_2b",
    "range_1", "range_1b", "range_2", "range_2b"
  } -- INV_WEAP.max_dps (do not remove this comment)
  for _, key in ipairs(keys) do
    INV_WEAP.max_dps[key] = { dps = 0, acc = 0 }
  end
end


-------- Hooks --------
function ready_pa_weapons()
  init_pa_weapons()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.is_weapon and not is_magic_staff(inv) then
      INV_WEAP.add_weapon(inv)
      update_high_scores(inv)
    end
  end
end
