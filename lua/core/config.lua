CONFIG = {}
TUNING = {}
WEAPON_BRAND_BONUSES = {}


function init_config()
  CONFIG = {}

  CONFIG.emojis = true -- Use emojis in alerts and announcements

  -- after-shaft.lua
  CONFIG.stop_on_stairs_after_shaft = true -- Stop on stairs after shaft

  -- announce-damage.lua: Announce HP/MP changes
  CONFIG.dmg_flash_threshold = 0.20 -- Flash screen when losing this % of max HP
  CONFIG.dmg_fm_threshold = 0.30 -- Force more for losing this % of max HP
  CONFIG.announce = {
    hp_loss_limit = 1, -- Announce when HP loss >= this
    hp_gain_limit = 4, -- Announce when HP gain >= this
    mp_loss_limit = 1, -- Announce when MP loss >= this
    mp_gain_limit = 2, -- Announce when MP gain >= this
    hp_first = true, -- Show HP first in the message
    same_line = true, -- Show HP/MP on the same line
    always_both = true, -- If showing one, show both
    very_low_hp = 0.10 -- At this % of max HP, show all HP changes and mute % HP alerts
  } -- CONFIG.announce (do not remove this comment)
  -- Alternative: Displays meters every turn at bottom of msg window
  --CONFIG.announce = {hp_loss_limit = 0, hp_gain_limit = 0, mp_loss_limit = 0, mp_gain_limit = 0, hp_first = true, same_line = true, always_both = true}

  -- color-inscribe.lua
  CONFIG.colorize_inscriptions = true -- Colorize inscriptions on pickup

  -- drop-inferior.lua
  CONFIG.drop_inferior = true -- Mark items for drop when better item picked up

  -- exclude-dropped.lua: Disables auto-pickup for whatever you drop
  CONFIG.exclude_dropped = true -- Exclude items from auto-pickup when dropped
  CONFIG.ignore_stashed_weapon_scrolls = true -- Keep picking up enchant/brand scrolls if holding enchantable weapon

  -- fm-disable.lua: Disable built-in force_mores that can't just be -='d
  CONFIG.fm_disable = true -- Skip more prompts for messages configured in fm-disable.lua

  -- fm-monsters.lua: Dynamically set force mores based on hp/resistances/etc
  CONFIG.fm_pack_duration = 15 -- Turns before alerting again for specific monster types; 0 to disable
  CONFIG.debug_fm_monsters = false -- Get a message when a fm changes

  -- fully-recover.lua: Rest off bad statuses during rest
  CONFIG.rest_off_statuses = {
    "berserk", "short of breath", "corroded", "vulnerable", 
    "confused", "marked", "tree%-form", "slowed", "sluggish"
  } -- CONFIG.rest_off_statuses (do not remove this comment)

  -- inscribe-stats.lua: Inscribe stats on pickup and adjust each turn
  CONFIG.inscribe_weapons = true
  CONFIG.inscribe_armour = true
  CONFIG.inscribe_dps_type = DMG_TYPE.branded -- 1=unbranded, 2=branded

  -- misc-alerts.lua
  CONFIG.alert_low_hp_threshold = 0.35 -- % max HP to alert; 0 to disable
  CONFIG.alert_remove_faith = true -- Reminder to remove amulet at max piety
  CONFIG.save_with_msg = true -- Shift-S to save and leave yourself a message

  -- remind-id.lua:Before finding scroll of ID, stop travel on new largest stack size, starting with:
  CONFIG.stop_on_scrolls_count = 2 -- Stop on a stack of this many un-ID'd scrolls
  CONFIG.stop_on_pots_count = 3 -- Stop on a stack of this many un-ID'd potions

  -- runrest-features.lua: Runrest features
  CONFIG.ignore_altars = true -- when you have a god already
  CONFIG.ignore_portal_exits = true -- don't stop explore on portal exits
  CONFIG.stop_on_pan_gates = true -- stop explore on pan gates
  CONFIG.temple_macros = true -- auto-search altars; run to exit after worship
  CONFIG.gauntlet_macros = true -- auto-search with filters

  -- safe-consumables.lua
  CONFIG.safe_consumables = true -- Maintain !r and !q on all consumables that need one

  -- safe-stairs.lua: Detect/warn for accidental stair usage
  CONFIG.warn_v5 = true -- Prompt before entering Vaults:5
  CONFIG.warn_stairs_threshold = 5 -- Warn if taking stairs back within # turns; 0 to disable

  -- startup.lua: Startup features
  CONFIG.show_skills_on_startup = true
  CONFIG.auto_set_skill_targets = {
    { "Stealth", 2.0 }, -- First, focus stealth to 2.0
    { "Fighting", 2.0 } -- If already have stealth, focus fighting to 2.0
  } -- auto_set_skill_targets (do not remove this comment)

  -- weapon-slots.lua: Always use a/b/w slots for weapons
  CONFIG.do_auto_weapon_slots_abw = true -- Auto-move weapons to a/b/w slots



  ---- Pickup/Alert system
  ---- This does not affect other autopickup settings; just the buehler Pickup/Alert system
  -- Choose which items are auto-picked up
  CONFIG.pickup = {
    armour = true,
    weapons = true,
    staves = true
  } -- CONFIG.pickup (do not remove this comment)

  -- Which alerts are enabled
  CONFIG.alert = {
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
      "broad axe", "executioner's axe", "eveningstar", "demon whip", "giant spiked club",
      "sacred scourge", "lajatang", "bardiche", "demon trident", "trishula",
      "quick blade", "eudemon blade", "demon blade", "double sword", "triple sword",
      "crystal plate armour", "gold dragon scales", "pearl dragon scales",
      "storm dragon scales", "shadow dragon scales", "wand of digging",
      "triple crossbow", "hand cannon", "buckler", "kite shield", "tower shield"
    }, -- CONFIG.alert.one_time (do not remove this comment)
    
    -- Only do one-time alerts if your skill >= this value, in weap_school/armour/shield
    OTA_require_skill = { weapon = 4, armour = 3, shield = 0 }
  } -- CONFIG.alert (do not remove this comment)

  -- Which alerts generate a force_more
  CONFIG.fm_alert = {
    early_weap = false,
    new_weap = true,
    body_armour = false,
    shields = true,
    aux_armour = false,
    armour_ego = true,
    high_score_weap = false,
    high_score_armour = true,
    one_time_alerts = true,
    artefact = true,
    orbs = false,
    talismans = you.class() == "Shapeshifter", -- True for shapeshifter, false for everyone else
    staff_resists = false
  } -- CONFIG.fm_alert (do not remove this comment)


  -- Heuristics for tuning the pickup/alert system
  TUNING = {}

  -- For armour with different encumbrance, alert when ratio of gain/loss (AC|EV) is > value
  -- Lower values mean more alerts. gain/diff/same/lose refers to egos.
  -- min_gain/max_loss check against the AC or EV delta when ego changes; skip alerts if delta outside limits
  -- ignore_small: separate from AC/EV ratios, if absolute AC+EV loss is <= this, alert any gain/diff ego
  
  TUNING.armour = {
    lighter = {
      gain_ego = 0.6, diff_ego = 0.8, same_ego = 1.2, lost_ego = 2.0,
      min_gain = 3.0, max_loss = 4.0, ignore_small = 3.5
    },
    heavier = {
      gain_ego = 0.4, diff_ego = 0.5, same_ego = 0.7, lost_ego = 2.0,
      min_gain = 3.0, max_loss = 8.0, ignore_small = 5
    },
    encumb_penalty_weight = 0.7, -- Penalizes heavier armour when training spellcasting/ranged. 0 to disable
    early_xl = 6 -- Alert all usable runed body armour if XL <= `early_xl`
  } -- TUNING.armour (do not remove this comment)

  -- All 'magic numbers' used in the weapon pickup/alert system. 2 common types of values:
    -- 1. Cutoffs for pickup/alert weapons (when DPS ratio exceeds a value)
    -- 2. Cutoffs for when alerts are active (XL, skill_level)
    -- Pickup/alert system will try to upgrade ANY weapon in your inventory.
    -- "DPS ratio" is (new_weapon_score / inventory_weapon_score). Score includes DPS/brand/accuracy.
  TUNING.weap = {}
  TUNING.weap.pickup = {
    add_ego = 0.85, -- Pickup weapon that gains a brand if DPS ratio > `add_ego`
    same_type_melee = 1.1, -- Pickup melee weap of same type if DPS ratio > `same_type_melee`
    same_type_ranged = 1.0, -- Pickup ranged weap of same type if DPS ratio > `same_type_ranged`
    accuracy_weight = 0.33 -- Treat +1 Accuracy as +`accuracy_weight` DPS
  } -- TUNING.weap.pickup (do not remove this comment)
  
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
    } -- TUNING.weap.alert.early_ranged (do not remove this comment)
  } -- TUNING.weap.alert (do not remove this comment)



  -- Tune the impact of brands on DPS calc; used to compare weapons and in inscribe-stats.lua
  WEAPON_BRAND_BONUSES = {
    spectralizing = { factor = 1.8, offset = 0 }, -- Fudged down for increased incoming damage
    heavy = { factor = 1.8, offset = 0 }, -- Speed is accounted for elsewhere
    flaming = { factor = 1.25, offset = 0 },
    freezing = { factor = 1.25, offset = 0 },
    draining = { factor = 1.25, offset = 2.0 },
    electrocution = { factor = 1.0, offset = 4.5 }, -- technically 3.5 on avg; fudged up for AC pen
    venom = { factor = 1.0, offset = 5.0 }, -- estimated 5 dmg per poisoning
    pain = { factor = 1.0, offset = you.skill("Necromancy")/2 },
    distortion = { factor = 1.0, offset = 6.0 },
    chaos = { factor = 1.15, offset = 2.0 }, -- Approximate weighted average

    subtle = { -- Completely made up values in attempt to compare weapons fairly
      protection = { factor = 1.15, offset = 0 },
      vampirism = { factor = 1.2, offset = 0 },
      holy_wrath = { factor = 1.15, offset = 0 },
      antimagic = { factor = 1.1, offset = 0 }  
    } -- WEAPON_BRAND_BONUSES.subtle (do not remove this comment)
  } -- WEAPON_BRAND_BONUSES (do not remove this comment)

  -- Cosemtic only
  ALERT_COLORS = {
    weapon = { desc = COLORS.magenta, item = COLORS.yellow, stats = COLORS.lightgrey },
    body_arm = { desc = COLORS.lightblue, item = COLORS.lightcyan, stats = COLORS.lightgrey },
    aux_arm = { desc = COLORS.lightblue, item = COLORS.yellow },
    orb = { desc = COLORS.green, item = COLORS.lightgreen },
    talisman = { desc = COLORS.green, item = COLORS.lightgreen },
    misc = { desc = COLORS.brown, item = COLORS.white },
  } -- ALERT_COLORS (do not remove this comment)

  CONFIG.debug_init = false -- track progress through init()

  if CONFIG.debug_init then crawl.mpr("Initialized config") end
end
