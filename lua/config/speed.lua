-- Speed Config Profile: For speed runs

BRC.Profiles.Speed = {
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
  ["mute-messages"] = {
    mute_level = 3,
  },
  ["remind-id"] = {
    stop_on_scrolls_count = 9, -- Stop when largest un-ID'd scroll stack increases and is >= this
    stop_on_pots_count = 9,    -- Stop when largest un-ID'd potion stack increases and is >= this
  },
  ["runrest-features"] = { after_shaft = false },
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
    BRC.Config.startup.auto_set_skill_targets = { { BRC.you.top_wpn_skill(), 8.0 } }
  ]],
} -- BRC.Profiles.Speed (do not remove this comment)
