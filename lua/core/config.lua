--[[
BRC Configuration - Core BRC config, and optional overrides for feature config values.
Author: buehler
Dependencies: (none)
Notes: Never put a closing brace `}` on a line by itself. (This will break crawl's RC parser.)
--]]

-- Initialize BRC namespace and Config module
BRC = BRC or {}
BRC.Config = {}

-- Core config values
BRC.Config.emojis = false -- Use emojis in alerts and announcements
BRC.Config.show_debug_messages = true
BRC.Config.offer_debug_notes_on_char_dump = true -- Won't add to char dump unless told to

-- Feature config overrides: Define like `BRC.Config[feature_name] = {...}`
BRC.Config["misc-alerts"] = {
  alert_low_hp_threshold = 0.35, -- % max HP to alert; 0 to disable
} -- BRC.Config["misc-alerts"] (do not remove this comment)

BRC.Config["announce-hp-mp"] = {
  dmg_flash_threshold = 0.20, -- Flash screen when losing this % of max HP
  dmg_fm_threshold = 0.30,    -- Force more for losing this % of max HP
  always_on_bottom = false,   -- Rewrite HP/MP meters after each turn with messages
} -- BRC.Config["announce-hp-mp"] (do not remove this comment)

BRC.Config["inscribe-stats"] = {
  inscribe_weapons = true, -- Inscribe weapon stats on pickup and adjust each turn
  inscribe_armour = true,  -- Inscribe armour stats on pickup and adjust each turn
} -- BRC.Config["inscribe-stats"] (do not remove this comment)

BRC.Config["remind-id"] = {
  stop_on_scrolls_count = 2, -- Stop when largest un-ID'd scroll stack increases and is >= this
  stop_on_pots_count = 3,    -- Stop when largest un-ID'd potion stack increases and is >= this
} -- BRC.Config["remind-id"] (do not remove this comment)

BRC.Config["runrest-features"] = {
  ignore_portal_exits = true, -- don't stop explore on portal exits
  temple_search = true,       -- on enter or explore, auto-search altars
  gauntlet_search = true,     -- on enter or explore, auto-search gauntlet with filters
} -- BRC.Config["runrest-features"] (do not remove this comment)

BRC.Config["startup"] = {
  show_skills_on_startup = false, -- Open skills menu on startup
  auto_set_skill_targets = {
    { "Stealth", 2.0 },  -- First, focus stealth to 2.0
    { "Fighting", 2.0 }, -- If already have stealth, focus fighting to 2.0
  },
} -- BRC.Config["startup"] (do not remove this comment)


BRC.Config["pickup-alert"] = {
  Pickup = {
    armour = true,
    staves = true,
    weapons = true,
    weapons_pure_upgrades_only = true, -- Only pick up better versions of same exact weapon
  },

  Alert = {
    armour_sensitivity = 0.1, -- Adjust all armour alerts; range [0.5-2.0]; 0 = disable all armour alerts
    weapon_sensitivity = 0.1, -- Adjust all weapon alerts; range [0.5-2.0]; 0 = disable all weapon alerts
    orbs = true,
    staff_resists = true, -- When a staff gives a missing resistance
    talismans = true,

    one_time = { -- Alert the first time each itemis found
      "wand of digging", "buckler", "kite shield", "tower shield", "crystal plate armour",
      "gold dragon scales", "pearl dragon scales", "storm dragon scales", "shadow dragon scales",
      "quick blade", "demon blade", "eudemon blade", "double sword", "triple sword",
      "broad axe", "executioner's axe",
      "demon whip", "eveningstar", "giant spiked club", "morningstar", "sacred scourge",
      "lajatang", "bardiche", "demon trident", "partisan", "trishula", "hand cannon", "triple crossbow",
    },
    OTA_require_skill = { weapon = 2, armour = 2.5, shield = 0 }, -- One-time alert only when skill level >= this

    More = { -- Which alerts generate a force_more_message (some categories overlap)
      early_weap = false,       -- Good weapons found early
      upgrade_weap = false,     -- Better DPS / weapon_score
      weap_ego = false,         -- New or diff egos
      body_armour = false,
      shields = true,
      aux_armour = false,
      armour_ego = true,        -- New or diff egos
      high_score_weap = false,  -- Highest damage found
      high_score_armour = true, -- Highest AC found
      one_time_alerts = true,
      artefact = false,         -- Any artefact
      trained_artefacts = true, -- Artefacts where you have corresponding skill > 0
      orbs = false,
      talismans = you.class() == "Shapeshifter", -- True for shapeshifter, false for everyone else
      staff_resists = false,
    },
  },
} -- BRC.Config["pickup-alert"] (do not remove this comment)

---- BRC.BrandBonus: Tune the impact of brands on DPS calculations
-- This applies to weapon inscriptions, and item comparisons in the pickup-alert system.
-- Uses "terse" ego names, e.g. "spect" instead of "spectralizing"
BRC.BrandBonus = {
  chaos = { factor = 1.15, offset = 2.0 }, -- Approximate weighted average
  distort = { factor = 1.0, offset = 6.0 },
  drain = { factor = 1.25, offset = 2.0 },
  elec = { factor = 1.0, offset = 4.5 },   -- 3.5 on avg; fudged up for AC pen
  flame = { factor = 1.25, offset = 0 },
  freeze = { factor = 1.25, offset = 0 },
  heavy = { factor = 1.8, offset = 0 },    -- Speed is accounted for elsewhere
  pain = { factor = 1.0, offset = you.skill("Necromancy") / 2 },
  spect = { factor = 1.7, offset = 0 },    -- Fudged down for increased incoming damage
  venom = { factor = 1.0, offset = 5.0 },  -- 5 dmg per poisoning

  subtle = { -- Values estimated for weapon comparisons
    antimagic = { factor = 1.1, offset = 0 },
    holy = { factor = 1.15, offset = 0 },
    penet = { factor = 1.3, offset = 0 },
    protect = { factor = 1.15, offset = 0 },
    reap = { factor = 1.3, offset = 0 },
    vamp = { factor = 1.2, offset = 0 },
  },
} -- BRC.BrandBonus (do not remove this comment)

---- Cosmetic settings
BRC.LogColor = {
  error = "lightred",
  warning = "yellow",
  info = "lightgrey",
  debug = "lightblue",
} -- BRC.LogColor (do not remove this comment)

BRC.Emoji = {
  CAUTION = BRC.Config.emojis and "⚠️" or "<yellow>!</yellow>",
  EXCLAMATION = BRC.Config.emojis and "❗" or "<magenta>!</magenta>",
  EXCLAMATION_2 = BRC.Config.emojis and "‼️" or "<lightmagenta>!!</lightmagenta>",
  SUCCESS = BRC.Config.emojis and "✅" or nil,
} -- BRC.Emoji (do not remove this comment)
