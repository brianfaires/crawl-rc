--[[
BRC Configuration - Core BRC config, and optional overrides for any config value defined in a feature module.
Author: buehler
Dependencies: (None)
--]]
BRC = BRC or {}
BRC.Config = {}

BRC.Config.emojis = false -- Use emojis in alerts and announcements
BRC.Config.show_debug_messages = true
BRC.Config.offer_debug_notes_on_char_dump = true -- Won't add to char dump unless told to

-- Feature config overrides: Can override anything defined in a feature.Config
-- Define values in a table matching the feature_name like: `BRC.Config[feature_name] = {...}`
BRC.Config["misc-alerts"] = { alert_low_hp_threshold = 0.35 } -- % max HP to alert; 0 to disable

BRC.Config["announce-hp-mp"] = {}
BRC.Config["announce-hp-mp"].dmg_flash_threshold = 0.20 -- Flash screen when losing this % of max HP
BRC.Config["announce-hp-mp"].dmg_fm_threshold = 0.30 -- Force more for losing this % of max HP
BRC.Config["announce-hp-mp"].every_turn = true -- Announce every turn, not just when HP/MP changes

BRC.Config["inscribe-stats"] = {}
BRC.Config["inscribe-stats"].inscribe_weapons = true -- Inscribe weapon stats on pickup and adjust each turn
BRC.Config["inscribe-stats"].inscribe_armour = true -- Inscribe armour stats on pickup and adjust each turn

BRC.Config["remind-id"] = {}
BRC.Config["remind-id"].stop_on_scrolls_count = 2 -- Stop when largest un-ID'd scroll stack increases and is >= this
BRC.Config["remind-id"].stop_on_pots_count = 3 -- Stop when largest un-ID'd potion stack increases and is >= this

BRC.Config["runrest-features"] = {}
BRC.Config["runrest-features"].ignore_portal_exits = true -- don't stop explore on portal exits
BRC.Config["runrest-features"].temple_search = true -- on enter or explore, auto-search altars
BRC.Config["runrest-features"].gauntlet_search = true -- on enter or explore, auto-search gauntlet with filters

BRC.Config["startup"] = {}
BRC.Config["startup"].show_skills_on_startup = false -- Show skills menu on startup
BRC.Config["startup"].auto_set_skill_targets = {
  { "Stealth", 2.0 }, -- First, focus stealth to 2.0
  { "Fighting", 2.0 }, -- If already have stealth, focus fighting to 2.0
} -- BRC.Config["startup"].auto_set_skill_targets (Do not remove this comment)

--[[
  Pickup/Alert system
  This does not affect other autopickup settings; just the BRC Pickup/Alert system
  Choose which items are auto-picked up, alerted, and when force-more is applied.
--]]
BRC.Config.pickup = {
  armour = true,
  weapons = true,
  weapons_pure_upgrades_only = true, -- Only pick up better versions of same exact weapon
  staves = true,
} -- BRC.Config.pickup (do not remove this comment)

-- Which alerts are enabled
BRC.Config.alert = {
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
  }, -- BRC.Config.alert.one_time (do not remove this comment)

  -- Only do one-time alerts if your skill >= this value, in weap_school/armour/shield
  OTA_require_skill = { weapon = 2, armour = 2.5, shield = 0 },
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


---- BRC.BrandBonus: Tune the impact of brands on DPS calculations
-- This applies to weapon inscriptions, and item comparisons in the pickup-alert system.
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

---- Cosmetic settings
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

BRC.LogColor = {
  error = "lightred",
  warning = "yellow",
  info = "lightgrey",
  debug = "lightblue",
} -- BRC.LogColor (do not remove this comment)

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

  BRC.Emoji.REMIND_ID = BRC.Config.emojis and "🎁" or "<magenta>?</magenta>"
  BRC.Emoji.EXCLAMATION = "❗"
  BRC.Emoji.EXCLAMATION_2 = "‼️"

  BRC.Emoji.SUCCESS = "✅"
else
  BRC.Emoji.EXCLAMATION = "<magenta>!</magenta>"
  BRC.Emoji.EXCLAMATION_2 = "<lightmagenta>!!</lightmagenta>"
end

if BRC.Config.emojis then
  BRC.Emoji.HP_METER = { FULL = "❤️", PART = "❤️‍🩹", EMPTY = "🤍" }
  BRC.Emoji.MP_METER = { FULL = "🟦", PART = "🔹", EMPTY = "➖" }
else
  BRC.Emoji.HP_METER = {
    BORDER = "<white>|</white>",
    FULL = "<lightgreen>+</lightgreen>",
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
