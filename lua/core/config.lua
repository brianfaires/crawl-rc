-- Initialize
BRC = BRC or {}
BRC.Config = {}

BRC.Config.emojis = true -- Use emojis in alerts and announcements

-- after-shaft.lua
BRC.Config.stop_on_stairs_after_shaft = true -- Stop on stairs after shaft, until back to original level

-- announce-hp-mp.lua: Announce HP/MP changes
BRC.Config.dmg_flash_threshold = 0.20 -- Flash screen when losing this % of max HP
BRC.Config.dmg_fm_threshold = 0.30 -- Force more for losing this % of max HP
BRC.Config.announce = {
  hp_loss_limit = 1, -- Announce when HP loss >= this
  hp_gain_limit = 4, -- Announce when HP gain >= this
  mp_loss_limit = 1, -- Announce when MP loss >= this
  mp_gain_limit = 2, -- Announce when MP gain >= this
  hp_first = true, -- Show HP first in the message
  same_line = true, -- Show HP/MP on the same line
  always_both = true, -- If showing one, show both
  very_low_hp = 0.10, -- At this % of max HP, show all HP changes and mute % HP alerts
} -- BRC.Config.announce (do not remove this comment)

-- An alternative announce setup: Displays meters after every turn. Uncomment the following block to try it.
--[[
  BRC.Config.announce = {
    hp_loss_limit = 0,
    hp_gain_limit = 0,
    mp_loss_limit = 0,
    mp_gain_limit = 0,
    hp_first = true,
    same_line = true,
    always_both = true
  } -- BRC.Config.announce (do not remove this comment)
--]]

-- color-inscribe.lua
BRC.Config.colorize_inscriptions = true -- Colorize inscriptions on pickup

-- drop-inferior.lua
BRC.Config.drop_inferior = true -- Mark items for drop when better item picked up
BRC.Config.msg_on_inscribe = true -- Show a message when an item is marked for drop

-- exclude-dropped.lua: Disables auto-pickup for whatever you drop
BRC.Config.exclude_dropped = true -- Exclude items from auto-pickup when dropped
BRC.Config.ignore_stashed_weapon_scrolls = true -- Keep picking up enchant/brand scrolls if holding enchantable weapon

-- fm-disable.lua: Disable built-in force_mores that can't be easily removed
BRC.Config.fm_disable = true -- Skip the 'more' prompt for messages configured in fm-disable.lua

-- fm-monsters.lua: Dynamically set force mores based on hp/resistances/etc
BRC.Config.fm_on_uniques = true -- Stop on all Uniques & Pan lords
BRC.Config.fm_pack_duration = 15 -- Turns before alerting again for specific monster types; 0 to disable
BRC.Config.disable_fm_monsters_in_zigs = true -- Disable dynamic force_mores in Ziggurats
BRC.Config.debug_fm_monsters = false -- Get a message when a fm changes

-- fully-recover.lua: Keep resting until these statuses are gone.
-- Special cases exist for "slowed" and "corroded". If you include them, use those exact strings only.
BRC.Config.rest_off_statuses = {
  "berserk", "confused", "corroded", "marked", "short of breath",
  "slowed", "sluggish", "tree%-form", "vulnerable", "weakened",
} -- BRC.Config.rest_off_statuses (do not remove this comment)

-- inscribe-stats.lua: Inscribe stats on pickup and adjust each turn
BRC.Config.inscribe_weapons = true
BRC.Config.inscribe_armour = true
BRC.Config.inscribe_dps_type = "plain" -- How to calc dmg for weapon inscriptions (See BRC.DMG_TYPE in constants.lua)

-- misc-alerts.lua
BRC.Config.alert_low_hp_threshold = 0.35 -- % max HP to alert; 0 to disable
BRC.Config.alert_remove_faith = true -- Reminder to remove amulet at max piety
BRC.Config.alert_spell_level_changes = true -- Alert when you gain additional spell levels
BRC.Config.save_with_msg = true -- Shift-S to save and leave yourself a message

-- remind-id.lua: Before finding scroll of ID, stop travel when increasing largest stack size, starting at:
BRC.Config.stop_on_scrolls_count = 2 -- Stop on a stack of this many un-ID'd scrolls
BRC.Config.stop_on_pots_count = 3 -- Stop on a stack of this many un-ID'd potions

-- runrest-features.lua: Runrest features
BRC.Config.ignore_altars = true -- when you have a god already
BRC.Config.ignore_portal_exits = true -- don't stop explore on portal exits
BRC.Config.stop_on_hell_stairs = true -- stop explore on hell stairs
BRC.Config.stop_on_pan_gates = true -- stop explore on pan gates
BRC.Config.temple_macros = true -- auto-search altars; run to exit after worship
BRC.Config.gauntlet_macros = true -- auto-search with filters

-- safe-consumables.lua
BRC.Config.safe_consumables = true -- Maintain !r and !q on all consumables without a built-in prompt

-- safe-stairs.lua: Detect/warn for accidental stair usage
BRC.Config.warn_v5 = true -- Prompt before entering Vaults:5
BRC.Config.warn_stairs_threshold = 5 -- Warn if taking stairs back within # turns; 0 to disable

-- startup.lua: Startup features
BRC.Config.show_skills_on_startup = true
BRC.Config.auto_set_skill_targets = {
  { "Stealth", 2.0 }, -- First, focus stealth to 2.0
  { "Fighting", 2.0 }, -- If already have stealth, focus fighting to 2.0
} -- auto_set_skill_targets (do not remove this comment)

-- weapon-slots.lua: Always use a/b/w slots for weapons
BRC.Config.do_auto_weapon_slots_abw = true -- Auto-move weapons to a/b/w slots

--[[
  Pickup/Alert system
  This does not affect other autopickup settings; just the BRC Pickup/Alert system
  Choose which items are auto-picked up, alerted, and when force-more is applied.
--]]
BRC.Config.pickup = {
  armour = true,
  weapons = true,
  staves = true,
} -- BRC.Config.pickup (do not remove this comment)

-- Which alerts are enabled
BRC.Config.alert = {
  system_enabled = true, -- If false, no alerts are generated
  armour = true,
  weapons = true,
  orbs = true,
  staff_resists = true,
  talismans = true,

  -- Only alert a plain talisman if its min_skill <= Shapeshifting + talisman_lvl_diff
  talisman_lvl_diff = you.class() == "Shapeshifter" and 27 or 6, -- 27 for Shapeshifter, 6 for everyone else

  -- Each non-useless item is alerted once.
  one_time = {
    "broad axe",
    "executioner's axe",
    "eveningstar",
    "demon whip",
    "giant spiked club",
    "sacred scourge",
    "lajatang",
    "bardiche",
    "demon trident",
    "trishula",
    "quick blade",
    "eudemon blade",
    "demon blade",
    "double sword",
    "triple sword",
    "crystal plate armour",
    "gold dragon scales",
    "pearl dragon scales",
    "storm dragon scales",
    "shadow dragon scales",
    "wand of digging",
    "triple crossbow",
    "hand cannon",
    "buckler",
    "kite shield",
    "tower shield",
  }, -- BRC.Config.alert.one_time (do not remove this comment)

  -- Only do one-time alerts if your skill >= this value, in weap_school/armour/shield
  OTA_require_skill = { weapon = 3, armour = 2.5, shield = 0 },
} -- BRC.Config.alert (do not remove this comment)

-- Which alerts generate a force_more
BRC.Config.fm_alert = {
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
} -- BRC.Config.fm_alert (do not remove this comment)

-- Heuristics for tuning the pickup/alert system. Advanced behavior customization.
BRC.Tuning = {}

--[[
  BRC.Tuning.armour: Magic numbers for the armour pickup/alert system.
  For armour with different encumbrance, alert when ratio of gain/loss (AC|EV) is > value
  Lower values mean more alerts. gain/diff/same/lose refers to egos.
  min_gain/max_loss check against the AC or EV delta when ego changes; skip alerts if delta outside limits
  ignore_small: separate from AC/EV ratios, if absolute AC+EV loss is <= this, alert any gain/diff ego
--]]
BRC.Tuning.armour = {
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
} -- BRC.Tuning.armour (do not remove this comment)

--[[
  BRC.Tuning.weap: Magic numbers for the weapon pickup/alert system. Two common types of values:
    1. Cutoffs for pickup/alert weapons (when DPS ratio exceeds a value)
    2. Cutoffs for when alerts are active (XL, skill_level)
  Pickup/alert system will try to upgrade ANY weapon in your inventory.
  "DPS ratio" is (new_weapon_score / inventory_weapon_score). Score considers DPS, brand, and accuracy.
--]]
BRC.Tuning.weap = {}
BRC.Tuning.weap.pickup = {
  add_ego = 1.0, -- Pickup weapon that gains a brand if DPS ratio > `add_ego`
  same_type_melee = 1.2, -- Pickup melee weap of same school if DPS ratio > `same_type_melee`
  same_type_ranged = 1.1, -- Pickup ranged weap if DPS ratio > `same_type_ranged`
  accuracy_weight = 0.25, -- Treat +1 Accuracy as +`accuracy_weight` DPS
} -- BRC.Tuning.weap.pickup (do not remove this comment)

BRC.Tuning.weap.alert = {
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
  }, -- BRC.Tuning.weap.alert.early_ranged (do not remove this comment)
} -- BRC.Tuning.weap.alert (do not remove this comment)

-- Tune the impact of brands on DPS calc; used to compare weapons and in inscribe-stats.lua
-- Uses "terse" ego names, e.g. "spect" instead of "spectralizing"
BRC.BrandBonus = {
  chaos = { factor = 1.15, offset = 2.0 }, -- Approximate weighted average
  distort = { factor = 1.0, offset = 6.0 },
  drain = { factor = 1.25, offset = 2.0 },
  elec = { factor = 1.0, offset = 4.5 }, -- technically 3.5 on avg; fudged up for AC pen
  flame = { factor = 1.25, offset = 0 },
  freeze = { factor = 1.25, offset = 0 },
  heavy = { factor = 1.8, offset = 0 }, -- Speed is accounted for elsewhere
  pain = { factor = 1.0, offset = you.skill("Necromancy") / 2 },
  spect = { factor = 1.7, offset = 0 }, -- Fudged down for increased incoming damage
  venom = { factor = 1.0, offset = 5.0 }, -- estimated 5 dmg per poisoning

  subtle = { -- Completely made up values in attempt to compare weapons fairly
    antimagic = { factor = 1.1, offset = 0 },
    holy = { factor = 1.15, offset = 0 },
    penet = { factor = 1.3, offset = 0 },
    protect = { factor = 1.15, offset = 0 },
    reap = { factor = 1.3, offset = 0 },
    vamp = { factor = 1.2, offset = 0 },
  }, -- BRC.BrandBonus.subtle (do not remove this comment)
} -- BRC.BrandBonus (do not remove this comment)

-- Cosmetic settings
BRC.AlertColor = {
  weapon = {
    desc = "magenta",
    item = "yellow",
    stats = "lightgrey",
  },
  body_arm = {
    desc = "lightblue",
    item = "lightcyan",
    stats = "lightgrey",
  },
  aux_arm = { desc = "lightblue", item = "yellow" },
  orb = { desc = "green", item = "lightgreen" },
  talisman = { desc = "green", item = "lightgreen" },
  misc = { desc = "brown", item = "white" },
} -- BRC.AlertColor (do not remove this comment)

BRC.Emoji = {}
if BRC.Config.emojis then
  BRC.Emoji.RARE_ITEM = "💎"
  BRC.Emoji.ORB = "🔮"
  BRC.Emoji.TALISMAN = "🧬"

  BRC.Emoji.WEAPON = "⚔️"
  BRC.Emoji.RANGED = "🏹"
  BRC.Emoji.POLEARM = "🔱"
  BRC.Emoji.TWO_HAND = "✋🤚"
  BRC.Emoji.CAUTION = "⚠️"

  BRC.Emoji.STAFF_RESISTANCE = "🔥"

  BRC.Emoji.ACCURACY = "🎯"
  BRC.Emoji.STRONGER = "💪"
  BRC.Emoji.STRONGEST = "💪💪"
  BRC.Emoji.EGO = "✨"
  BRC.Emoji.LIGHTER = "⏬"
  BRC.Emoji.HEAVIER = "⏫"
  BRC.Emoji.ARTEFACT = "💠"

  BRC.Emoji.REMIND_ID = "🎁"
  BRC.Emoji.EXCLAMATION = "❗"
  BRC.Emoji.EXCLAMATION_2 = "‼️"

  BRC.Emoji.HP_METER = { FULL = "❤️", PART = "❤️‍🩹", EMPTY = "🤍" }
  BRC.Emoji.MP_METER = { FULL = "🟦", PART = "🔹", EMPTY = "➖" }

  BRC.Emoji.SUCCESS = "✅"
else
  BRC.Emoji.REMIND_ID = "<magenta>?</magenta>"
  BRC.Emoji.EXCLAMATION = "<magenta>!</magenta>"
  BRC.Emoji.EXCLAMATION_2 = "<lightmagenta>!!</lightmagenta>"

  BRC.Emoji.HP_METER = {
    BORDER = "<white>|</white>",
    FULL = "<green>+</green>",
    PART = "<lightgrey>+</lightgrey>",
    EMPTY = "<darkgrey>-</darkgrey>",
  } -- BRC.Emoji.HP_METER (do not remove this comment)
  BRC.Emoji.MP_METER = {
    BORDER = "<white>|</white>",
    FULL = "<lightblue>+</lightblue>",
    PART = "<lightgrey>+</lightgrey>",
    EMPTY = "<darkgrey>-</darkgrey>",
  } -- BRC.Emoji.MP_METER (do not remove this comment)
end
