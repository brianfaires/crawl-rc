if loaded_pa_weapons then return end
loaded_pa_weapons = true
loadfile("crawl-rc/lua/util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-data.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-main.lua")

---- Begin inv arrays ----
-- Use these arrays to compare potential upgrades against entire inventory
-- But only update these arrays once per turn, in ready()

local inv_weap_data = {}
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

  --weap_data.it = it
  return weap_data
end

-- High scores for melee/ranged, 1/2-handed, branded/unbranded
-- (Don't put these closing curly braces on a line by themself)
local top_school = "unarmed combat"
local egos = { }

local inv_max_dmg = {
  melee_1 = 0, melee_1b = 0, melee_2 = 0, melee_2b = 0,
  ranged_1 = 0, ranged_1b = 0, ranged_2 = 0, ranged_2b = 0, melee_only = 0
} -- inv_max_dmg (do not remove this comment)

local inv_max_dmg_acc = {
  melee_1 = 0, melee_1b = 0, melee_2 = 0, melee_2b = 0,
  ranged_1 = 0, ranged_1b = 0, ranged_2 = 0, ranged_2b = 0, melee_only = 0
} -- inv_max_dmg_acc (do not remove this comment)


local function set_top_school()
  local max = 0

  for _,v in ipairs(all_weap_schools) do
    if get_skill(v) > max then
      max = get_skill(v)
      top_school = v
    end
  end
end

local function get_weap_tag(it)
  local ret_val = if_el(it.is_ranged, "ranged_", "melee_")
  ret_val = ret_val .. get_hands(it)
  if has_ego(it) then ret_val = ret_val .. "b" end
  return ret_val
end

local function enforce_dmg_floor(target, floor)
  if inv_max_dmg[target] < inv_max_dmg[floor] then
    inv_max_dmg[target] = inv_max_dmg[floor]
    inv_max_dmg_acc[target] = inv_max_dmg_acc[floor]
  end
end

function generate_inv_weap_arrays()
  inv_weap_data = {}
  for k, _ in pairs(inv_max_dmg) do
    inv_max_dmg[k] = 0
    inv_max_dmg_acc[k] = 0
  end

  set_top_school()

  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_weapon(inv) and not is_staff(inv) then
      update_high_scores(inv)
      inv_weap_data[#inv_weap_data + 1] = make_weapon_struct(inv)
      if has_ego(inv) then table.insert(egos, get_ego(inv)) end

      local dmg = inv_weap_data[#inv_weap_data].dps
      local weap_type = get_weap_tag(inv)
      if dmg > inv_max_dmg[weap_type] then
        inv_max_dmg[weap_type] = dmg
        local inv_plus = inv.plus
        if not inv_plus then inv_plus = 0 end
        inv_max_dmg_acc[weap_type] = inv.accuracy + inv_plus

    -- Keep a separate count for all melee weapons
    if weap_type:find("melee") then
      inv_max_dmg["melee_only"] = dmg
      inv_max_dmg_acc["melee_only"] = inv.accuracy + inv_plus
    end
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


-- Alert strong weapons early
local function alert_early_weapons(it)
  -- Alert really good usable ranged weapons
  if CACHE.xl <= 14 then
    if it.is_identified and it.is_ranged then
      if has_ego(it) and it.plus >= 5 or it.plus >= 7 then
        if get_hands(it) == 1 or not have_shield() or you.skill("shield") <= 8 then
          return pa_alert_item(it, "Ranged weapon", CACHE.EMOJI.RANGED)
        end
      end
    end
  end

  -- Skip items when we're clearly going another route
  if get_skill(top_school) - get_skill(it.weap_skill) > 1.5*CACHE.xl+3 then return end


  if CACHE.xl < 8 then
    if has_ego(it) or it.plus and it.plus >= 4 then
      -- Make sure we don't alert a pure downgrade to something in inventory
      for _,inv in ipairs(inv_weap_data) do
        if inv.basename == it.name("base") then
          if inv.plus >= it.plus then
            if not has_ego(it) then return end
            if it.ego() == inv.ego then return end
          end
        end
      end

      return pa_alert_item(it, "Early weapon", CACHE.EMOJI.WEAPON)
    end
  end
end


local function alert_first_ranged(it)
  if not it.is_ranged then return false end

  if get_hands(it) == 2 then
    if have_shield() then return false end
    if alerted_first_ranged_two_handed == 0 then
      alerted_first_ranged_two_handed = 1
      for _,inv in ipairs(inv_weap_data) do
        if inv.is_ranged and inv.hands == 2 then return true end
      end
      return pa_alert_item(it, "Ranged weapon", CACHE.EMOJI.RANGED)
    end
  else
    if alerted_first_ranged_one_handed == 0 then
      alerted_first_ranged_one_handed = 1
      for _,inv in ipairs(inv_weap_data) do
        if inv.is_ranged then return true end
      end
      return pa_alert_item(it, "Ranged weapon", CACHE.EMOJI.RANGED)
    end
  end

  return false
end


---- pickup_weapons util ----
local function no_upgrade_possible(it, inv)
  if get_hands(it) > inv.hands then return true end
  if it.is_ranged ~= inv.is_ranged then return true end
  if inv.weap_skill == "Polearms" and it.weap_skill ~= "Polearms" then return true end
  return false
end

local function get_dmg_delta(it, cur, penalty)
  if not penalty then penalty = 1 end

  local delta
  local dmg_inv = inv_max_dmg[get_weap_tag(it)]

  if cur.dps >= dmg_inv then
    delta = get_weap_dps(it) - cur.dps
  else
    delta = get_weap_dps(it) - dmg_inv
  end

  if delta > 0 then return delta * penalty end
  return delta / penalty
end

local function need_first_weapon(it)
  if inv_max_dmg["melee_2"] ~= 0 then
    if inv_max_dmg["melee_only"] == 0 then
    -- Carrying ranged weapons only
    return get_weap_dps(it) > inv_max_dmg["melee_2"]
  end
  -- Carrying a melee weapon
  return false
  end

  if you.skill("Unarmed Combat") > 0 then return false end
  if get_mut("claws", true) > 0 then return false end
  if get_mut("demonic touch", true) > 0 then return false end

  return true
end


local function pickup_weapon(it, cur)
  if cur.subtype == it.subtype() then
    -- Exact weapon type match
    if it.artefact then return true end
    if cur.artefact then return false end
    if has_ego(it) and it.is_identified and not cur.branded then
      return get_weap_dps(it) > 0.85*cur.dps
    end
    if cur.branded and not has_ego(it) then return false end
    return it.ego() == cur.ego and get_weap_dps(it) > cur.dps + 0.001
  --elseif get_skill(it.weap_skill) >= 0.5 * get_skill(cur.weap_skill) then
  elseif it.weap_skill == cur.weap_skill or CACHE.race == "Gnoll" then
    if no_upgrade_possible(it, cur) then return false end

    if it.artefact then return true end
    if cur.artefact then return false end
    if it.branded and not it.is_identified then return false end
    --if cur.branded and not it.branded then return false end

    if it.is_ranged then return get_weap_dps(it) > cur.dps + 0.001 end

    local it_plus = if_el(it.plus, it.plus, 0)
    local it_score = get_weap_dps(it) + (it.accuracy + it_plus)/3
    local cur_score = cur.dps + cur.acc/3

    return it_score > 1.1*cur_score
  end

  return false
end


function do_pa_weapon_pickup(it)
  if it.is_useless then return false end
  for _,cur in ipairs(inv_weap_data) do
    if pickup_weapon(it, cur) then return true end
  end

  return need_first_weapon(it)
end


local function alert_interesting_weapon(it, cur)
  if it.artefact and it.is_identified then
    return pa_alert_item(it, "Artefact weapon", CACHE.EMOJI.ARTEFACT)
  end

  if cur.subtype == it.subtype() then
    -- Exact weapon type match
    if not cur.artefact and has_ego(it) and it.ego() ~= cur.ego then
      return pa_alert_item(it, "New ego", CACHE.EMOJI.EGO)
    end
    if get_weap_dps(it) > inv_max_dmg[get_weap_tag(it)] then
      return pa_alert_item(it, "Stronger weapon", CACHE.EMOJI.STRONGER)
    end
  elseif get_skill(it.weap_skill) >= 0.5 * get_skill(cur.weap_skill) then
    -- A usable weapon school
    if it.is_ranged ~= cur.is_ranged then return false end

    --local penalty = 1
    --if it.weap_skill == top_school then penalty = 0.5 end
    local penalty = (get_skill(it.weap_skill)+8) / (get_skill(top_school)+8)

    if get_hands(it) == 2 and cur.hands == 1 then
      -- Item requires an extra hand
      if has_ego(it) and not cur.branded then
        if get_weap_dps(it) > 0.8*cur.dps then
          return pa_alert_item(it, "2-handed weapon", CACHE.EMOJI.TWO_HANDED)
        end
      end

      if not have_shield() then
        if has_ego(it) and not (it.ego() == "heavy" or it.ego() == "speed") and
          not util.contains(egos, it.ego()) then
            return pa_alert_item(it, "New ego", CACHE.EMOJI.EGO)
        end
        if not cur.branded and
          get_weap_dps(it) > inv_max_dmg[get_weap_tag(it)] then
            return pa_alert_item(it, "2-handed weapon", CACHE.EMOJI.TWO_HANDED)
        end
        if cur.branded and not has_ego(it) and
          get_weap_dps(it) > inv_max_dmg[get_weap_tag(it)] then
            return pa_alert_item(it, "2-handed weapon", CACHE.EMOJI.TWO_HANDED)
        end
      elseif CACHE.s_shields <= 4 then
        -- Not really training shields; may be interested in big upgrades
        if penalty*get_weap_dps(it) >= inv_max_dmg["melee_2"] then
          return pa_alert_item(it, "2-handed weapon", CACHE.EMOJI.TWO_HANDED)
        end
      end
    else
      -- Item uses same number of hands or fewer
      if cur.artefact then return false end
      if has_ego(it) and not (it.ego() == "heavy" or it.ego() == "speed") then
        local dmg_delta = get_dmg_delta(it, cur, penalty)
        local dmg_delta_ratio = dmg_delta / get_weap_dps(it)

        if not cur.branded then
          if dmg_delta_ratio >= -0.2 then
            return pa_alert_item(it, "New ego", CACHE.EMOJI.EGO)
          end
        elseif it.ego() == cur.ego then
          if dmg_delta_ratio >= 0 then
            return pa_alert_item(it, "Stronger weapon", CACHE.EMOJI.STRONGER)
          end
        elseif not util.contains(egos, it.ego()) then
          if dmg_delta_ratio >= -0.2 then
            return pa_alert_item(it, "New ego", CACHE.EMOJI.EGO)
          end
        end
      else
        -- Not branded
        -- Allowing lower-trained skills triggers too often after picking up an untrained weapon
        -- Only use it to trigger upgrades from a low-value branded weapon to unbranded
        if cur.branded and cur.weap_skill == it.weap_skill then
          if get_weap_dps(it, true) > get_weap_dps(it, true) then
            return pa_alert_item(it, "Stronger weapon", CACHE.EMOJI.STRONGER)
          end
        else
          local dmg_delta, other_acc
          if cur.dps > inv_max_dmg[get_weap_tag(it)] then
            dmg_delta = get_weap_dps(it) - cur.dps
            other_acc = cur.acc
          else
            dmg_delta = get_weap_dps(it) - inv_max_dmg[get_weap_tag(it)]
            other_acc = inv_max_dmg_acc[get_weap_tag(it)]
          end

          if dmg_delta > 0 then
            return pa_alert_item(it, "Stronger weapon", CACHE.EMOJI.STRONGER)
          end
          local it_plus = if_el(it.plus, it.plus, 0)
          if dmg_delta == 0 and (it.accuracy+it_plus) > other_acc then
            return pa_alert_item(it, "Higher accuracy", CACHE.EMOJI.ACCURACY)
          end
        end
      end
    end
  end
end

local function alert_interesting_weapons(it)
  local ranged_weap_in_inv = false
  for _,cur in ipairs(inv_weap_data) do
    if alert_interesting_weapon(it, cur) then return true end
    if cur.is_ranged then ranged_weap_in_inv = true end
  end

  -- Alert for the first ranged weapon found (for 1 and 2 handed separately)
  if it.is_ranged and not ranged_weap_in_inv then
    if it.artefact or has_ego(it) and it.plus >= 4 then
      if get_hands(it) == 1 or not have_shield() then
        return pa_alert_item(it, "Ranged Weapon", CACHE.EMOJI.RANGED)
      end
    end
  end

  return false
end

local function alert_weap_high_scores(it)
  local category = update_high_scores(it)
  if category then pa_alert_item(it, category) end
end

function do_pa_weapon_alerts(it)
  if it.is_useless then return end
  if (it.artefact or has_ego(it)) and not it.is_identified then return end

  alert_first_ranged(it)
  alert_early_weapons(it)
  alert_interesting_weapons(it)

  -- Skip high score alerts if not using weapons
  if inv_max_dmg["melee_2"] > 0 then alert_weap_high_scores(it) end
end
