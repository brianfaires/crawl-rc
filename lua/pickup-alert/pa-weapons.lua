INV_WEAP = {}

function INV_WEAP.get_key(it)
  local ret_val = it.is_ranged and "range_" or "melee_"
  ret_val = ret_val .. get_hands(it)
  if has_ego(it) then ret_val = ret_val .. "b" end
  return ret_val
end

function INV_WEAP.add_weapon(it)
  local weap_data = {}

  weap_data.ego = get_ego(it)
  weap_data.branded = weap_data.ego ~= nil
  weap_data.dps = get_weap_dps(it)
  weap_data.plus = it.plus
  weap_data.acc = it.accuracy + it.plus
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

function INV_WEAP.get_best(it)
  return INV_WEAP.max_dps[INV_WEAP.get_key(it)]
end

function INV_WEAP.is_empty()
  return INV_WEAP.max_dps["melee_2"].dps == 0
end

---- Weapon pickup ----
local function should_pickup_weapon(it, cur)
  if it.subtype() == cur.subtype then
    -- Exact weapon type match
    if it.artefact then return true end
    if cur.artefact then return false end
    if has_ego(it) and it.is_identified and not cur.branded then
      return get_weap_dps(it) > 0.85*cur.dps
    end
    if cur.branded and not has_ego(it) then return false end
    return it.ego() == cur.ego and get_weap_dps(it) > cur.dps + 0.001
  elseif it.weap_skill == cur.weap_skill or CACHE.race == "Gnoll" then
    -- Return false if no upgrade possible
    if get_hands(it) > cur.hands then return false end
    if it.is_ranged ~= cur.is_ranged then return false end
    if is_polearm(cur) and not is_polearm(it) then return false end

    if it.artefact then return true end
    if cur.artefact then return false end
    if it.branded and not it.is_identified then return false end
    --if cur.branded and not it.branded then return false end

    if it.is_ranged then return get_weap_dps(it) > cur.dps + 0.001 end

    local it_plus = it.plus or 0
    local it_score = get_weap_dps(it) + (it.accuracy + it_plus)/3
    local cur_score = cur.dps + cur.acc/3

    return it_score > 1.1*cur_score
  end

  return false
end

function pa_pickup_weapon(it)
  for _,inv in ipairs(INV_WEAP.weapons) do
    if should_pickup_weapon(it, inv) then return true end
  end

  -- Check if we need the first weapon of the game
  return CACHE.xl < 6 and INV_WEAP.is_empty() and
      you.skill("Unarmed Combat") == 0 and get_mut("claws", true) == 0
end


---- Alert types ----
local function alert_first_ranged(it)
  if not it.is_ranged then return false end

  if get_hands(it) == 2 then
    if alerted_first_range_2h == 0 then return false end
    if have_shield() then return false end
    alerted_first_range_2h = 1
    return pa_alert_item(it, "Ranged weapon (2-handed)", EMOJI.RANGED)
  else
    if alerted_first_range_1h ~= 0 then return false end
    alerted_first_range_1h = 1
    return pa_alert_item(it, "Ranged weapon", EMOJI.RANGED)
  end
end

local function alert_first_polearm(it)
  if alerted_first_polearm ~= 0 then return false end
  if not is_polearm(it) then return false end
  if get_hands(it) == 2 and have_shield() then return false end
  alerted_first_polearm = 1
  if CACHE.s_ranged > 2 then return false end -- Don't bother if learning ranged
  return pa_alert_item(it, "First polearm", EMOJI.POLEARM)
end

local function alert_early_weapons(it)
  -- Alert really good usable ranged weapons
  if CACHE.xl <= 14 then
    if it.is_identified and it.is_ranged then
      if has_ego(it) and it.plus >= 5 or it.plus >= 7 then
        if get_hands(it) == 1 or not have_shield() or CACHE.s_shields <= 8 then
          return pa_alert_item(it, "Ranged weapon", EMOJI.RANGED)
        end
      end
    end
  end

  if CACHE.xl < 8 then
    -- Skip items if we're clearly going another route
    local skill_diff = get_skill(CACHE.top_weap_skill) - get_skill(it.weap_skill)
    if skill_diff > 1.5*CACHE.xl+3 then return false end

    if has_ego(it) or it.plus and it.plus >= 4 then
      return pa_alert_item(it, "Early weapon", EMOJI.WEAPON)
    end
  end

  return false
end

-- Check if weapon is worth alerting for, informed by a weapon currently in inventory
local function alert_interesting_weapon(it, cur)
  if it.artefact and it.is_identified then
    return pa_alert_item(it, "Artefact weapon", EMOJI.ARTEFACT)
  end

  if cur.subtype == it.subtype() then
    -- Exact weapon type match
    if not cur.artefact and has_ego(it) and it.ego() ~= cur.ego then
      return pa_alert_item(it, "New ego", EMOJI.EGO)
    end
    if get_weap_dps(it) > INV_WEAP.get_best(it).dps then
      return pa_alert_item(it, "Stronger weapon", EMOJI.STRONGER)
    end
  elseif get_skill(it.weap_skill) >= 0.5 * get_skill(cur.weap_skill) then
    -- A usable weapon school
    if it.is_ranged ~= cur.is_ranged then return false end


    -- Create penalty to disfavor weapons from lower-trained skills
    local penalty = (get_skill(it.weap_skill)+8) / (get_skill(CACHE.top_weap_skill)+8)

    if get_hands(it) == 2 and cur.hands == 1 then
      -- Item requires an extra hand
      if has_ego(it) and not cur.branded then
        if get_weap_dps(it) > 0.8*cur.dps then
          return pa_alert_item(it, "2-handed weapon", EMOJI.TWO_HANDED)
        end
      end

      if not have_shield() then
        if has_ego(it) and not (it.ego() == "heavy" or it.ego() == "speed") and
          not util.contains(INV_WEAP.weap_egos, it.ego()) then
            return pa_alert_item(it, "New ego", EMOJI.EGO)
        end
        if not cur.branded and
          get_weap_dps(it) > INV_WEAP.get_best(it).dps then
            return pa_alert_item(it, "2-handed weapon", EMOJI.TWO_HANDED)
        end
        if cur.branded and not has_ego(it) and
          get_weap_dps(it) > INV_WEAP.get_best(it).dps then
            return pa_alert_item(it, "2-handed weapon", EMOJI.TWO_HANDED)
        end
      elseif CACHE.s_shields <= 4 then
        -- Not really training shields; may be interested in big upgrades
        if penalty*get_weap_dps(it) >= INV_WEAP.get_best(it).dps then
          return pa_alert_item(it, "2-handed weapon", EMOJI.TWO_HANDED)
        end
      end
    else
      -- Item uses same number of hands or fewer
      if cur.artefact then return false end
      if has_ego(it) and not (it.ego() == "heavy" or it.ego() == "speed") then
        local it_dps = get_weap_dps(it)
        local dps_delta = it_dps - INV_WEAP.get_best(it).dps
        if penalty then
          if dps_delta >= 0 then dps_delta = dps_delta * penalty end
        else dps_delta = dps_delta / penalty
        end

        local dps_delta_ratio = dps_delta / it_dps

        if not cur.branded then
          if dps_delta_ratio >= -0.2 then
            return pa_alert_item(it, "New ego", EMOJI.EGO)
          end
        elseif it.ego() == cur.ego then
          if dps_delta_ratio >= 0 then
            return pa_alert_item(it, "Stronger weapon", EMOJI.STRONGER)
          end
        elseif not util.contains(INV_WEAP.weap_egos, it.ego()) then
          if dps_delta_ratio >= -0.2 then
            return pa_alert_item(it, "New ego", EMOJI.EGO)
          end
        end
      else
        -- Not branded
        -- Allowing lower-trained skills triggers too often after picking up an untrained weapon
        -- Only use it to trigger upgrades from a low-value branded weapon to unbranded
        if cur.branded and cur.weap_skill == it.weap_skill then
          if get_weap_dps(it, true) > get_weap_dps(cur, true) then
            return pa_alert_item(it, "Stronger weapon", EMOJI.STRONGER)
          end
        else
          local inv = INV_WEAP.get_best(it)
          local best = cur.dps > inv.dps and cur or inv
          local dps_delta = get_weap_dps(it) - best.dps

          if dps_delta > 0 then
            return pa_alert_item(it, "Stronger weapon", EMOJI.STRONGER)
          elseif dps_delta == 0 and it.accuracy + (it.plus or 0) > best.acc then
            return pa_alert_item(it, "Higher accuracy", EMOJI.ACCURACY)
          end
        end
      end
    end
  end
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
  return pa_alert_item(it, category)
end

function pa_alert_weapon(it)
  if has_ego(it) and not it.is_identified then return false end

  if alert_first_ranged(it) then return true end
  if alert_first_polearm(it) then return true end
  if alert_early_weapons(it) then return true end
  if alert_interesting_weapons(it) then return true end

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
  }
  for _, key in ipairs(keys) do
    INV_WEAP.max_dps[key] = { dps = 0, acc = 0 }
  end
end


-------- Hooks --------
function ready_pa_weapons()
  init_pa_weapons()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_weapon(inv) and not is_staff(inv) then
      INV_WEAP.add_weapon(inv)
      update_high_scores(inv)
    end
  end
end
