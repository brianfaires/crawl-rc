---------------------------------------------------------------------------------------------------
-- BRC feature module: pickup-alert-misc
-- @submodule f_pa_misc
-- Miscellaneous item pickup and alert functions for the pickup-alert feature.
---------------------------------------------------------------------------------------------------

f_pa_misc = {}

---- Local variables ----
local E -- emoji config alias
local A -- alert config alias
local M -- more config alias

---- Initialization ----
function f_pa_misc.init()
  E = f_pickup_alert.Config.Emoji
  A = f_pickup_alert.Config.Alert
  M = f_pickup_alert.Config.Alert.More
end

---- Local functions ----

---- Public API ----
function f_pa_misc.alert_orb(it)
  return f_pickup_alert.do_alert(it, "New orb", E.ORB, M.orbs)
end

function f_pa_misc.alert_OTA(it)
  local ota_item = f_pa_data.find_OTA(it)
  if not ota_item then return end

  local do_alert = true

  if BRC.it.is_shield(it) then
    if you.skill("Shields") < A.OTA_require_skill.shield then return end

    -- Don't alert if already wearing a larger shield
    if ota_item == "buckler" then
      if BRC.you.have_shield() then do_alert = false end
    elseif ota_item == "kite shield" then
      local sh = items.equipped_at("offhand")
      if sh and sh.name("qual") == "tower shield" then do_alert = false end
    end
  elseif BRC.it.is_armour(it) then
    if you.skill("Armour") < A.OTA_require_skill.armour then return end
  elseif it.is_weapon then
    if you.skill(it.weap_skill) < A.OTA_require_skill.weapon then return end
  end

  f_pa_data.remove_OTA(it)
  if not do_alert then return false end
  if it.class(true) == "book" and not it.name():find(ota_item) then
    return f_pickup_alert.do_alert(it, "Found " .. ota_item, E.RARE_ITEM, M.one_time_alerts)
  end
  return f_pickup_alert.do_alert(it, "Found first", E.RARE_ITEM, M.one_time_alerts)
end

function f_pa_misc.alert_staff(it)
  local basename = it.name("base")
  local tag
  local tag_color

  if basename == "staff of air" then
    if you.res_shock() > 0 then return false end
    tag = "rElec"
    tag_color = BRC.COL.lightcyan
  elseif basename == "staff of chemistry" then
    if you.res_poison() > 0 then return false end
    tag = "rPois"
    tag_color = BRC.COL.lightgreen
  elseif basename == "staff of cold" then
    if you.res_cold() > 0 then return false end
    tag = "rC+"
    tag_color = BRC.COL.lightblue
  elseif basename == "staff of fire" then
    if you.res_fire() > 0 then return false end
    tag = "rF+"
    tag_color = BRC.COL.lightred
  elseif basename == "staff of necromancy" then
    if you.res_draining() > 0 then return false end
    tag = "rN+"
    tag_color = BRC.COL.lightmagenta
  else
    return false
  end

  for _, inv in ipairs(items.inventory()) do
    if inv.is_weapon and inv.name("plain"):contains(tag) then
      return false
    end
  end

  tag = BRC.txt[tag_color]("(" .. tag .. ")")
  return f_pickup_alert.do_alert(it, "Staff resistance " .. tag, E.STAFF_RES, M.staff_resists)
end

function f_pa_misc.alert_talisman(it)
  if not it.is_identified then return false end -- Necessary to avoid firing on '\' menu
  if it.artefact then
    return f_pickup_alert.do_alert(it, "Artefact talisman", E.TALISMAN, M.talismans)
  end
  local required_skill = BRC.it.get_talisman_min_level(it) - A.talisman_lvl_diff
  if required_skill > BRC.you.shapeshifting_skill() then return false end
  return f_pickup_alert.do_alert(it, "New talisman", E.TALISMAN, M.talismans)
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
  if f_pa_data.already_alerted(it) then return false end
  if BRC.you.skill(BRC.it.get_staff_school(it)) == 0 then return false end

  local qualname = it.name("qual")
  local max_slots = BRC.you.num_eq_slots(it)
  local count = 0
  for _, inv in ipairs(items.inventory()) do
    if inv.name("qual") == qualname then
      count = count + 1
      if count >= max_slots then return false end
    end
  end

  return true
end
