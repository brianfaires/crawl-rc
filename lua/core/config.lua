--[[
BRC Configuration - Various configs, overriding default values in feature configs.
Author: buehler
Dependencies: (none)
Usage:
  - Update BRC.config_to_use to load the corresponding config.
  - Update each config or create new ones.
  - Values that aren't defined will first fall back to Configs.Default, then to the defaults defined in feature configs.
  - Define `init = function(self) ... end` in a config to run code after it loads. (use self to access the config table)
--]]

-- Initialize BRC namespace and Public modules
BRC = BRC or {}
BRC.Configs = {}
BRC.config_to_use = "ask"

-- Default: non-feature default values
BRC.Configs.Default = {
  emojis = false, -- Use emojis in alerts and announcements
  show_debug_messages = false,
} -- BRC.Configs.Default (do not remove this comment)
BRC.Config = BRC.Configs.Default -- Init BRC.Config

-- Testing Config: Isolate and test specific features
BRC.Configs.Testing = {
  show_debug_messages = true,
  disable_other_features = true,
  ["pickup-alert"] = {
    Alert = {
      armour_sensitivity = 0.1,
      weapon_sensitivity = 0.1,
    },
  },
  init = function(self)
    if self.disable_other_features then
      for _, v in pairs(_G) do
        if BRC.is_feature_module(v) and not self[v.BRC_FEATURE_NAME] then
          self[v.BRC_FEATURE_NAME] = { disabled = true }
        end
      end
    end
  end,
} -- BRC.Configs.Testing (do not remove this comment)

-- Custom Config: Personalized settings
BRC.Configs.Custom = {
  ["misc-alerts"] = {
    alert_low_hp_threshold = 0.35, -- % max HP to alert; 0 to disable
  },
  ["announce-hp-mp"] = {
    dmg_flash_threshold = 0.20, -- Flash screen when losing this % of max HP
    dmg_fm_threshold = 0.30,    -- Force more for losing this % of max HP
    always_on_bottom = false,   -- Rewrite HP/MP meters after each turn with messages
  },
  ["inscribe-stats"] = {
    inscribe_weapons = true, -- Inscribe weapon stats on pickup and adjust each turn
    inscribe_armour = true,  -- Inscribe armour stats on pickup and adjust each turn
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
      armour_sensitivity = 0.1, -- Adjust all armour alerts; range [0.5-2.0]; 0 = disable all armour alerts
      weapon_sensitivity = 2, -- Adjust all weapon alerts; range [0.5-2.0]; 0 = disable all weapon alerts
      orbs = true,
      staff_resists = true, -- When a staff gives a missing resistance
      talismans = true,

      one_time = { -- Alert the first time each item is found
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
  },

  BrandBonus = {
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
  },
} -- BRC.Configs.Custom (do not remove this comment)

-- Speed Config: For speed runs
BRC.Configs.Speed = {
  ["after-shaft"] = { disabled = true },
  ["alert-monsters"] = { disabled = true },
  ["safe-consumables"] = { disabled = true },
  ["safe-stairs"] = { disabled = true },
  ["announce-hp-mp"] = {
    dmg_flash_threshold = 0.20, -- Flash screen when losing this % of max HP
    dmg_fm_threshold = 1,    -- Force more for losing this % of max HP
    always_on_bottom = true,   -- Rewrite HP/MP meters after each turn with messages
  },
  ["misc-alerts"] = {
    alert_low_hp_threshold = 0, -- % max HP to alert; 0 to disable
    save_with_msg = false, -- Shift-S to save and leave yourself a message
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
      armour_sensitivity = 1.1, -- Adjust all armour alerts; range [0.5-2.0]; 0 = disable all armour alerts
      weapon_sensitivity = 1.2, -- Adjust all weapon alerts; range [0.5-2.0]; 0 = disable all weapon alerts
      orbs = false,
      staff_resists = false, -- When a staff gives a missing resistance
      talismans = false,

      one_time = { -- Alert the first time each item is found
        "kite shield", "tower shield", "crystal plate armour",
        "gold dragon scales", "pearl dragon scales", "storm dragon scales",
        "broad axe", "demon whip", "eveningstar", "morningstar",
      },
      OTA_require_skill = { weapon = 6, armour = 0, shield = 0 }, -- One-time alert only when skill level >= this

      More = { }, -- All nil / false
    },
    Tuning = {
      Armour = {
        encumb_penalty_weight = 0, -- Penalizes heavier armour when training spellcasting/ranged. 0 to disable
        early_xl = 0, -- Alert all usable runed body armour if XL <= `early_xl`
      },
    },
  },

  init = function(self)
    self.startup.auto_set_skill_targets = { { BRC.get.preferred_weapon_type(), 8.0 } }
  end
} -- BRC.Configs.Speed (do not remove this comment)

-- Turncount Config: For turncount runs
BRC.Configs.Turncount = {

} -- BRC.Configs.Turncount (do not remove this comment)

-- Streak Config: For win streaks
BRC.Configs.Streak = {

} -- BRC.Configs.Streak (do not remove this comment)
