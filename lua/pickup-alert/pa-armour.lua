---- Pickup and Alert features for armour ----
ARMOUR_ALERT = {
  artefact = { msg = "Artefact armour", emoji = EMOJI.ARTEFACT },
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
  } -- ARMOUR_ALERT.heavier (do not remove this comment)
} -- ARMOUR_ALERT (do not remove this comment)

local function send_armour_alert(it, alert_type)
  return pa_alert_item(it, alert_type.msg, alert_type.emoji, CONFIG.fm_alert.body_armour)
end

-- If training armour in early/mid game, alert user to any armour that is the strongest found so far
local function alert_ac_high_score(it)
  if not is_body_armour(it) then return false end
  if CACHE.s_armour == 0 then return false end
  if CACHE.xl > 12 then return false end

  if ac_high_score == 0 then
    local worn = items.equipped_at("armour")
    if not worn then return false end
    ac_high_score = get_armour_ac(worn)
  else
    local itAC = get_armour_ac(it)
    if itAC > ac_high_score then
      ac_high_score = itAC
      return pa_alert_item(it, "Highest AC", EMOJI.STRONGEST, CONFIG.fm_alert.high_score_armour)
    end
  end

  return false
end


-- Alerts armour items that didn't autopickup, but are worth consideration
-- The function assumes pickup occurred; so it doesn't alert things like pure upgrades
-- Takes `unworn_inv_item`, which is an unworn aux armour item in inventory
function pa_alert_armour(it, unworn_inv_item)
  if is_body_armour(it) then
    if it.artefact then
      return it.is_identified and send_armour_alert(it, ARMOUR_ALERT.artefact)
    end
  
    local cur = items.equipped_at("armour")
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
      if (ac_delta > 0) or (ev_delta / -ac_delta > TUNING.armour.lighter[ego_change_type]) then
        if ego_change_type == "lost_ego" and ev_delta < TUNING.armour.lighter.min_gain then return false end
        if ego_change_type ~= "same_ego" and -ac_delta > TUNING.armour.lighter.max_loss then return false end
        return send_armour_alert(it, ARMOUR_ALERT.lighter[ego_change_type])
      end
    else -- Heavier armour
      local encumb_impact = math.min(1, (CACHE.s_spellcasting + CACHE.s_ranged) / CACHE.xl)
      local total_loss = TUNING.armour.encumb_penalty_weight * encumb_impact * encumb_delta - ev_delta
      if (total_loss < 0) or (ac_delta / total_loss > TUNING.armour.heavier[ego_change_type]) then
        if ego_change_type == "lost_ego" and ac_delta < TUNING.armour.heavier.min_gain then return false end
        if ego_change_type ~= "same_ego" and total_loss > TUNING.armour.heavier.max_loss then return false end
        return send_armour_alert(it, ARMOUR_ALERT.heavier[ego_change_type])
      end
    end

    if alert_ac_high_score(it) then return true end
  elseif is_shield(it) then
    if it.artefact then
      return it.is_identified and pa_alert_item(it, "Artefact shield", EMOJI.ARTEFACT, CONFIG.fm_alert.shields)
    end
  
    local sh = items.equipped_at("offhand")
    if not is_shield(sh) then return false end
    if has_ego(it) and get_ego(it) ~= get_ego(sh) then
      local alert_msg = has_ego(sh) and "Diff ego" or "Gain ego"
      return pa_alert_item(it, alert_msg, EMOJI.EGO, CONFIG.fm_alert.shields)
    elseif get_shield_sh(it) > get_shield_sh(sh) then
      return pa_alert_item(it, "Increased SH", EMOJI.STRONGER, CONFIG.fm_alert.shields)
    end
  else
    -- Aux armour
    if it.artefact then
      return it.is_identified and pa_alert_item(it, "Artefact aux armour", EMOJI.ARTEFACT, CONFIG.fm_alert.aux_armour)
    end
  
    local cur = items.equipped_at(it.subtype()) or unworn_inv_item
    if not cur then return pa_alert_item(it, "Open slot", EMOJI.CAUTION, CONFIG.fm_alert.aux_armour) end
    if has_ego(it) and get_ego(it) ~= get_ego(cur) then
      local alert_msg = has_ego(cur) and "Diff ego" or "Gain ego"
      return pa_alert_item(it, alert_msg, EMOJI.EGO, CONFIG.fm_alert.aux_armour)
    elseif get_armour_ac(it) > get_armour_ac(cur) then
      return pa_alert_item(it, "Increased AC", EMOJI.STRONGER, CONFIG.fm_alert.aux_armour)
    end
  end
end

-- Equipment autopickup (by Medar, gammafunk, buehler, and various others)
function pa_pickup_armour(it)
  if has_risky_ego(it) then return false end

  if is_body_armour(it) then
    -- Pick up AC upgrades, new egos that don't lose AC, and artefacts that don't lose 5+ AC
    local cur = items.equipped_at("armour")
    if not cur then return false end
    if it.encumbrance > cur.encumbrance then return false end

    local ac_delta = get_armour_ac(it) - get_armour_ac(cur)

    if cur.artefact then return false end
    if it.artefact then return ac_delta > -5 end

    if get_ego(it) == get_ego(cur) then
      return ac_delta > 0 or ac_delta == 0 and it.encumbrance < cur.encumbrance 
    elseif has_ego(it) and not has_ego(cur) then
      return ac_delta >= 0
    end
  elseif is_shield(it) then
    -- Pick up SH upgrades, artefacts, and added egos
    local cur = items.equipped_at("offhand")
    if not is_shield(cur) then return false end
    if cur.encumbrance ~= it.encumbrance then return false end

    if cur.artefact then return false end
    if it.artefact then return true end
    if has_ego(cur) then
      return get_ego(cur) == get_ego(it) and it.plus > cur.plus
    end
    return has_ego(it) or it.plus > cur.plus
  else
    -- Aux armour: Pickup artefacts, AC upgrades, and new egos
    if is_orb(it) then return false end
    local st = it.subtype()

    -- Skip boots/gloves/helmet if wearing Lear's hauberk
    local worn = items.equipped_at("armour")
    if worn and worn.name("qual") == "Lear's hauberk" and st ~= "cloak" then return false end

    -- No autopickup if mutation interference
    if st == "gloves" then
      -- Ignore demonic touch if you're using offhand
      if get_mut(MUTS.demonic_touch, true) >= 3 and not offhand_is_free() then return false end
      -- Ignore claws if you're wielding a weapon
      if get_mut(MUTS.claws, true) > 0 and not have_weapon() then return false end
    elseif st == "boots" then
      if get_mut(MUTS.hooves, true) + get_mut(MUTS.talons, true) > 0 then return false end
    elseif it.name("base"):find("helmet", 1, true) then
      if get_mut(MUTS.horns, true) + get_mut(MUTS.beak, true) + get_mut(MUTS.antennae, true) > 0 then return false end
    end

    local cur = items.equipped_at(st)
    if not cur then
      -- Check if we're carrying one already; implying we have a temporary form
      for inv in iter.invent_iterator:new(items.inventory()) do
        if inv.subtype() == st then return false end
      end
      return true
    end
    if not it.is_identified then return false end

    if cur.artefact then return false end
    if it.artefact then return true end
    if has_ego(cur) then
      return get_ego(cur) == get_ego(it) and it.plus > cur.plus
    elseif has_ego(it) then
      return get_armour_ac(it) >= get_armour_ac(cur)
    else
      return get_armour_ac(it) > get_armour_ac(cur)
    end
  end

  return false
end
