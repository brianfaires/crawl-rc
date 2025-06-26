CONFIG = {}

function init_config()
  CONFIG = {}

  CONFIG.emojis = true -- Use emojis in alerts and damage announcements

  -- Announce HP/MP when change is greater than this value
  CONFIG.ANNOUNCE_HP_THRESHOLD = 1
  CONFIG.ANNOUNCE_MP_THRESHOLD = 0
  -- Flash/Force more for losing this percentage of max HP
  CONFIG.DAMAGE_FLASH_THRESHOLD = 0.20
  CONFIG.DAMAGE_FORCE_MORE_THRESHOLD = 0.30

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

  ---- Pickup/Alert system
  CONFIG.pickup_armour = true
  CONFIG.pickup_weapons = true
  CONFIG.pickup_staves = true

  CONFIG.alert_system_enabled = true
  CONFIG.alert_force_more = true
  CONFIG.alert_armour = true
  CONFIG.alert_weapons = true
  CONFIG.alert_orbs = true
  CONFIG.alert_talismans = true
  CONFIG.alert_staff_resists = true
  CONFIG.alert_one_time_items = true
  CONFIG.one_time_alerts = {
    "broad axe", "executioner's axe", "eveningstar", "demon whip",
    "sacred scourge", "lajatang", "bardiche", "demon trident", "trishula",
    "quick blade", "eudemon blade", "demon blade", "double sword", "triple sword",
    "crystal plate armour", "gold dragon scales", "pearl dragon scales",
    "storm dragon scales", "shadow dragon scales", "wand of digging",
    "triple crossbow", "hand cannon", "buckler", "kite shield", "tower shield"
  } -- one_time_alerts (do not remove this comment)

  -- For armour of diff encumbrance, alert when ratio of gain/loss (AC|EV) is >= value
  -- Lower values mean more alerts. gain/diff/same/lose refers to egos. 
  CONFIG.armour_alert_threshold = {
    lighter = {gain = 0.6, diff = 0.8, same = 1.2, lose = 2 },
    heavier = {gain = 0.4, diff = 0.5, same = 0.7, lose = 2 }
  } -- CONFIG.armour_alert_threshold (do not remove this comment)
  CONFIG.ENCUMB_PENALTY_WEIGHT = 0.7 -- Penalizes heavier armour when training spellcasting/ranged. 0 to disable

  -- Startup
  CONFIG.show_skills_on_startup = true
  CONFIG.auto_set_skill_targets = {
    {"Stealth", 2},
    {"Fighting", 2}
  } -- auto_set_skill_targets (do not remove this comment)

  -- Debugging
  CONFIG.debug_init = true
  CONFIG.debug_dump_data_freq = 1000 -- 0 to disable
  CONFIG.debug_fm_monsters = false -- Set to true to get a message when fm changes

  if CONFIG.debug_init then crawl.mpr("Initialized config") end
end
