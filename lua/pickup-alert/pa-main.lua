--[[
Feature: pickup-alert
Description: Comprehensive pickup and alert system for weapons, armour, and miscellaneous items
Author: buehler
Dependencies: core/config.lua, core/data.lua, core/util.lua,
  pickup-alert/pa-armour.lua, pickup-alert/pa-data.lua, pickup-alert/pa-misc.lua, pickup-alert/pa-weapons.lua
--]]

f_pickup_alert = {}
f_pickup_alert.BRC_FEATURE_NAME = "pickup-alert"

-- Persistent variables
num_autopickup_funcs = BRC.data.persist("num_autopickup_funcs", #chk_force_autopickup + 1)

-- Local variables
local pause_pa_system

-- Local functions
local function has_configured_force_more(it)
  if it.artefact then
    if BRC.Config.fm_alert.artefact then return true end
    if BRC.Config.fm_alert.trained_artefacts and BRC.get.skill_with(it) > 0 then return true end
  end
  if BRC.Config.fm_alert.armour_ego and BRC.is.armour(it) and BRC.is.branded(it) then return true end
  return false
end

-- Hook functions
function f_pickup_alert.autopickup(it)
  local unworn_aux_item = nil -- Conditionally set below for pa-alert-armour
  if pause_pa_system then return end
  if you.have_orb() then return end
  if BRC.is.branded(it) and not it.is_identified then return false end
  if not it.is_useless then
    if f_pa_armour and BRC.Config.pickup.armour and BRC.is.armour(it) then
      if f_pa_armour.pickup_armour(it) then return true end
    elseif f_pa_misc and BRC.Config.pickup.staves and BRC.is.magic_staff(it) then
      if f_pa_misc.pickup_staff(it) then return true end
    elseif f_pa_weapons and BRC.Config.pickup.weapons and it.is_weapon then
      if pa_pickup_weapon(it) then return true end
    elseif f_pa_misc and f_pa_misc.is_unneeded_ring(it) then
      return false
    end
  else
    -- Useless item; allow alerts for aux armour if you're carrying one (implies a temporary mutation)
    if BRC.is.aux_armour(it) then return end

    local st = it.subtype()
    for inv in iter.invent_iterator:new(items.inventory()) do
      local inv_st = inv.subtype()
      if inv_st and inv_st == st then
        unworn_aux_item = inv
        break
      end
    end
    if not unworn_aux_item then return end
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
    if pa_alert_weapon(it) then return end
  end
end

function f_pickup_alert.init()
  pause_pa_system = false
  f_pa_data.init()

  if f_pa_armour then
    if f_pa_armour.init then f_pa_armour.init() end
    BRC.debug("    pa-armour loaded")
  end

  if f_pa_weapons then
    if f_pa_weapons.init then f_pa_weapons.init() end
    BRC.debug("    pa-weapons loaded")
  end

  if f_pa_misc then
    if f_pa_misc.init then f_pa_misc.init() end
    BRC.debug("    pa-misc loaded")
  end

  -- Check for duplicate autopickup creation (affects local only)
  if num_autopickup_funcs < #chk_force_autopickup then
    BRC.warn(table.concat({
      "Warning: Duplicate autopickup funcs loaded. (Commonly from reloading a local game.)\n",
      "Expected: ", num_autopickup_funcs, " but got: ", #chk_force_autopickup, "\n",
      "Will skip reloading buehler autopickup. Reload the game to fix crawl's memory usage."
    }))
    return
  end

  -- Hook to the autopickup function
  add_autopickup_func(function(it, _)
    return f_pickup_alert.autopickup(it)
  end)
end

function f_pickup_alert.c_assign_invletter(it)
  f_pa_misc.alert_OTA(it)
  f_pa_data.remove(pa_recent_alerts, it)
  if it.is_weapon and you.race() == "Coglin" then
    -- Allow 1 more alert for an identical weapon, if dual-wielding possible.
    -- ie, Reset the alert the first time you pick up.
    if f_pa_data.find(pa_items_picked, it) then f_pa_data.remove(pa_items_alerted, it) end
  end

  f_pa_data.insert(pa_items_picked, it)

  if it.is_weapon or BRC.is.armour(it) then
    f_pa_data.update_high_scores(it)
    you.stop_activity() -- crawl misses this sometimes
  end
end

function f_pickup_alert.c_message(text, channel)
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

function f_pickup_alert.do_alert(it, alert_type, emoji, force_more)
  local item_name = f_pa_data.get_keyname(it, true)
  local alert_col
  if it.is_weapon then
    alert_col = BRC.AlertColor.weapon
    f_pa_data.update_high_scores(it)
    local weapon_info = string.format(" (%s)", BRC.get.weapon_info(it))
    item_name = item_name .. BRC.text.color(BRC.AlertColor.weapon.stats, weapon_info)
  elseif BRC.is.body_armour(it) then
    alert_col = BRC.AlertColor.body_arm
    f_pa_data.update_high_scores(it)
    local ac, ev = BRC.get.armour_info(it)
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
