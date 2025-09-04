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
  return f_pickup_alert.do_alert(it, "New orb", BRC.Emoji.ORB, BRC.Config.fm_alert.orbs)
end

function pa_alert_OTA(it)
  local index = f_pa_data.get_OTA_index(it)
  if index == -1 then return end

  local do_alert = true

  if BRC.is.shield(it) then
    if you.skill("Shields") < BRC.Config.alert.OTA_require_skill.shield then return end

    -- Don't alert if already wearing a larger shield
    if pa_OTA_items[index] == "buckler" then
      if BRC.you.have_shield() then do_alert = false end
    elseif pa_OTA_items[index] == "kite shield" then
      local sh = items.equipped_at("offhand")
      if sh and sh.name("qual") == "tower shield" then do_alert = false end
    end
  elseif BRC.is.armour(it) then
    if you.skill("Armour") < BRC.Config.alert.OTA_require_skill.armour then return end
  elseif it.is_weapon then
    if you.skill(it.weap_skill) < BRC.Config.alert.OTA_require_skill.weapon then return end
  end

  f_pa_data.remove_from_OTA(it)
  if not do_alert then return false end
  return f_pickup_alert.do_alert(it, "Rare item", BRC.Emoji.RARE_ITEM, BRC.Config.fm_alert.one_time_alerts)
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
  return f_pickup_alert.do_alert(it, "Staff resistance", BRC.Emoji.STAFF_RESISTANCE, BRC.Config.fm_alert.staff_resists)
end

function pa_alert_talisman(it)
  if it.artefact then
    if not it.is_identified then return false end
    return f_pickup_alert.do_alert(it, "Artefact talisman", BRC.Emoji.TALISMAN, BRC.Config.fm_alert.talismans)
  end
  local required_skill = BRC.get.talisman_min_level(it) - BRC.Config.alert.talisman_lvl_diff
  if required_skill > you.skill("Shapeshifting") then return false end
  return f_pickup_alert.do_alert(it, "New talisman", BRC.Emoji.TALISMAN, BRC.Config.fm_alert.talismans)
end

---- Smart staff pickup ----
function pa_pickup_staff(it)
  if not it.is_identified then return false end
  if get_skill(BRC.get.staff_school(it)) == 0 then return false end
  return not f_pa_data.contains(pa_items_picked, it)
end

---- Exclude superfluous rings ----
function is_unneeded_ring(it)
  if not BRC.is.ring(it) or it.artefact or you.race() == "Octopode" then return false end
  local missing_hand = BRC.get.mut(MUTS.missing_hand, true)
  local st = it.subtype()
  local found_first = false
  for inv in iter.invent_iterator:new(items.inventory()) do
    if BRC.is.ring(inv) and inv.subtype() == st then
      if found_first or missing_hand then return true end
      found_first = true
    end
  end
  return false
end
