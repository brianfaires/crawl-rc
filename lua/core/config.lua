CONFIG = {}
TUNING = {}
WEAPON_BRAND_BONUSES = {}


function init_config()
  CONFIG = {}

  CONFIG.emojis = false -- Use emojis in alerts and damage announcements

  -- Announce HP/MP when change is greater than this value
  CONFIG.announce_hp_threshold = 1
  CONFIG.announce_mp_threshold = 0
  -- Flash/Force more for losing this percentage of max HP
  CONFIG.dmg_flash_threshold = 0.20
  CONFIG.dmg_fm_threshold = 0.30

  -- Inscribe stats
  CONFIG.inscribe_weapons = true
  CONFIG.inscribe_armour = true

  -- Runrest features
  CONFIG.ignore_altars = true
  CONFIG.ignore_portal_exits = true
  CONFIG.stop_on_pan_gates = true
  CONFIG.temple_macros = true
  CONFIG.gauntlet_macros = true

  -- Misc alerts
  CONFIG.warn_v5 = true
  CONFIG.warn_stairs_threshold = 5 -- Warn if taking stairs back within # turns; 0 to disable
  CONFIG.fm_pack_duration = 15 -- Turns before alerting again for a pack monster; 0 to disable
  CONFIG.alert_remove_faith = true
  CONFIG.alert_low_hp_threshold = 0.35 -- % max HP to alert; 0 to disable
  CONFIG.save_with_msg = true
  CONFIG.stop_on_scrolls_count = 2 -- Before finding ID, stop when you have this many un-ID'd scrolls
  CONFIG.stop_on_pots_count = 3 -- Before finding ID, stop when you have this many un-ID'd potions

  -- exclude-dropped
  CONFIG.exclude_stashed_enchant_scrolls = false -- Don't exclude enchant/brand scrolls if holding enchantable weapon

  CONFIG.do_auto_weapon_slots_abw = true
  CONFIG.rest_off_statuses = {
    "berserk", "short of breath", "corroded", "vulnerable", 
    "confused", "marked", "tree%-form", "slowed", "sluggish"
  } -- rest_off_statuses (do not remove this comment)

  ---- Pickup/Alert system
  -- Choose which items are auto-picked up
  CONFIG.pickup = {
    armour = true,
    weapons = true,
    staves = true
  } -- CONFIG.pickup (do not remove this comment)

  -- Which alerts are enabled
  CONFIG.alert = {
    system_enabled = true, -- If false, all alerts are skipped
    armour = true,
    weapons = true,
    orbs = true,
    talismans = true,
    talisman_lvl_diff = 6, -- Only alert a plain talisman if its min_skill <= Shapeshifting + this
    staff_resists = true,

    -- Each item is alerted once. Set to empty to disable.
    one_time = {
      "broad axe", "executioner's axe", "eveningstar", "demon whip",
      "sacred scourge", "lajatang", "bardiche", "demon trident", "trishula",
      "quick blade", "eudemon blade", "demon blade", "double sword", "triple sword",
      "crystal plate armour", "gold dragon scales", "pearl dragon scales",
      "storm dragon scales", "shadow dragon scales", "wand of digging",
      "triple crossbow", "hand cannon", "buckler", "kite shield", "tower shield"
    } -- one_time_alerts (do not remove this comment)
  } -- CONFIG.alert (do not remove this comment)

  -- Which alerts generate a force_more
  CONFIG.fm_alert = {
    early_weap = false,
    new_weap = true,
    body_armour = true,
    aux_armour = true,
    shields = true,
    high_score_weap = true,
    high_score_armour = true,
    one_time_alerts = true,
    artefact = true,
    orbs = false,
    talismans = false,
    staff_resists = true
  } -- CONFIG.fm_alert (do not remove this comment)

  -- Startup
  CONFIG.show_skills_on_startup = true
  CONFIG.auto_set_skill_targets = {
    { "Stealth", 2.0 },
    { "Fighting", 2.0 }
  } -- auto_set_skill_targets (do not remove this comment)

  -- Debugging
  CONFIG.debug_init = false -- track progress through init()
  CONFIG.debug_fm_monsters = false -- Get a message when a fm changes



  -- Heuristics for tuning the pickup/alert system
  TUNING = {}

  -- Alerts for armour of diff encumbrance, when ratio of gain/loss (AC|EV) is > value
  -- Lower values mean more alerts. gain/diff/same/lose refers to egos.
  -- min_gain/max_loss check against the AC or EV delta when ego changes
  TUNING.armour = {
    lighter = {gain_ego = 0.6, diff_ego = 0.8, same_ego = 1.2, lost_ego = 2.0, min_gain = 3.0, max_loss = 4.0 },
    heavier = {gain_ego = 0.4, diff_ego = 0.5, same_ego = 0.7, lost_ego = 2.0, min_gain = 3.0, max_loss = 8.0 },
    encumb_penalty_weight = 0.7 -- Penalizes heavier armour when training spellcasting/ranged. 0 to disable
  }

  -- All 'magic numbers' used in the weapon pickup/alert system.
    -- 1. Cutoffs for pickup/alert weapons (when DPS ratio exceeds a value)
    -- 2. Cutoffs for when alerts are active (XL, skill_level)
  TUNING.weap = {}
  TUNING.weap.pickup = {
    add_ego = 0.85, -- Pickup weapon that gains a brand if DPS ratio > `add_ego`
    same_type_melee = 1.1, -- Pickup melee weap of same type if DPS ratio > `same_type_melee`
    same_type_ranged = 1.0, -- Pickup ranged weap of same type if DPS ratio > `same_type_ranged`
    accuracy_weight = 0.33 -- Treat +1 Accuracy as +`accuracy_weight` DPS
  }
  
  TUNING.weap.alert = {
    -- Alerts for weapons not requiring an extra hand
    pure_dps = 1.0, -- Alert if DPS ratio > `pure_dps`
    gain_ego = 0.8, -- Gaining ego; Alert if DPS ratio > `gain_ego`
    new_ego = 0.8, -- Get ego not in inventory;Alert if DPS ratio > `new_ego`
    low_skill_penalty_damping = 8, -- Small values penalize low-trained schools more. Penalty is (skill+damp) / (top_skill+damp)

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
      branded_min_plus = 4 -- Alert branded weapons with plus >= `branded_min_plus`
    },

    -- Alerts for particularly strong ranged weapons
    early_ranged = {
      xl = 14, -- Alert strong ranged weapons if XL <= `xl`
      min_plus = 7, -- Alert ranged weapons with plus >= `min_plus`
      branded_min_plus = 4, -- Alert branded ranged weapons with plus >= `branded_min_plus`
      max_shields = 8.0 -- Alert 2h ranged, despite shield, if shield_skill <= `max_shields`
    }
  }



  -- Defining impact of brands on DPS; used in PA system and weapon inscriptions
  -- `scoring` includes subtle brands
  DMG_TYPE = { unbranded = 1, branded = 2, scoring = 3 }

  WEAPON_BRAND_BONUSES = {
    spectralizing = { factor = 2.0, offset = 0 },
    heavy = { factor = 1.8, offset = 0 },
    flaming = { factor = 1.25, offset = 0 },
    freezing = { factor = 1.25, offset = 0 },
    draining = { factor = 1.25, offset = 2.0 },
    electrocution = { factor = 1.0, offset = 4.5 }, -- technically 3.5 on avg; fudged up for AC pen
    venom = { factor = 1.0, offset = 5.0 }, -- 5 dmg per poisoning
    pain = { factor = 1.0, offset = you.skill("Necromancy")/2 },
    distortion = { factor = 1.0, offset = 6.0 },
    chaos = { factor = 1.15, offset = 2.0 }, -- Approximate weighted average

    subtle = { -- Completely made up in attempt to balance vs the damaging brands
      protection = { factor = 1.15, offset = 0 },
      vampirism = { factor = 1.2, offset = 0 },
      holy_wrath = { factor = 1.15, offset = 0 },
      antimagic = { factor = 1.1, offset = 0 }  
    }
  }


  ALERT_COLORS = {
    weapon = { desc = COLORS.magenta, item = COLORS.yellow, stats = COLORS.lightgrey },
    body_arm = { desc = COLORS.blue, item = COLORS.lightcyan, stats = COLORS.lightgrey },
    aux_arm = { desc = COLORS.lightblue, item = COLORS.yellow },
    orb = { desc = COLORS.green, item = COLORS.lightgreen },
    talisman = { desc = COLORS.green, item = COLORS.lightgreen },
    staff = { desc = COLORS.brown, item = COLORS.white },
  }

  if CONFIG.debug_init then crawl.mpr("Initialized config") end
end
