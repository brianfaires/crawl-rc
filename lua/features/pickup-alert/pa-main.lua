--[[
Feature: pickup-alert
Description: Comprehensive pickup and alert system for weapons, armour, and miscellaneous items
Author: buehler
Dependencies: core/config.lua, core/constants.lua, core/data.lua, core/util.lua,
  pa-armour.lua, pa-config.lua, pa-data.lua, pa-misc.lua, pa-weapons.lua
--]]

f_pickup_alert = f_pickup_alert or {}
f_pickup_alert.BRC_FEATURE_NAME = "pickup-alert"

---- Local config alias ----
local Config = f_pickup_alert.Config

---- Local variables ----
local pause_pa_system
local hold_alerts_for_next_turn

---- Local functions ----
local function has_configured_force_more(it)
  if it.artefact then
    if Config.Alert.More.artefact then return true end
    if Config.Alert.More.trained_artefacts then
      -- Accept artefacts with any relevant training, or no training required
      local s = BRC.you.skill_with(it)
      if s == nil or s > 0 then return true end
    end
  end

  return Config.Alert.More.armour_ego and BRC.it.is_armour(it) and BRC.eq.get_ego(it)
end

local function track_unique_egos(it)
  local ego = BRC.eq.get_ego(it)
  if
    ego
    and not util.contains(pa_egos_alerted, ego)
    and not (it.artefact and BRC.eq.is_risky(it))
  then
    pa_egos_alerted[#pa_egos_alerted+1] = ego
  end
end

---- Public API ----
function f_pickup_alert.pause_alerts()
  hold_alerts_for_next_turn = true
end

function f_pickup_alert.do_alert(it, alert_type, emoji, force_more)
  local item_name = f_pa_data.get_keyname(it, true)
  local alert_col

  if it.is_weapon then
    f_pa_data.update_high_scores(it)
    alert_col = Config.AlertColor.weapon
    local weapon_info = string.format(" (%s)", BRC.eq.wpn_stats(it))
    item_name = item_name .. BRC.txt[Config.AlertColor.weapon.stats](weapon_info)
  elseif BRC.it.is_orb(it) then
    alert_col = Config.AlertColor.orb
  elseif BRC.it.is_talisman(it) then
    alert_col = Config.AlertColor.talisman
  elseif BRC.it.is_armour(it) then
    if BRC.it.is_body_armour(it) then
      f_pa_data.update_high_scores(it)
      alert_col = Config.AlertColor.body_arm
      local ac, ev = BRC.eq.arm_stats(it)
      local armour_info = string.format(" {%s, %s}", ac, ev)
      item_name = item_name .. BRC.txt[Config.AlertColor.body_arm.stats](armour_info)
    else
      alert_col = Config.AlertColor.aux_arm
    end

    track_unique_egos(it)
  else
    alert_col = Config.AlertColor.misc
  end

  local tokens = {}
  tokens[1] = emoji and emoji or BRC.txt.cyan("----")
  tokens[#tokens + 1] = BRC.txt[alert_col.desc](string.format(" %s:", alert_type))
  tokens[#tokens + 1] = BRC.txt[alert_col.item](string.format(" %s ", item_name))
  tokens[#tokens + 1] = tokens[1]
  BRC.mpr.que_optmore(force_more or has_configured_force_more(it), table.concat(tokens))

  f_pa_data.add_recent_alert(it)
  f_pa_data.remember_alert(it)

  if not hold_alerts_for_next_turn then you.stop_activity() end

  -- Set hotkeys
  if util.exists(you.floor_items(), function(fl) return fl.name() == it.name() end) then
    if Config.Alert.hotkey_pickup then BRC.Hotkey.pickup(it.name(), true) end
  else
    if Config.Alert.hotkey_travel then BRC.Hotkey.waypoint(it.name()) end
  end

  return true
end

---- Hook functions ----
function f_pickup_alert.init()
  pause_pa_system = false
  hold_alerts_for_next_turn = false

  BRC.mpr.debug("Initialize pickup-alert submodules...")
  if f_pa_data.init then f_pa_data.init() end
  BRC.mpr.debug("  pa-data loaded")

  if f_pa_armour then
    if f_pa_armour.init then f_pa_armour.init() end
    BRC.mpr.debug("  pa-armour loaded")
  end

  if f_pa_weapons then
    if f_pa_weapons.init then f_pa_weapons.init() end
    BRC.mpr.debug("  pa-weapons loaded")
  end

  if f_pa_misc then
    if f_pa_misc.init then f_pa_misc.init() end
    BRC.mpr.debug("  pa-misc loaded")
  end

  -- Don't alert for starting items
  for _, inv in ipairs(items.inventory()) do
    f_pa_data.remember_alert(inv)
    f_pa_data.remove_OTA(inv)
  end
end

function f_pickup_alert.autopickup(it, _)
  if
    not BRC.active
    or pause_pa_system
    or you.have_orb()
    or not it.is_identified and (it.branded or it.artefact or BRC.it.is_magic_staff(it))
  then
    return
  end

  local unworn_aux_item = nil -- Track carried aux armour for mutation scenarios
  if it.is_useless then
    -- Allow alerts for useless aux armour, iff you're carrying one (implies a temporary mutation)
    if not BRC.it.is_aux_armour(it) then return end
    local st = it.subtype()
    for _, inv in ipairs(items.inventory()) do
      if inv.subtype() == st then
        unworn_aux_item = inv
        break
      end
    end
    if not unworn_aux_item then return end
  else
    -- Pickup main
    if f_pa_armour and Config.Pickup.armour and BRC.it.is_armour(it) then
      if f_pa_armour.pickup_armour(it) then return true end
    elseif f_pa_misc and Config.Pickup.staves and BRC.it.is_magic_staff(it) then
      if f_pa_misc.pickup_staff(it) then return true end
    elseif f_pa_weapons and Config.Pickup.weapons and it.is_weapon then
      if f_pa_weapons.pickup_weapon(it) then return true end
    elseif f_pa_misc and f_pa_misc.is_unneeded_ring(it) then
      return false
    end
  end

  -- Item not picked up - check if it should trigger alerts
  if f_pa_data.already_alerted(it) then return end

  if f_pa_misc and Config.Alert.one_time and #Config.Alert.one_time > 0 then
    if f_pa_misc.alert_OTA(it) then return end
  end

  if f_pa_misc and Config.Alert.staff_resists and BRC.it.is_magic_staff(it) then
    if f_pa_misc.alert_staff(it) then return end
  elseif f_pa_misc and Config.Alert.orbs and BRC.it.is_orb(it) then
    if f_pa_misc.alert_orb(it) then return end
  elseif f_pa_misc and Config.Alert.talismans and BRC.it.is_talisman(it) then
    if f_pa_misc.alert_talisman(it) then return end
  elseif f_pa_armour and Config.Alert.armour_sensitivity > 0 and BRC.it.is_armour(it) then
    if f_pa_armour.alert_armour(it, unworn_aux_item) then return end
  elseif f_pa_weapons and Config.Alert.weapon_sensitivity > 0 and it.is_weapon then
    if f_pa_weapons.alert_weapon(it) then return end
  end
end

function f_pickup_alert.c_assign_invletter(it)
  f_pa_misc.alert_OTA(it)
  f_pa_data.remove_recent_alert(it)

  -- Re-enable the alert, iff we are able to use another one
  if BRC.you.num_eq_slots(it) > 1 then f_pa_data.forget_alert(it) end

  -- Ensure we always stop for these autopickup types
  if it.is_weapon or BRC.it.is_armour(it) then
    f_pa_data.update_high_scores(it)
    you.stop_activity()
  end
end

function f_pickup_alert.c_message(text, channel)
  -- Avoid firing alerts when changing armour/weapons
  if channel == "multiturn" then
    if not pause_pa_system and text:contains("ou start ") then pause_pa_system = true end
  elseif channel == "plain" then
    if pause_pa_system and (text:contains("ou stop ") or text:contains("ou finish ")) then
      pause_pa_system = false
    elseif text:contains("one exploring") or text:contains("artly explored") then
      local tokens = { "Recent alerts:" }
      for _, v in ipairs(pa_recent_alerts) do
        tokens[#tokens + 1] = string.format("\n  %s", v)
      end
      if #tokens > 1 then BRC.mpr.que(table.concat(tokens), BRC.COL.magenta) end
      pa_recent_alerts = {}
    end
  end
end

function f_pickup_alert.ready()
  hold_alerts_for_next_turn = false
  if pause_pa_system then return end
  f_pa_weapons.ready()
  f_pa_data.update_high_scores(items.equipped_at("armour"))
end
