--[[
Feature: pickup-alert
Description: Comprehensive pickup and alert system for weapons, armour, and miscellaneous items
Author: buehler
Dependencies: core/config.lua, core/constants.lua, core/data.lua, core/util.lua,
  pa-armour.lua, pa-data.lua, pa-misc.lua, pa-weapons.lua
--]]

f_pickup_alert = {}
f_pickup_alert.BRC_FEATURE_NAME = "pickup-alert"
f_pickup_alert.Config = {}
f_pickup_alert.Config.pickup = {
  armour = true,
  weapons = true,
  weapons_pure_upgrades_only = true, -- Only pick up better versions of same exact weapon
  staves = true,
} -- f_pickup_alert.Config.pickup (do not remove this comment)

f_pickup_alert.Config.alert = {
  alerts_enabled = true, -- If false, no alerts are generated
  armour = true,
  weapons = true,
  orbs = true,
  staff_resists = true,
  talismans = true,

  -- Only alert a plain talisman if its min_skill <= Shapeshifting + talisman_lvl_diff
  talisman_lvl_diff = you.class() == "Shapeshifter" and 27 or 6, -- 27 for Shapeshifter, 6 for everyone else

  -- Each non-useless item is alerted once.
  one_time = {
    "wand of digging", "buckler", "kite shield", "tower shield",
    "crystal plate armour", "gold dragon scales", "pearl dragon scales", "storm dragon scales", "shadow dragon scales",
    "quick blade", "demon blade", "eudemon blade", "double sword", "triple sword",
    "broad axe", "executioner's axe",
    "demon whip", "eveningstar", "giant spiked club", "morningstar", "sacred scourge",
    "lajatang", "bardiche", "demon trident", "partisan", "trishula", "hand cannon", "triple crossbow",
  }, -- f_pickup_alert.Config.alert.one_time (do not remove this comment)

  -- Only do one-time alerts if your skill >= this value, in weap_school/armour/shield
  OTA_require_skill = { weapon = 2, armour = 2.5, shield = 0 },
} -- f_pickup_alert.Config.alert (do not remove this comment)

-- Which alerts generate a force_more
f_pickup_alert.Config.fm_alert = {
  early_weap = false, -- Good weapons found early
  upgrade_weap = false, -- Better DPS / weapon_score
  weap_ego = false, -- New or diff egos
  body_armour = false,
  shields = true,
  aux_armour = false,
  armour_ego = true, -- New or diff egos
  high_score_weap = false, -- Highest damage found
  high_score_armour = true, -- Highest AC found
  one_time_alerts = true,
  artefact = false, -- Any artefact
  trained_artefacts = true, -- Only for artefacts where you have corresponding skill > 0
  orbs = false,
  talismans = you.class() == "Shapeshifter", -- True for shapeshifter, false for everyone else
  staff_resists = false,
} -- f_pickup_alert.Config.fm_alert (do not remove this comment)

---- Heuristics for tuning the pickup/alert system. Advanced behavior customization.
f_pickup_alert.Config.Tuning = {}

--[[
  f_pickup_alert.Config.Tuning.armour: Magic numbers for the armour pickup/alert system.
  For armour with different encumbrance, alert when ratio of gain/loss (AC|EV) is > value
  Lower values mean more alerts. gain/diff/same/lose refers to egos.
  min_gain/max_loss check against the AC or EV delta when ego changes; skip alerts if delta outside limits
  ignore_small: separate from AC/EV ratios, if absolute AC+EV loss is <= this, alert any gain/diff ego
--]]
f_pickup_alert.Config.Tuning.armour = {
  lighter = {
    gain_ego = 0.6,
    diff_ego = 0.8,
    same_ego = 1.2,
    lost_ego = 2.0,
    min_gain = 3.0,
    max_loss = 4.0,
    ignore_small = 3.5,
  },
  heavier = {
    gain_ego = 0.4,
    diff_ego = 0.5,
    same_ego = 0.7,
    lost_ego = 2.0,
    min_gain = 3.0,
    max_loss = 8.0,
    ignore_small = 5,
  },
  encumb_penalty_weight = 0.7, -- Penalizes heavier armour when training spellcasting/ranged. 0 to disable
  early_xl = 6, -- Alert all usable runed body armour if XL <= `early_xl`
} -- f_pickup_alert.Config.Tuning.armour (do not remove this comment)

--[[
  f_pickup_alert.Config.Tuning.weap: Magic numbers for the weapon pickup/alert system. Two common types of values:
    1. Cutoffs for pickup/alert weapons (when DPS ratio exceeds a value)
    2. Cutoffs for when alerts are active (XL, skill_level)
  Pickup/alert system will try to upgrade ANY weapon in your inventory.
  "DPS ratio" is (new_weapon_score / inventory_weapon_score). Score considers DPS, brand, and accuracy.
--]]
f_pickup_alert.Config.Tuning.weap = {}
f_pickup_alert.Config.Tuning.weap.pickup = {
  add_ego = 1.0, -- Pickup weapon that gains a brand if DPS ratio > `add_ego`
  same_type_melee = 1.2, -- Pickup melee weap of same school if DPS ratio > `same_type_melee`
  same_type_ranged = 1.1, -- Pickup ranged weap if DPS ratio > `same_type_ranged`
  accuracy_weight = 0.25, -- Treat +1 Accuracy as +`accuracy_weight` DPS
} -- f_pickup_alert.Config.Tuning.weap.pickup (do not remove this comment)

f_pickup_alert.Config.Tuning.weap.alert = {
  -- Alerts for weapons not requiring an extra hand
  pure_dps = 1.0, -- Alert if DPS ratio > `pure_dps`
  gain_ego = 0.8, -- Gaining ego; Alert if DPS ratio > `gain_ego`
  new_ego = 0.8, -- Get ego not in inventory; Alert if DPS ratio > `new_ego`
  low_skill_penalty_damping = 8, -- Increase to penalize low-trained schools. Penalty = (skill+damp) / (top_skill+damp)

  -- Alerts for 2-handed weapons, when carrying 1-handed
  add_hand = {
    ignore_sh_lvl = 4.0, -- Treat offhand as empty if shield_skill < `ignore_sh_lvl`
    add_ego_lose_sh = 0.8, -- Alert 1h -> 2h (using shield) if DPS ratio > `add_ego_lose_sh`
    not_using = 1.0, --  Alert 1h -> 2h (not using 2nd hand) if DPS ratio > `not_using`
  },

  -- Alerts for good early weapons of all types
  early = {
    xl = 7, -- Alert early weapons if XL <= `xl`
    skill = { factor = 1.5, offset = 2.0 }, -- Skip weapons with skill diff > XL * factor + offset
    branded_min_plus = 4, -- Alert branded weapons with plus >= `branded_min_plus`
  },

  -- Alerts for particularly strong ranged weapons
  early_ranged = {
    xl = 14, -- Alert strong ranged weapons if XL <= `xl`
    min_plus = 7, -- Alert ranged weapons with plus >= `min_plus`
    branded_min_plus = 4, -- Alert branded ranged weapons with plus >= `branded_min_plus`
    max_shields = 8.0, -- Alert 2h ranged, despite shield, if shield_skill <= `max_shields`
  }, -- f_pickup_alert.Config.Tuning.weap.alert.early_ranged (do not remove this comment)
} -- f_pickup_alert.Config.Tuning.weap.alert (do not remove this comment)

-- Persistent variables
pa_num_autopickup_funcs = BRC.data.persist("pa_num_autopickup_funcs", #chk_force_autopickup + 1)

-- Local config
local Config = f_pickup_alert.Config

-- Local variables
local pause_pa_system

-- Local functions
local function has_configured_force_more(it)
  if it.artefact then
    if Config.fm_alert.artefact then return true end
    if Config.fm_alert.trained_artefacts and BRC.get.skill_with(it) > 0 then return true end
  end
  if Config.fm_alert.armour_ego and BRC.is.armour(it) and BRC.get.ego(it) then return true end
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
    if f_pa_armour and Config.pickup.armour and BRC.is.armour(it) then
      if f_pa_armour.pickup_armour(it) then return true end
    elseif f_pa_misc and Config.pickup.staves and BRC.is.magic_staff(it) then
      if f_pa_misc.pickup_staff(it) then return true end
    elseif f_pa_weapons and Config.pickup.weapons and it.is_weapon then
      if f_pa_weapons.pickup_weapon(it) then return true end
    elseif f_pa_misc and f_pa_misc.is_unneeded_ring(it) then
      return false
    end
  end

  -- Not picking up this item. Now check for alerts.
  if not Config.alert.alerts_enabled or f_pa_data.find(pa_items_alerted, it) then return end

  if f_pa_misc and Config.alert.one_time and #Config.alert.one_time > 0 then
    if f_pa_misc.alert_OTA(it) then return end
  end

  if f_pa_misc and Config.alert.staff_resists and BRC.is.magic_staff(it) then
    if f_pa_misc.alert_staff(it) then return end
  elseif f_pa_misc and Config.alert.orbs and BRC.is.orb(it) then
    if f_pa_misc.alert_orb(it) then return end
  elseif f_pa_misc and Config.alert.talismans and BRC.is.talisman(it) then
    if f_pa_misc.alert_talisman(it) then return end
  elseif f_pa_armour and Config.alert.armour and BRC.is.armour(it) then
    if f_pa_armour.alert_armour(it, unworn_aux_item) then return end
  elseif f_pa_weapons and Config.alert.weapons and it.is_weapon then
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
