--[[
Feature: pickup-alert
Description: Comprehensive pickup and alert system for weapons, armour, and miscellaneous items
Author: buehler
Dependencies: CONFIG, COLORS, EMOJI, ALERT_COLORS, iter, util, pa-util
--]]

f_pickup_alert = {}
f_pickup_alert.BRC_FEATURE_NAME = "pickup-alert"

-- Local state
local loaded_pa_armour
local loaded_pa_misc
local loaded_pa_weapons
pause_pa_system = nil

function has_configured_force_more(it)
  if it.artefact then
    if CONFIG.fm_alert.artefact then return true end
    if CONFIG.fm_alert.trained_artefacts and BRC.get.skill_with_item(it) > 0 then return true end
  end
  if CONFIG.fm_alert.armour_ego and BRC.is.armour(it) and has_ego(it) then return true end
  return false
end

-- Hook functions
function f_pickup_alert.init()
  pause_pa_system = false
  f_pickup_alert_data.init()

  if f_pickup_alert_armour then
    loaded_pa_armour = true
    if f_pickup_alert_armour.init then f_pickup_alert_armour.init() end
    BRC:debug("    pa-armour loaded")
  end

  if f_pickup_alert_weapons then
    loaded_pa_weapons = true
    if f_pickup_alert_weapons.init then f_pickup_alert_weapons.init() end
    BRC:debug("    pa-weapons loaded")
  end

  if f_pickup_alert_misc then
    loaded_pa_misc = true
    if f_pickup_alert_misc.init then f_pickup_alert_misc.init() end
    BRC:debug("    pa-misc loaded")
  end

  -- Check for duplicate autopickup creation (affects local only)
  BRC.data.create("num_autopickup_funcs", #chk_force_autopickup + 1)
  if num_autopickup_funcs < #chk_force_autopickup then
    crawl.mpr("Warning: Duplicate autopickup funcs loaded. (Commonly from reloading a local game.)")
    crawl.mpr("Expected: " .. num_autopickup_funcs .. " but got: " .. #chk_force_autopickup)
    crawl.mpr("Will skip reloading buehler autopickup. Reload the game to fix crawl's memory usage.")
    return
  end

  ---- Autopickup main ----
  add_autopickup_func(function(it, _)
    local unworn_aux_item = nil -- Conditionally set below for pa-alert-armour
    if pause_pa_system then return end
    if you.have_orb() then return end
    if has_ego(it) and not it.is_identified then return false end
    if not it.is_useless then
      if loaded_pa_armour and CONFIG.pickup.armour and BRC.is.armour(it) then
        if pa_pickup_armour(it) then return true end
      elseif loaded_pa_misc and CONFIG.pickup.staves and BRC.is.magic_staff(it) then
        if pa_pickup_staff(it) then return true end
      elseif loaded_pa_weapons and CONFIG.pickup.weapons and it.is_weapon then
        if pa_pickup_weapon(it) then return true end
      elseif loaded_pa_misc and is_unneeded_ring(it) then
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
    if not CONFIG.alert.system_enabled or already_contains(pa_items_alerted, it) then return end

    if loaded_pa_misc and CONFIG.alert.one_time and #CONFIG.alert.one_time > 0 then
      if pa_alert_OTA(it) then return end
    end

    if loaded_pa_misc and CONFIG.alert.staff_resists and BRC.is.magic_staff(it) then
      if pa_alert_staff(it) then return end
    elseif loaded_pa_misc and CONFIG.alert.orbs and BRC.is.orb(it) then
      if pa_alert_orb(it) then return end
    elseif loaded_pa_misc and CONFIG.alert.talismans and BRC.is.talisman(it) then
      if pa_alert_talisman(it) then return end
    elseif loaded_pa_armour and CONFIG.alert.armour and BRC.is.armour(it) then
      if pa_alert_armour(it, unworn_aux_item) then return end
    else
      if loaded_pa_weapons and CONFIG.alert.weapons and it.is_weapon then
        if pa_alert_weapon(it) then return end
      end
    end
  end)
end

function pa_alert_item(it, alert_type, emoji, force_more)
  local item_desc = get_plussed_name(it, "plain")
  local alert_colors
  if it.is_weapon then
    alert_colors = ALERT_COLORS.weapon
    update_high_scores(it)
    item_desc = item_desc .. BRC.util.color(ALERT_COLORS.weapon.stats, " (" .. get_weapon_info_string(it) .. ")")
  elseif BRC.is.body_armour(it) then
    alert_colors = ALERT_COLORS.body_arm
    update_high_scores(it)
    local ac, ev = get_armour_info_strings(it)
    item_desc = item_desc .. BRC.util.color(ALERT_COLORS.body_arm.stats, " {" .. ac .. ", " .. ev .. "}")
  elseif BRC.is.armour(it) then
    alert_colors = ALERT_COLORS.aux_arm
  elseif BRC.is.orb(it) then
    alert_colors = ALERT_COLORS.orb
  elseif BRC.is.talisman(it) then
    alert_colors = ALERT_COLORS.talisman
  else
    alert_colors = ALERT_COLORS.misc
  end
  local tokens = {}
  tokens[1] = emoji and emoji or BRC.util.color(COLORS.cyan, "----")
  tokens[#tokens + 1] = BRC.util.color(alert_colors.desc, " " .. alert_type .. ": ")
  tokens[#tokens + 1] = BRC.util.color(alert_colors.item, item_desc .. " ")
  tokens[#tokens + 1] = tokens[1]

  BRC.mpr.que_optmore(force_more or has_configured_force_more(it), table.concat(tokens))

  table.insert(pa_recent_alerts, get_plussed_name(it))
  add_to_pa_table(pa_items_alerted, it)
  you.stop_activity()
  return true
end

function f_pickup_alert.c_assign_invletter(it)
  pa_alert_OTA(it)

  util.remove(pa_recent_alerts, get_plussed_name(it))
  if it.is_weapon and you.race() == "Coglin" then
    -- Allow 1 more alert for an identical weapon, if dual-wielding possible.
    -- ie, Reset the alert the first time you pick up.
    local name, _ = get_pa_keys(it)
    if pa_items_picked[name] == nil then pa_items_alerted[name] = nil end
  end

  add_to_pa_table(pa_items_picked, it)

  if it.is_weapon or BRC.is.armour(it) then
    update_high_scores(it)
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
      local tokens = {}
      for _, v in ipairs(pa_recent_alerts) do
        tokens[#tokens + 1] = "\n  " .. v
      end
      if #tokens > 0 then BRC.mpr.que("Recent alerts:" .. table.concat(tokens), COLORS.magenta) end
      pa_recent_alerts = {}
    end
  end
end

function f_pickup_alert.ready()
  if pause_pa_system then return end
  f_pickup_alert_weapons.ready()
  update_high_scores(items.equipped_at("armour"))
end
