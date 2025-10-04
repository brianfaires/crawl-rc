--[[
Feature: pickup-alert-misc
Description: Miscellaneous item pickup logic and alert system for the pickup-alert system
Author: buehler
Dependencies: core/config.lua, core/constants.lua, core/util.lua, pa-data.lua, pa-main.lua
--]]

f_pa_misc = {}

-- Local config
local Config = f_pickup_alert.Config
local Emoji = f_pickup_alert.Config.Emoji

function f_pa_misc.alert_orb(it)
  return f_pickup_alert.do_alert(it, "New orb", Emoji.ORB, Config.fm_alert.orbs)
end

function f_pa_misc.alert_OTA(it)
  local ota_item = f_pa_data.find(pa_OTA_items, it)
  if not ota_item then return end

  local do_alert = true

  if BRC.is.shield(it) then
    if you.skill("Shields") < Config.alert.OTA_require_skill.shield then return end

    -- Don't alert if already wearing a larger shield
    if ota_item == "buckler" then
      if BRC.you.have_shield() then do_alert = false end
    elseif ota_item == "kite shield" then
      local sh = items.equipped_at("offhand")
      if sh and sh.name("qual") == "tower shield" then do_alert = false end
    end
  elseif BRC.is.armour(it) then
    if you.skill("Armour") < Config.alert.OTA_require_skill.armour then return end
  elseif it.is_weapon then
    if you.skill(it.weap_skill) < Config.alert.OTA_require_skill.weapon then return end
  end

  f_pa_data.remove(pa_OTA_items, it)
  if not do_alert then return false end
  return f_pickup_alert.do_alert(it, "Found first", Emoji.RARE_ITEM, Config.fm_alert.one_time_alerts)
end

function f_pa_misc.alert_staff(it)
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
  return f_pickup_alert.do_alert(it, "Staff resistance", Emoji.STAFF_RESISTANCE, Config.fm_alert.staff_resists)
end

function f_pa_misc.alert_talisman(it)
  if it.artefact then
    return f_pickup_alert.do_alert(it, "Artefact talisman", Emoji.TALISMAN, Config.fm_alert.talismans)
  end
  local required_skill = BRC.get.talisman_min_level(it) - Config.alert.talisman_lvl_diff
  if required_skill > BRC.you.shapeshifting_skill() then return false end
  return f_pickup_alert.do_alert(it, "New talisman", Emoji.TALISMAN, Config.fm_alert.talismans)
end

function f_pa_misc.is_unneeded_ring(it)
  if not BRC.is.ring(it) or it.artefact or you.race() == "Octopode" then return false end
  local missing_hand = BRC.get.mut(BRC.MUTATIONS.missing_hand, true)
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

function f_pa_misc.pickup_staff(it)
  return BRC.get.skill(BRC.get.staff_school(it)) > 0
end
