--[[
Feature: pickup-alert
Description: Comprehensive pickup and alert system for weapons, armour, and miscellaneous items
Author: buehler
Dependencies: core/config.lua, core/constants.lua, core/data.lua, core/util.lua,
  pa-armour.lua, pa-data.lua, pa-misc.lua, pa-weapons.lua
--]]

f_pickup_alert = {}
f_pickup_alert.BRC_FEATURE_NAME = "pickup-alert"

-- Persistent variables
pa_num_autopickup_funcs = BRC.data.persist("pa_num_autopickup_funcs", #chk_force_autopickup + 1)

-- Local variables
local pause_pa_system

-- Local functions
local function has_configured_force_more(it)
  if it.artefact then
    if BRC.Config.fm_alert.artefact then return true end
    if BRC.Config.fm_alert.trained_artefacts and BRC.get.skill_with(it) > 0 then return true end
  end
  if BRC.Config.fm_alert.armour_ego and BRC.is.armour(it) and BRC.get.ego(it) then return true end
  return false
end

-- Public API
function f_pickup_alert.autopickup(it, _)
  if (
    not BRC.active or
    pause_pa_system or
    you.have_orb() or
    not it.is_identified and (it.branded or it.artefact or BRC.is.magic_staff(it))
  ) then return end

  local unworn_aux_item = nil -- Conditionally set for pa-alert-armour
  if it.is_useless then
    -- Allow alerts for useless aux armour, iff you're carrying one (implies a temporary mutation)
    if not BRC.is.aux_armour(it) then return end
    local st = it.subtype()
    for inv in iter.invent_iterator:new(items.inventory()) do
      local inv_st = inv.subtype()
      if inv_st and inv_st == st then
        unworn_aux_item = inv
        break
      end
    end
    if not unworn_aux_item then return end
  else
    -- Pickup main
    if f_pa_armour and BRC.Config.pickup.armour and BRC.is.armour(it) then
      if f_pa_armour.pickup_armour(it) then return true end
    elseif f_pa_misc and BRC.Config.pickup.staves and BRC.is.magic_staff(it) then
      if f_pa_misc.pickup_staff(it) then return true end
    elseif f_pa_weapons and BRC.Config.pickup.weapons and it.is_weapon then
      if f_pa_weapons.pickup_weapon(it) then return true end
    elseif f_pa_misc and f_pa_misc.is_unneeded_ring(it) then
      return false
    end
  end

  -- Not picking up this item. Now check for alerts.
  if not BRC.Config.alert.system_enabled or f_pa_data.find(pa_items_alerted, it) then return end

  if f_pa_misc and BRC.Config.alert.one_time and #BRC.Config.alert.one_time > 0 then
    if f_pa_misc.alert_OTA(it) then return end
  end

  if f_pa_misc and BRC.Config.alert.staff_resists and BRC.is.magic_staff(it) then
    if f_pa_misc.alert_staff(it) then return end
  elseif f_pa_misc and BRC.Config.alert.orbs and BRC.is.orb(it) then
    if f_pa_misc.alert_orb(it) then return end
  elseif f_pa_misc and BRC.Config.alert.talismans and BRC.is.talisman(it) then
    if f_pa_misc.alert_talisman(it) then return end
  elseif f_pa_armour and BRC.Config.alert.armour and BRC.is.armour(it) then
    if f_pa_armour.alert_armour(it, unworn_aux_item) then return end
  elseif f_pa_weapons and BRC.Config.alert.weapons and it.is_weapon then
    if f_pa_weapons.alert_weapon(it) then return end
  end
end

function f_pickup_alert.do_alert(it, alert_type, emoji, force_more)
  local item_name = f_pa_data.get_keyname(it, true)
  local alert_col
  if it.is_weapon then
    f_pa_data.update_high_scores(it)
    alert_col = BRC.AlertColor.weapon
    local weapon_info = string.format(" (%s)", BRC.get.weapon_stats(it))
    item_name = item_name .. BRC.text.color(BRC.AlertColor.weapon.stats, weapon_info)
  elseif BRC.is.body_armour(it) then
    f_pa_data.update_high_scores(it)
    alert_col = BRC.AlertColor.body_arm
    local ac, ev = BRC.get.armour_stats(it)
    local armour_info = string.format(" {%s, %s}", ac, ev)
    item_name = item_name .. BRC.text.color(BRC.AlertColor.body_arm.stats, armour_info)
  elseif BRC.is.armour(it) then
    alert_col = BRC.AlertColor.aux_arm
  elseif BRC.is.orb(it) then
    alert_col = BRC.AlertColor.orb
  elseif BRC.is.talisman(it) then
    alert_col = BRC.AlertColor.talisman
  else
    alert_col = BRC.AlertColor.misc
  end

  local tokens = {}
  tokens[1] = emoji and emoji or BRC.text.cyan("----")
  tokens[#tokens + 1] = BRC.text.color(alert_col.desc, string.format(" %s:", alert_type))
  tokens[#tokens + 1] = BRC.text.color(alert_col.item, string.format(" %s ", item_name))
  tokens[#tokens + 1] = tokens[1]
  BRC.mpr.que_optmore(force_more or has_configured_force_more(it), table.concat(tokens))

  f_pa_data.insert(pa_recent_alerts, it)
  f_pa_data.insert(pa_items_alerted, it)
  you.stop_activity()
  return true
end

-- Hook functions
function f_pickup_alert.init()
  BRC.log.debug("Initializing pickup-alert submodules...")
  local indent = "  "
  pause_pa_system = false
  f_pa_data.init()
  BRC.log.debug(indent .. "pa-data loaded")

  if f_pa_armour then
    if f_pa_armour.init then f_pa_armour.init() end
    BRC.log.debug(indent .. "pa-armour loaded")
  end

  if f_pa_weapons then
    if f_pa_weapons.init then f_pa_weapons.init() end
    BRC.log.debug(indent .. "pa-weapons loaded")
  end

  if f_pa_misc then
    if f_pa_misc.init then f_pa_misc.init() end
    BRC.log.debug(indent .. "pa-misc loaded")
  end

  -- Check for duplicate autopickup creation (affects local only)
  if pa_num_autopickup_funcs < #chk_force_autopickup then
    BRC.log.warning(table.concat({
      "Warning: Extra autopickup funcs detected. (Commonly from reloading a local game.)\n",
      "Expected: ", pa_num_autopickup_funcs, " but got: ", #chk_force_autopickup, "\n",
      "If this is not expected, restart crawl to clear its memory."
    }))
    if not BRC.mpr.yesno("Continue adding BRC autopickup function?") then
      BRC.log.info("Skipping BRC autopickup function.")
      return
    end
  end

  pa_num_autopickup_funcs = #chk_force_autopickup
end

function f_pickup_alert.c_assign_invletter(it)
  f_pa_misc.alert_OTA(it)
  f_pa_data.remove(pa_recent_alerts, it)

  -- Re-enable the alert, iff we are able to use another one
  if BRC.get.num_equip_slots(it) > 1 then
    f_pa_data.remove(pa_items_alerted, it)
  end

  -- Ensure we always stop for these autopickup types
  if it.is_weapon or BRC.is.armour(it) then
    f_pa_data.update_high_scores(it)
    you.stop_activity()
  end
end

function f_pickup_alert.c_message(text, channel)
  -- Avoid firing alerts when changing armour/weapons
  if channel == "multiturn" then
    if not pause_pa_system and text:find("ou start ", 1, true) then pause_pa_system = true end
  elseif channel == "plain" then
    if pause_pa_system and (text:find("ou stop ", 1, true) or text:find("ou finish ", 1, true)) then
      pause_pa_system = false
    elseif text:find("one exploring", 1, true) or text:find("artly explored", 1, true) then
      local tokens = { "Recent alerts:" }
      for _, v in ipairs(pa_recent_alerts) do
        tokens[#tokens + 1] = string.format("\n  %s", v)
      end
      if #tokens > 1 then BRC.mpr.que(table.concat(tokens), BRC.COLORS.magenta) end
      pa_recent_alerts = {}
    end
  end
end

function f_pickup_alert.ready()
  if pause_pa_system then return end
  f_pa_weapons.ready()
  f_pa_data.update_high_scores(items.equipped_at("armour"))
end
