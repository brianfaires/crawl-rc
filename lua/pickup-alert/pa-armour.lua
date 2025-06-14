if loaded_pa_armour then return end
loaded_pa_armour = true
loadfile("crawl-rc/lua/globals.lua")
loadfile("crawl-rc/lua/util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-data.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-main.lua")


-- If training armour in early/mid game, alert user to any armour that is the strongest found so far
local function alert_armour_upgrades(it)
  if not is_body_armour(it) then return false end
  if CACHE.s_armour == 0 then return false end
  if CACHE.xl > 12 then return false end
  if (it.artefact or it.branded) and not it.is_identified then return false end

  if armour_high_score == 0 then
    local cur = get_body_armour()
    if not cur then return false end
    armour_high_score = get_armour_ac(cur)
  else
    local itAC = get_armour_ac(it)
    if itAC > armour_high_score then
      armour_high_score = itAC
      return pa_alert_item(it, "Strongest armour yet", GLOBALS.EMOJI.STRONGEST)
    end
  end

  return false
end


-- Equipment autopickup (by Medar, gammafunk, buehler, and various others)
function pa_pickup_armour(it)
  if it.is_useless then return false end

  if is_body_armour(it) then
    local cur = get_body_armour()

    -- Exclusions
    if not cur then return false end
    if it.branded and not it.is_identified then return false end
    if it.encumbrance > cur.encumbrance then return false end

    -- Pick up AC upgrades, new egos that don't lose AC, and artefacts that don't lose 5+ AC
    local ac_delta = get_armour_ac(it) - get_armour_ac(cur)

    if it.artefact and ac_delta > -5 then return true end
    if cur.artefact then return false end

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
      if get_ego(cur) == get_ego(it) then return it.plus > cur.plus end
      return false
    end
    if it.branded then return true end
    return it.plus > cur.plus
  else
    if is_orb(it) then return false end
    -- Aux armour: Pickup artefacts, AC upgrades, and new egos
    local st, _ = it.subtype()

    -- Skip boots/gloves/helmet if wearing Lear's hauberk
    local body_arm = get_body_armour()
    if body_arm and body_arm.name("qual"):find("Lear's hauberk") and st ~= "cloak" then return false end

    -- No autopickup if mutation interference
    if st == "gloves" then
      -- Ignore demonic touch if you're wearing a shield
      if not items.equipped_at("shield") then
        if get_mut("demonic touch", true) >= 3 then return false end
      end

      -- Ignore claws if you're wielding a weapon
      if not items.equipped_at("weapon") then
        if get_mut("claws", true) > 0 then return false end
      end
    elseif st == "boots" then
      if get_mut("hooves", true) > 0 then return false end
      if get_mut("talons", true) > 0 then return false end
    elseif it.name("base"):find("helmet") then
      if get_mut("horns", true) > 0 then return false end
      if get_mut("beak", true) > 0 then return false end
      if get_mut("antennae", true) > 0 then return false end
    end

    if it.artefact then return true end

    local cur = items.equipped_at(st)
    if not cur then return true end
    if not it.is_identified then return false end

    if it.branded then
      if get_ego(it) ~= get_ego(cur) then return true end
      if get_armour_ac(it) > get_armour_ac(cur) then return true end
    else
      if cur.branded or cur.artefact then return false end
      if get_armour_ac(it) > get_armour_ac(cur) then return true end
    end
  end

  return false
end


---- alert_armour_while_mutated() ----
-- Special cases where you have temporary or innate mutations that interfere with armour
-- Alert when an ego item is usable but interferes with mutation, or unusable due to temp mutations
local function alert_armour_while_mutated(it, type)
  local it_plus = it.plus and it.plus or 0

  if type == "gloves" then
    local claws_lvl_innate = get_mut("claws", false)
    if claws_lvl_innate >= 3 then return false end

    local touch_lvl_innate = get_mut("demonic touch", false)
    if touch_lvl_innate >= 3 then return false end

    local claws_lvl = get_mut("claws", true)
    local touch_lvl = get_mut("demonic touch", true)

    if claws_lvl > 0 or touch_lvl >= 3 then
      if it.artefact or it.branded then
        return pa_alert_item(it, "Branded gloves", GLOBALS.EMOJI.GLOVES)
      end
      local cur_gloves = items.equipped_at("gloves")
      if not cur_gloves or it_plus > cur_gloves.plus then
        return pa_alert_item(it, "Enchanted gloves", GLOBALS.EMOJI.GLOVES)
      end
    end
  elseif type == "boots" then
    local hooves_lvl_innate = get_mut("hooves", false)
    if hooves_lvl_innate >= 3 then return false end

    local talons_lvl_innate = get_mut("talons", false)
    if talons_lvl_innate >= 3 then return false end

    local hooves_lvl = get_mut("hooves", true)
    local talons_lvl = get_mut("talons", true)

    if hooves_lvl + talons_lvl > 0 then
      if it.artefact or it.branded then
        return pa_alert_item(it, "Branded boots", GLOBALS.EMOJI.BOOTS)
      end
      local cur_boots = items.equipped_at("boots")
      if not cur_boots or it_plus > cur_boots.plus then
        return pa_alert_item(it, "Enchanted boots", GLOBALS.EMOJI.BOOTS)
      end
    end
  elseif type == "helmet" then
    local horns_lvl_innate = get_mut("horns", false)
    local antennae_lvl_innate = get_mut("antennae", false)

    if it.name("base"):find("helmet") then
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
      if it.artefact or it.branded then
        return pa_alert_item(it, "Branded headgear", CONFIG.EMOJI.HAT)
      end
      local cur_helmet = items.equipped_at("helmet")
      if not cur_helmet or it_plus > cur_helmet.plus then
        return pa_alert_item(it, "Enchanted headgear", GLOBALS.EMOJI.HAT)
      end
    end
  end
end

---- alert_interesting_armour() ----
-- Alerts armour items that did trigger autopickup, but are worth consideration
-- Includes: Artefacts, added or changed egos, and
  -- body armour AC/EV/Encumbrance changes, defined by following heuristics:
    -- Lighter: EV/AC >= { 0.6, 0.8, 1.2, 2 } for ego: {gain, diff, same, lose}
      -- Or: Gain/Diff ego while losing <=4AC
    -- Heavier: AC/EV >= { 0.4, 0.7, 0.8, 2 } for ego: {gain, diff, same, lose}
      -- Penalty == 0.75*encumb_change (or 0 if irrelevant)
-- Adjusting the heuristic values up will mean fewer alerts, and down will alert more often.
-- If you want a specific alert to occur more or less often, look for the line of code below with the alert text,
-- Then modify the values in the same line of code.
local function alert_interesting_armour(it)
  if it.artefact then
    return pa_alert_item(it, "Artefact armour", GLOBALS.EMOJI.ARTEFACT)
  end

  if is_body_armour(it) then
    local cur = get_body_armour()
    if not cur then return false end

    if it.encumbrance == cur.encumbrance then
      if has_ego(it) then
        if not has_ego(cur) then
          return pa_alert_item(it, "Gain ego", GLOBALS.EMOJI.EGO)
        end
        if get_ego(it) ~= get_ego(cur) then
          return pa_alert_item(it, "Diff ego", GLOBALS.EMOJI.EGO)
        end
      end
      if get_armour_ac(it) > get_armour_ac(cur) + 0.1 then
        return pa_alert_item(it, "Stronger armour", GLOBALS.EMOJI.STRONGER)
      end

    elseif it.encumbrance < cur.encumbrance then
      -- Lighter armour
      local ev_gain = get_armour_ev(it) - get_armour_ev(cur)
      local ac_lost = get_armour_ac(cur) - get_armour_ac(it)

      if has_ego(it) then
        if not cur.artefact and not has_ego(cur) then
          if ev_gain/ac_lost >= 0.6 or ac_lost <= 4 then
            return pa_alert_item(it, "Gain ego (Lighter armour)", GLOBALS.EMOJI.EGO)
          end
        elseif get_ego(it) ~= get_ego(cur) then
          if ev_gain/ac_lost >= 0.8 or ac_lost <= 4 then
            return pa_alert_item(it, "Diff ego (Lighter armour)", GLOBALS.EMOJI.EGO)
          end
        else
          if ev_gain/ac_lost >= 1.2 then
            return pa_alert_item(it, "Lighter armour (Same ego)", GLOBALS.EMOJI.LIGHTER)
          end
        end
      else
        if has_ego(cur) then
          if ev_gain/ac_lost >= 2 and ev_gain >= 3 then
            return pa_alert_item(it, "Lighter armour (Lost ego)", GLOBALS.EMOJI.LIGHTER)
          end
        else
          -- Neither has ego
          if ev_gain/ac_lost >= 1.2 then
            return pa_alert_item(it, "Lighter armour", GLOBALS.EMOJI.LIGHTER)
          end
        end
      end
    else
      -- Heavier armour
      local ac_gain = get_armour_ac(it) - get_armour_ac(cur)
      local ev_lost = get_armour_ev(cur) - get_armour_ev(it)
      local encumb_penalty = 0
      if you.skill("Spellcasting") + you.skill("Ranged Weapons") > 1 then
        encumb_penalty = (it.encumbrance - cur.encumbrance)*0.75
      end
      local total_loss = ev_lost + encumb_penalty

      if has_ego(it) then
        if not cur.artefact and not has_ego(cur) then
          if ac_gain/total_loss >= 0.4 or total_loss <= 6 then
            return pa_alert_item(it, "Gain ego (Heavier armour)", GLOBALS.EMOJI.EGO)
          end
        elseif get_ego(it) ~= get_ego(cur) then
          if ac_gain/total_loss >= 0.7 or total_loss <= 6 then
            return pa_alert_item(it, "Diff ego (Heavier armour)", GLOBALS.EMOJI.EGO)
          end
        else
          if ac_gain/total_loss >= 0.8 then
            return pa_alert_item(it, "Heavier armour (Same ego)", GLOBALS.EMOJI.HEAVIER)
          end
        end
      else
        if cur.artefact or has_ego(cur) then
          if ac_gain/total_loss >= 2 and ac_gain >= 3 then
            return pa_alert_item(it, "Heavier armour (Lost ego)", GLOBALS.EMOJI.HEAVIER)
          end
        else
          -- Neither has ego
          if ac_gain/total_loss >= 0.8 then
            return pa_alert_item(it, "Heavier armour", GLOBALS.EMOJI.HEAVIER)
          end
        end
      end
    end
  elseif is_shield(it) then
    --if it.is_useless then return end
    local cur = items.equipped_at("shield")
    if not cur then return false end
    if it.branded and it.ego() ~= cur.ego() then
      return pa_alert_item(it, "New ego", GLOBALS.EMOJI.EGO)
    end
  else
    -- Aux armour
    local st, _ = it.subtype()
    local cur = items.equipped_at(st)
    if not cur then return false end
    if get_armour_ac(it) > get_armour_ac(cur) then
      return pa_alert_item(it, "Stronger armour", GLOBALS.EMOJI.STRONGER)
    else
      return alert_armour_while_mutated(it, st)
    end
  end
end

function pa_alert_armour(it)
  if it.is_useless then return false end
  if alert_armour_upgrades(it) then return true end
  if not it.is_identified or has_ego(it) then return false end
  return alert_interesting_armour(it)
end
