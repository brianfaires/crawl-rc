---- Pickup and Alert features for armour ----
ARMOUR_ALERT = {
  artefact = { msg = "Artefact armour", emoji = EMOJI.ARTEFACT },
  stronger = { msg = "Stronger armour", emoji = EMOJI.STRONGER },
  lighter = { msg = "Lighter armour", emoji = EMOJI.LIGHTER },
  gain_ego = { msg = "Gain ego", emoji = EMOJI.EGO },
  diff_ego = { msg = "Diff ego", emoji = EMOJI.EGO },

  lighter = {
    gain_ego = { msg = "Gain ego (Lighter armour)", emoji = EMOJI.EGO },
    diff_ego = { msg = "Diff ego (Lighter armour)", emoji = EMOJI.EGO },
    same_ego = { msg = "Lighter armour", emoji = EMOJI.LIGHTER },
    lost_ego = { msg = "Lighter armour (Lost ego)", emoji = EMOJI.LIGHTER }
  },
  heavier = {
    gain_ego = { msg = "Gain ego (Heavier armour)", emoji = EMOJI.EGO },
    diff_ego = { msg = "Diff ego (Heavier armour)", emoji = EMOJI.EGO },
    same_ego = { msg = "Heavier Armour", emoji = EMOJI.HEAVIER },
    lost_ego = { msg = "Heavier Armour (Lost ego)", emoji = EMOJI.HEAVIER }
  }
} -- ARMOUR_ALERT (do not remove this comment)

local function send_armour_alert(it, alert_type)
  return pa_alert_item(it, alert_type.msg, alert_type.emoji)
end

-- If training armour in early/mid game, alert user to any armour that is the strongest found so far
local function alert_ac_high_score(it)
  if not is_body_armour(it) then return false end
  if CACHE.s_armour == 0 then return false end
  if CACHE.xl > 12 then return false end
  if has_ego(it) and not it.is_identified then return false end

  if ac_high_score == 0 then
    local cur = get_body_armour()
    if not cur then return false end
    ac_high_score = get_armour_ac(cur)
  else
    local itAC = get_armour_ac(it)
    if itAC > ac_high_score then
      ac_high_score = itAC
      return pa_alert_item(it, "Strongest armour yet", EMOJI.STRONGEST)
    end
  end

  return false
end

-- Special cases where you have temporary or innate mutations that interfere with armour
-- Alert when an ego item is usable but interferes with mutation, or unusable due to temp mutations
local function alert_armour_consider_mutations(it, type)
  local it_plus = it.plus or 0

  if type == "gloves" then
    local claws_lvl_innate = get_mut("claws", false)
    if claws_lvl_innate >= 3 then return false end

    local touch_lvl_innate = get_mut("demonic touch", false)
    if touch_lvl_innate >= 3 then return false end

    local claws_lvl = get_mut("claws", true)
    local touch_lvl = get_mut("demonic touch", true)

    if claws_lvl > 0 or touch_lvl >= 3 then
      if has_ego(it) then
        return pa_alert_item(it, "Branded gloves", EMOJI.GLOVES)
      end
      local cur_gloves = items.equipped_at("gloves")
      if not cur_gloves or it_plus > cur_gloves.plus then
        return pa_alert_item(it, "Enchanted gloves", EMOJI.GLOVES)
      end
    end
  elseif type == "boots" then
    if get_mut("hooves", false) >= 3 then return false end
    if get_mut("talons", false) >= 3 then return false end

    if get_mut("hooves", true) + get_mut("talons", true) > 0 then
      if has_ego(it) then
        return pa_alert_item(it, "Branded boots", EMOJI.BOOTS)
      end
      local cur_boots = items.equipped_at("boots")
      if not cur_boots or it_plus > cur_boots.plus then
        return pa_alert_item(it, "Enchanted boots", EMOJI.BOOTS)
      end
    end
  elseif type == "helmet" then
    local horns_lvl_innate = get_mut("horns", false)
    local antennae_lvl_innate = get_mut("antennae", false)

    if it.name("qual"):find("helmet") then
      if horns_lvl_innate > 0 then return false end
      if antennae_lvl_innate > 0 then return false end
      if get_mut("beak", false) > 0 then return false end
    else
      -- hat/crown/etc
      if horns_lvl_innate >= 3 then return false end
      if antennae_lvl_innate >= 3 then return false end
    end

    local horns_lvl = get_mut("horns", true)
    local antennae_lvl = get_mut("antennae", true)
    local beak_lvl = get_mut("beak", true)
    if horns_lvl + antennae_lvl + beak_lvl > 0 then
      if has_ego(it) then
        return pa_alert_item(it, "Branded headgear", EMOJI.HAT)
      end
      local cur_helmet = items.equipped_at("helmet")
      if not cur_helmet or it_plus > cur_helmet.plus then
        return pa_alert_item(it, "Enchanted headgear", EMOJI.HAT)
      end
    end
  end
end

-- Alerts armour items that didn't autopickup, but are worth consideration
-- The function assumes pickup occurred; so it doesn't alert things like pure upgrades
function pa_alert_armour(it)
  if alert_ac_high_score(it) then return true end
  if it.artefact then
    return it.is_identified and pa_alert(it, ARMOUR_ALERT.artefact)
  end

  if is_body_armour(it) then
    local cur = get_body_armour()
    if not cur then return false end

    local encumb_delta = it.encumbrance - cur.encumbrance
    local ac_delta = get_armour_ac(it) - get_armour_ac(cur)
    local ev_delta = get_armour_ev(it) - get_armour_ev(cur)

    local it_ego = get_ego(it)
    local cur_ego = get_ego(cur)
    local ego_change_type
    if it_ego == cur_ego then ego_change_type = "same_ego"
    elseif not it_ego then ego_change_type = "lost_ego"
    elseif not cur_ego then ego_change_type = "gain_ego"
    else ego_change_type = "diff_ego"
    end

    if encumb_delta == 0 then
      if ego_change_type == "gain_ego" or ego_change_type == "diff_ego" then
        return send_armour_alert(it, ARMOUR_ALERT[ego_change_type])
      end
    elseif encumb_delta < 0 then
      if ev_delta / -ac_delta >= TUNING.armour.lighter[ego_change_type] then
        if ego_change_type == "lost_ego" and ev_delta < TUNING.armour.lighter.min_gain then return false end
        if ego_change_type ~= "same_ego" and -ac_delta > TUNING.armour.lighter.max_loss then return false end
        return send_armour_alert(it, ARMOUR_ALERT.lighter[ego_change_type])
      end
    else -- Heavier armour
      local encumb_impact = math.min(1, (CACHE.s_spellcasting + CACHE.s_ranged) / CACHE.xl)
      local total_loss = TUNING.armour.encumb_penalty_weight * encumb_impact * encumb_delta - ev_delta
      if ac_delta / total_loss >= TUNING.armour.heavier[ego_change_type] then
        if ego_change_type == "lost_ego" and ac_delta < TUNING.armour.lighter.min_gain then return false end
        if ego_change_type ~= "same_ego" and total_loss > TUNING.armour.lighter.max_loss then return false end
        return send_armour_alert(it, ARMOUR_ALERT.heavier[ego_change_type])
      end
    end
  elseif is_shield(it) then
    local cur = items.equipped_at("shield")
    if not cur then return false end
    if has_ego(it) and get_ego(it) ~= get_ego(cur) then
      return pa_alert_item(it, "New ego", EMOJI.EGO)
    end
  else
    -- Aux armour
    local st, _ = it.subtype()
    local cur = items.equipped_at(st)
    if not cur then return false end
    if get_armour_ac(it) > get_armour_ac(cur) + 0.001 then
      return pa_alert_item(it, "Stronger armour", EMOJI.STRONGER)
    else
      return alert_armour_consider_mutations(it, st)
    end
  end
end

-- Equipment autopickup (by Medar, gammafunk, buehler, and various others)
function pa_pickup_armour(it)
  if has_ego(it) and not it.is_identified then return false end

  if is_body_armour(it) then
    local cur = get_body_armour()

    -- Exclusions
    if not cur then return false end
    if it.encumbrance > cur.encumbrance then return false end

    -- Pick up AC upgrades, new egos that don't lose AC, and artefacts that don't lose 5+ AC
    local ac_delta = get_armour_ac(it) - get_armour_ac(cur)

    if cur.artefact then return false end
    if it.artefact and ac_delta > -5 then return true end

    if get_ego(it) == get_ego(cur) then
      return ac_delta > 0 or ac_delta == 0 and it.encumbrance < cur.encumbrance
    elseif has_ego(it) and not has_ego(cur) then
      return ac_delta >= 0
    end
  elseif is_shield(it) then
    local cur = items.equipped_at("offhand")

    -- Exclusions
    if not it.is_identified then return false end
    if not cur or not is_shield(cur) then return false end
    if cur.name("base") ~= it.name("base") then return false end

    -- Pick up SH upgrades, artefacts, and added egos
    if it.artefact then return true end
    if cur.artefact then return false end
    if cur.branded then
      return get_ego(cur) == get_ego(it) and it.plus > cur.plus
    end
    if it.branded then return true end
    return it.plus > cur.plus
  else
    if is_orb(it) then return false end
    -- Aux armour: Pickup artefacts, AC upgrades, and new egos
    local st, _ = it.subtype()

    -- Skip boots/gloves/helmet if wearing Lear's hauberk
    local body_arm = get_body_armour()
    if body_arm and body_arm.name("qual") == "Lear's hauberk" and st ~= "cloak" then return false end

    -- No autopickup if mutation interference
    if st == "gloves" then
      -- Ignore demonic touch if you're wearing a shield
      if not items.equipped_at("shield") and get_mut("demonic touch", true) >= 3 then return false end
      -- Ignore claws if you're wielding a weapon
      if not items.equipped_at("weapon") and get_mut("claws", true) > 0 then return false end
    elseif st == "boots" then
      if get_mut("hooves", true) + get_mut("talons", true) > 0 then return false end
    elseif it.name("base"):find("helmet") then
      if get_mut("horns", true) + get_mut("beak", true) + get_mut("antennae", true) > 0 then return false end
    end

    if it.artefact then return true end

    local cur = items.equipped_at(st)
    if not cur then return true end
    if not it.is_identified then return false end

    if it.branded then
      local it_ego = get_ego(it)
      if is_dangerous_brand(it_ego) then return false end
      if it_ego ~= get_ego(cur) then return true end
      if get_armour_ac(it) > get_armour_ac(cur) then return true end
    else
      if has_ego(cur) then return false end
      if get_armour_ac(it) > get_armour_ac(cur) then return true end
    end
  end

  return false
end
