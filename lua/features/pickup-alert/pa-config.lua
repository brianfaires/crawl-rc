--[[
Feature: pickup-alert-config
Description: Configuration for the pickup-alert system
Author: buehler
Dependencies: core/constants.lua
--]]

f_pickup_alert = f_pickup_alert or {}
f_pickup_alert.Config = {}
f_pickup_alert.Config.Pickup = {
  armour = true,
  weapons = true,
  weapons_pure_upgrades_only = true, -- Only pick up better versions of same exact weapon
  staves = true,
} -- f_pickup_alert.Config.Pickup (do not remove this comment)

f_pickup_alert.Config.Alert = {
  armour_sensitivity = 1.0, -- Adjust all armour alerts; 0 to disable all (typical range 0.5-2.0)
  weapon_sensitivity = 1.0, -- Adjust all weapon alerts; 0 to disable all (typical range 0.5-2.0)
  orbs = true,
  staff_resists = true,
  talismans = true,
  first_ranged = true,
  first_polearm = true,

  hotkey_travel = true,
  hotkey_pickup = true,

  -- Only alert a plain talisman if its min_skill <= Shapeshifting + talisman_lvl_diff
  talisman_lvl_diff = you.class() == "Shapeshifter" and 27 or 6,

  -- Each usable item is alerted once.
  one_time = {
    "wand of digging", "buckler", "kite shield", "tower shield", "crystal plate armour",
    "gold dragon scales", "pearl dragon scales", "storm dragon scales", "shadow dragon scales",
    "quick blade", "demon blade", "eudemon blade", "double sword", "triple sword",
    "broad axe", "executioner's axe",
    "demon whip", "eveningstar", "giant spiked club", "morningstar", "sacred scourge",
    "lajatang", "bardiche", "demon trident", "partisan", "trishula",
    "hand cannon", "triple crossbow",
  },

  -- Only do one-time alerts if your skill >= this value, in weap_school/armour/shield
  OTA_require_skill = { weapon = 2, armour = 2.5, shield = 0 },

  -- Which alerts generate a force_more
  More = {
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
    trained_artefacts = true, -- Artefacts where you have corresponding skill > 0
    orbs = false,
    talismans = you.class() == "Shapeshifter", -- True for shapeshifter, false for everyone else
    staff_resists = false,
  },
} -- f_pickup_alert.Config.Alert (do not remove this comment)

---- Heuristics for tuning the pickup/alert system. Advanced behavior customization.
f_pickup_alert.Config.Tuning = {}

--[[
  f_pickup_alert.Config.Tuning.Armour: Magic numbers for the armour pickup/alert system.
  For armour with different encumbrance, alert when ratio of gain/loss (AC|EV) is > value
  Lower values mean more alerts. gain/diff/same/lose refers to egos.
  min_gain/max_loss block alerts for new egos, when AC or EV delta is outside limits
  ignore_small: if abs(AC+EV) <= this, ignore ratios and alert any gain/diff ego
--]]
f_pickup_alert.Config.Tuning.Armour = {
  Lighter = {
    gain_ego = 0.6,
    new_ego = 0.7,
    diff_ego = 0.9,
    same_ego = 1.2,
    lost_ego = 2.0,
    min_gain = 3.0,
    max_loss = 4.0,
    ignore_small = 3.5,
  },

  Heavier = {
    gain_ego = 0.4,
    new_ego = 0.5,
    diff_ego = 0.6,
    same_ego = 0.7,
    lost_ego = 2.0,
    min_gain = 3.0,
    max_loss = 8.0,
    ignore_small = 5,
  },

  encumb_penalty_weight = 0.7, -- [0-2.0] Penalty to heavy armour when training magic/ranged
  early_xl = 6, -- Alert all usable runed body armour if XL <= early_xl
  diff_body_ego_is_good = false, -- More alerts for diff_ego in body armour (skips min_gain check)
} -- f_pickup_alert.Config.Tuning.Armour (do not remove this comment)

--[[
  f_pickup_alert.Config.Tuning.Weap: Magic numbers for the weapon pickup/alert system, namely:
    1. Cutoffs for pickup/alert weapons (when DPS ratio exceeds a value)
    2. Cutoffs for when alerts are active (XL, skill_level)
  Pickup/alert system will try to upgrade ANY weapon in your inventory.
  "DPS ratio" is (new_weapon_score / inventory_weapon_score). Score considers DPS/brand/accuracy.
--]]
f_pickup_alert.Config.Tuning.Weap = {}
f_pickup_alert.Config.Tuning.Weap.Pickup = {
  add_ego = 1.0, -- Pickup weapon that gains a brand if DPS ratio > add_ego
  same_type_melee = 1.2, -- Pickup melee weap of same school if DPS ratio > same_type_melee
  same_type_ranged = 1.1, -- Pickup ranged weap if DPS ratio > same_type_ranged
  accuracy_weight = 0.25, -- Treat +1 Accuracy as +accuracy_weight DPS
} -- f_pickup_alert.Config.Tuning.Weap.Pickup (do not remove this comment)

f_pickup_alert.Config.Tuning.Weap.Alert = {
  -- Alerts for weapons not requiring an extra hand
  pure_dps = 1.0, -- Alert if DPS ratio > pure_dps
  gain_ego = 0.8, -- Gaining ego; Alert if DPS ratio > gain_ego
  new_ego = 0.8, -- Get ego not in inventory; Alert if DPS ratio > new_ego
  low_skill_penalty_damping = 8, -- [0-20] Reduces penalty to weapons of lower-trained schools

  -- Alerts for 2-handed weapons, when carrying 1-handed
  AddHand = {
    ignore_sh_lvl = 4.0, -- Treat offhand as empty if shield_skill < ignore_sh_lvl
    add_ego_lose_sh = 0.8, -- Alert 1h -> 2h (using shield) if DPS ratio > add_ego_lose_sh
    not_using = 1.0, --  Alert 1h -> 2h (not using 2nd hand) if DPS ratio > not_using
  },

  -- Alerts for good early weapons of all types
  Early = {
    xl = 7, -- Alert early weapons if XL <= xl
    skill = { factor = 1.5, offset = 2.0 }, -- Ignore weapons with skill_diff > XL*factor+offset
    branded_min_plus = 4, -- Alert branded weapons with plus >= branded_min_plus
  },

  -- Alerts for particularly strong ranged weapons
  EarlyRanged = {
    xl = 14, -- Alert strong ranged weapons if XL <= xl
    min_plus = 7, -- Alert ranged weapons with plus >= min_plus
    branded_min_plus = 4, -- Alert branded ranged weapons with plus >= branded_min_plus
    max_shields = 8.0, -- Alert 2h ranged, despite a wearing shield, if shield_skill <= max_shields
  },
} -- f_pickup_alert.Config.Tuning.Weap.Alert (do not remove this comment)

f_pickup_alert.Config.AlertColor = {
  weapon = { desc = BRC.COL.magenta, item = BRC.COL.yellow, stats = BRC.COL.lightgrey },
  body_arm = { desc = BRC.COL.lightblue, item = BRC.COL.lightcyan, stats = BRC.COL.lightgrey },
  aux_arm = { desc = BRC.COL.lightblue, item = BRC.COL.yellow },
  orb = { desc = BRC.COL.green, item = BRC.COL.lightgreen },
  talisman = { desc = BRC.COL.green, item = BRC.COL.lightgreen },
  misc = { desc = BRC.COL.brown, item = BRC.COL.white },
} -- f_pickup_alert.Config.AlertColor (do not remove this comment)

f_pickup_alert.Config.Emoji = not BRC.Config.emojis and {} or {
  RARE_ITEM = "💎",
  ARTEFACT = "💠",
  ORB = "🔮",
  TALISMAN = "🧬",
  STAFF_RES = "🔥",

  WEAPON = "⚔️",
  RANGED = "🏹",
  POLEARM = "🔱",
  TWO_HAND = "✋🤚",

  EGO = "✨",
  ACCURACY = "🎯",
  STRONGER = "💪",
  STRONGEST = "💪💪",
  LIGHTER = "⏬",
  HEAVIER = "⏫",
} -- f_pickup_alert.Config.Emoji (do not remove this comment)
