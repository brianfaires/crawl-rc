--[[
Feature: pickup-alert-misc
Description: Miscellaneous item pickup logic and alert system for the pickup-alert system
Author: buehler
Dependencies: CONFIG, COLORS, EMOJI, util, iter
--]]

f_pickup_alert_misc = {}
--f_pickup_alert_misc.BRC_FEATURE_NAME = "pickup-alert-misc"

function pa_alert_orb(it)
  if not it.is_identified then return false end
  return pa_alert_item(it, "New orb", EMOJI.ORB, CONFIG.fm_alert.orbs)
end

function pa_alert_OTA(it)
  local index = get_OTA_index(it)
  if index == -1 then return end

  local do_alert = true

  if is_shield(it) then
    if you.skill("Shields") < CONFIG.alert.OTA_require_skill.shield then return end

    -- Don't alert if already wearing a larger shield
    if pa_OTA_items[index] == "buckler" then
      if have_shield() then do_alert = false end
    elseif pa_OTA_items[index] == "kite shield" then
      local sh = items.equipped_at("offhand")
      if sh and sh.name("qual") == "tower shield" then do_alert = false end
    end
  elseif is_armour(it) then
    if you.skill("Armour") < CONFIG.alert.OTA_require_skill.armour then return end
  elseif it.is_weapon then
    if you.skill(it.weap_skill) < CONFIG.alert.OTA_require_skill.weapon then return end
  end

  remove_from_OTA(it)
  if not do_alert then return false end
  return pa_alert_item(it, "Rare item", EMOJI.RARE_ITEM, CONFIG.fm_alert.one_time_alerts)
end

---- Alert for needed resists ----
function pa_alert_staff(it)
  if not it.is_identified then return false end
  local needRes = false
  local basename = it.name("base")

  if basename == "staff of fire" then
    needRes = you.res_fire() == 0
  elseif basename == "staff of cold" then
    needRes = you.res_cold() == 0
  elseif basename == "staff of air" then
    needRes = you.res_shock() == 0
  elseif basename == "staff of poison" then
    needRes = you.res_poison() == 0
  elseif basename == "staff of death" then
    needRes = you.res_draining() == 0
  end

  if not needRes then return false end
  return pa_alert_item(it, "Staff resistance", EMOJI.STAFF_RESISTANCE, CONFIG.fm_alert.staff_resists)
end

function pa_alert_talisman(it)
  if it.artefact then
    if not it.is_identified then return false end
    return pa_alert_item(it, "Artefact talisman", EMOJI.TALISMAN, CONFIG.fm_alert.talismans)
  end
  if get_talisman_min_level(it) > you.skill("Shapeshifting") + CONFIG.alert.talisman_lvl_diff then return false end
  return pa_alert_item(it, "New talisman", EMOJI.TALISMAN, CONFIG.fm_alert.talismans)
end

---- Smart staff pickup ----
function pa_pickup_staff(it)
  if not it.is_identified then return false end
  if get_skill(get_staff_school(it)) == 0 then return false end
  return not already_contains(pa_items_picked, it)
end

---- Exclude superfluous rings ----
function is_unneeded_ring(it)
  if not is_ring(it) or it.artefact or you.race() == "Octopode" then return false end
  local missing_hand = get_mut(MUTS.missing_hand, true)
  local st = it.subtype()
  local found_first = false
  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_ring(inv) and inv.subtype() == st then
      if found_first or missing_hand then return true end
      found_first = true
    end
  end
  return false
end
