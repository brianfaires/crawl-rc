--[[
BRC Configuration - Various configs, overriding default values in feature configs.
Author: buehler
Dependencies: (none)
Usage:
  - Update BRC.config_to_use to load the corresponding config.
  - Update each config or create new ones.
  - Undefined values first fall back to Configs.Default, then defaults in feature.Config.
  - `init` (function or multi-line comment of lua) executes after config loads, before overrides.
  - If using config_memory == "full", the function needs to be saved as a string instead. --]]
-- To do this, just replace `function()` and `end` with double square brackets: [[ ... ]]

---- Initialize BRC namespace and Public modules
BRC = BRC or {}
BRC.Profiles = {}
BRC.config_to_use = "ask"
BRC.config_memory = "name"

-- Default Config Profile (defines all non-feature values)
BRC.Profiles.Default = {
  emojis = false, -- Use emojis in alerts and announcements
  show_debug_messages = false,
} -- BRC.Profiles.Default (do not remove this comment)
BRC.Config = BRC.Profiles.Default -- Always init to Default profile

-- Testing Config Profile: Isolate and test specific features
BRC.Profiles.Testing = {
  show_debug_messages = true,
  disable_other_features = false,
  ["pickup-alert"] = {
    Alert = {
      armour_sensitivity = 0.3,
      weapon_sensitivity = 2,
    },
    Tuning = {
      Armour = {
        diff_body_ego_is_good = false,
      },
    },
  },
  init = [[
    if BRC.Config.disable_other_features then
      for _, v in pairs(_G) do
        if BRC.is_feature_module(v) and not BRC.Config[v.BRC_FEATURE_NAME] then
          BRC.Config[v.BRC_FEATURE_NAME] = { disabled = true }
        end
      end
    end
  ]],
} -- BRC.Profiles.Testing (do not remove this comment)

-- Custom Config Profile: Personalized settings
BRC.Profiles.Custom = {
  ["misc-alerts"] = {
    alert_low_hp_threshold = 0.35, -- % max HP to alert; 0 to disable
  },
  ["announce-hp-mp"] = {
    dmg_flash_threshold = 0.20, -- Flash screen when losing this % of max HP
    dmg_fm_threshold = 0.30,    -- Force more for losing this % of max HP
    always_on_bottom = false,   -- Rewrite HP/MP meters after each turn with messages
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
      weapon_sensitivity = 1,   -- Adjust all weapon alerts; range [0.5-2.0]; 0 to disable
      orbs = true,
      staff_resists = true,     -- When a staff gives a missing resistance
      talismans = true,

      one_time = { -- Alert the first time each item is found
        "wand of digging", "buckler", "kite shield", "tower shield", "crystal plate armour",
        "gold dragon scales", "pearl dragon scales", "storm dragon scales", "shadow dragon scales",
        "quick blade", "demon blade", "eudemon blade", "double sword", "triple sword",
        "broad axe", "executioner's axe",
        "demon whip", "eveningstar", "giant spiked club", "morningstar", "sacred scourge",
        "lajatang", "bardiche", "demon trident", "partisan", "trishula",
        "hand cannon", "triple crossbow",
      },
      OTA_require_skill = { weapon = 2, armour = 2.5, shield = 0 }, -- No one_time if skill < this

      More = { -- Which alerts generate a force_more_message (some categories overlap)
        early_weap = false,       -- Good weapons found early
        upgrade_weap = false,     -- Better DPS / weapon_score
        weap_ego = false,         -- New or diff egos
        body_armour = false,
        shields = true,
        aux_armour = false,
        armour_ego = false,        -- New or diff egos
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
  },
} -- BRC.Profiles.Custom (do not remove this comment)

-- Speed Config Profile: For speed runs
BRC.Profiles.Speed = {
  ["after-shaft"] = { disabled = true },
  ["alert-monsters"] = { disabled = true },
  ["safe-consumables"] = { disabled = true },
  ["safe-stairs"] = { disabled = true },
  ["announce-hp-mp"] = {
    dmg_flash_threshold = 0.20, -- Flash screen when losing this % of max HP
    dmg_fm_threshold = 1,       -- Force more for losing this % of max HP
    always_on_bottom = true,    -- Rewrite HP/MP meters after each turn with messages
  },
  ["misc-alerts"] = {
    alert_low_hp_threshold = 0, -- % max HP to alert; 0 to disable
    save_with_msg = false,      -- Shift-S to save and leave yourself a message
  },
  ["remind-id"] = {
    stop_on_scrolls_count = 9, -- Stop when largest un-ID'd scroll stack increases and is >= this
    stop_on_pots_count = 9,    -- Stop when largest un-ID'd potion stack increases and is >= this
  },
  ["startup"] = {
    show_skills_on_startup = false, -- Open skills menu on startup
  },
  ["pickup-alert"] = {
    Pickup = {
      armour = true,
      staves = false,
      weapons = true,
      weapons_pure_upgrades_only = false, -- Only pick up better versions of same exact weapon
    },

    Alert = {
      armour_sensitivity = 1.1, -- [0.5-2.0] Adjust all armour alerts; 0 to disable
      weapon_sensitivity = 1.2, -- [0.5-2.0] Adjust all weapon alerts; 0 to disable
      orbs = false,
      staff_resists = false, -- When a staff gives a missing resistance
      talismans = false,

      one_time = { -- Alert the first time each item is found
        "kite shield", "tower shield", "crystal plate armour",
        "gold dragon scales", "pearl dragon scales", "storm dragon scales",
        "broad axe", "demon whip", "eveningstar", "morningstar",
      },
      OTA_require_skill = { weapon = 6, armour = 0, shield = 0 }, -- No one_time if skill < this

      More = {}, -- All nil / false
    },
    Tuning = {
      Armour = {
        encumb_penalty_weight = 0, -- [0-2.0] Penalty to heavy armour when training magic/ranged
        early_xl = 0, -- Alert all usable runed body armour if XL <= `early_xl`
      },
    },
  },

  init = [[
    BRC.Config.startup.auto_set_skill_targets = { { BRC.get.preferred_weapon_type(), 8.0 } }
  ]],
} -- BRC.Profiles.Speed (do not remove this comment)

-- Turncount Config Profile: For turncount runs
BRC.Profiles.Turncount = {
  ["after-shaft"] = { disabled = true },
  ["alert-monsters"] = {
    sensitivity = 1.25, -- 0 to disable all; at 2.0, alerts will fire at 1/2 HP
  },
} -- BRC.Profiles.Turncount (do not remove this comment)

-- Streak Config Profile: For win streaks
BRC.Profiles.Streak = {
  ["alert-monsters"] = {
    sensitivity = 1.5, -- 0 to disable all; at 2.0, alerts will fire at 1/2 HP
  },
} -- BRC.Profiles.Streak (do not remove this comment)
