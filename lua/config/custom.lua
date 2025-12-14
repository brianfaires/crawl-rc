--- Custom Config Profile: Personalized settings
-- Aims to list the most commonly adjusted config settings.
-- See feature config sections, or Profiles.Explicit for more settings.

brc_config_custom = {
  BRC_CONFIG_NAME = "Custom",

  ["misc-alerts"] = {
    alert_low_hp_threshold = 35, -- % max HP to alert; 0 to disable
    preferred_god = nil, -- Stop on first altar with this text (Ex. "Wu Jian", "Ash"); nil disables
  },
  ["announce-hp-mp"] = {
    dmg_flash_threshold = 0.20, -- Flash screen when losing this % of max HP
    dmg_fm_threshold = 0.30,    -- Force more for losing this % of max HP
    always_on_bottom = false,   -- Rewrite HP/MP meters after each turn with messages
  },
  ["fm-messages"] = {
    force_more_threshold = 6, -- How many force_more_messages; 1=many; 10=none
  },
  ["inscribe-stats"] = {
    inscribe_weapons = true, -- Inscribe weapon stats on pickup and keep updated
    inscribe_armour = true,  -- Inscribe armour stats on pickup and keep updated
  },
  ["remind-id"] = {
    stop_on_scrolls_count = 2, -- Stop when largest un-ID'd scroll stack increases and is >= this
    stop_on_pots_count = 3,    -- Stop when largest un-ID'd potion stack increases and is >= this
  },
  ["runrest-features"] = {
    ignore_portal_exits = true, -- don't stop explore on portal exits
    temple_search = true,       -- on enter or explore, auto-search altars
    gauntlet_search = true,     -- on enter or explore, auto-search gauntlet with filters
  },
  ["startup"] = {
    show_skills_on_startup = false, -- Open skills menu on startup
    auto_set_skill_targets = {
      { "Stealth", 2.0 },  -- First, focus stealth to 2.0
      { "Fighting", 2.0 }, -- If already have stealth, focus fighting to 2.0
    },
  },
  ["pickup-alert"] = {
    Pickup = {
      armour = true,
      staves = true,
      weapons = true,
      weapons_pure_upgrades_only = true, -- Only pick up better versions of same exact weapon
    },

    Alert = {
      armour_sensitivity = 1, -- Adjust all armour alerts; range [0.5-2.0]; 0 to disable
      weapon_sensitivity = 1, -- Adjust all weapon alerts; range [0.5-2.0]; 0 to disable
      orbs = true,            -- Unique orbs
      staff_resists = true,   -- When a staff gives a missing resistance

      talismans = true, -- Alert talismans, if their min skill <= Shapeshifting + talisman_lvl_diff
      talisman_lvl_diff = you.class() == "Shapeshifter" and 27 or 6,

      -- Alert the first time each item is found. Can require training with OTA_require_skill.
      one_time = {
        "buckler", "kite shield", "tower shield", "crystal plate armour",
        "gold dragon scales", "pearl dragon scales", "storm dragon scales", "shadow dragon scales",
        "quick blade", "demon blade", "eudemon blade", "double sword", "triple sword",
        "broad axe", "executioner's axe",
        "demon whip", "eveningstar", "giant spiked club", "morningstar", "sacred scourge",
        "lajatang", "bardiche", "demon trident", "partisan", "trishula",
        "hand cannon", "triple crossbow",
      },
      OTA_require_skill = { weapon = 2, armour = 2.5, shield = 0 }, -- No alert if skill < this

      More = { -- Which alerts generate a force_more_message (some categories overlap)
        early_weap = false,       -- Good weapons found early
        upgrade_weap = false,     -- Better DPS / weapon_score
        weap_ego = false,         -- New or diff egos
        body_armour = false,
        shields = true,
        aux_armour = false,
        armour_ego = false,       -- New or diff egos
        high_score_weap = false,  -- Highest damage found
        high_score_armour = true, -- Highest AC found
        one_time_alerts = true,
        artefact = false,         -- Any artefact
        trained_artefacts = true, -- Artefacts where you have corresponding skill > 0
        orbs = false,
        talismans = you.class() == "Shapeshifter", -- True for shapeshifter, false for everyone else
        staff_resists = false,    -- When a staff gives a missing resistance
      },
    },
  },
} -- brc_config_custom (do not remove this comment)
