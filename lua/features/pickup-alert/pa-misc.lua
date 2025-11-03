---------------------------------------------------------------------------------------------------
-- BRC feature module: pickup-alert-misc
-- @submodule f_pa_misc
-- Miscellaneous item pickup and alert functions for the pickup-alert feature.
---------------------------------------------------------------------------------------------------

f_pa_misc = {}

---- Local variables ----
local Emoji
local Alert

---- Initialization ----
function f_pa_misc.init()
  Emoji = f_pickup_alert.Config.Emoji
  Alert = f_pickup_alert.Config.Alert
end

---- Local functions ----

---- Public API ----
function f_pa_misc.alert_orb(it)
  return f_pickup_alert.do_alert(it, "New orb", Emoji.ORB, Alert.More.orbs)
end

function f_pa_misc.alert_OTA(it)
  local ota_item = f_pa_data.find_OTA(it)
  if not ota_item then return end

  local do_alert = true

  if BRC.it.is_shield(it) then
    if you.skill("Shields") < Alert.OTA_require_skill.shield then return end

    -- Don't alert if already wearing a larger shield
    if ota_item == "buckler" then
      if BRC.you.have_shield() then do_alert = false end
    elseif ota_item == "kite shield" then
      local sh = items.equipped_at("offhand")
      if sh and sh.name("qual") == "tower shield" then do_alert = false end
    end
  elseif BRC.it.is_armour(it) then
    if you.skill("Armour") < Alert.OTA_require_skill.armour then return end
  elseif it.is_weapon then
    if you.skill(it.weap_skill) < Alert.OTA_require_skill.weapon then return end
  end

  f_pa_data.remove_OTA(it)
  if not do_alert then return false end
  return f_pickup_alert.do_alert(it, "Found first", Emoji.RARE_ITEM, Alert.More.one_time_alerts)
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
  return f_pickup_alert.do_alert(it, "Staff resistance", Emoji.STAFF_RES, Alert.More.staff_resists)
end

function f_pa_misc.alert_talisman(it)
  if not it.is_identified then return false end -- Necessary to avoid firing on '\' menu
  if it.artefact then
    return f_pickup_alert.do_alert(it, "Artefact talisman", Emoji.TALISMAN, Alert.More.talismans)
  end
  local required_skill = BRC.it.get_talisman_min_level(it) - Alert.talisman_lvl_diff
  if required_skill > BRC.you.shapeshifting_skill() then return false end
  return f_pickup_alert.do_alert(it, "New talisman", Emoji.TALISMAN, Alert.More.talismans)
end

function f_pa_misc.is_unneeded_ring(it)
  if not BRC.it.is_ring(it) or it.artefact or you.race() == "Octopode" then return false end
  local missing_hand = BRC.you.mut_lvl("missing a hand") > 0
  local st = it.subtype()
  local found_first = false
  for _, inv in ipairs(items.inventory()) do
    if BRC.it.is_ring(inv) and inv.subtype() == st then
      if found_first or missing_hand then return true end
      found_first = true
    end
  end
  return false
end

function f_pa_misc.pickup_staff(it)
  return BRC.you.skill(BRC.it.get_staff_school(it)) > 0
end
