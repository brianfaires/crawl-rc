if loaded_lua_config_file then return end
loaded_lua_config_file = true
CONFIG = { }

-- Announce damage emojis
CONFIG.emojis = true

-- Inscribe stats
CONFIG.inscribe_weapons = true
CONFIG.inscribe_armour = true

-- Runrest features
CONFIG.ignore_altars = true
CONFIG.ignore_portal_exits = true
CONFIG.ignore_gauntlet_msgs = true
CONFIG.stop_on_pan_gates = true
CONFIG.search_altars_in_temple = true

-- Misc alerts
CONFIG.alert_remove_faith = true
CONFIG.alert_low_hp_threshold = 0.5 -- % max HP to alert; 0 to disable
CONFIG.annotate_v5 = true
CONFIG.save_with_msg = true

---- Pickup/Alert system
CONFIG.pickup_armour = true
CONFIG.pickup_weapons = true
CONFIG.pickup_staves = true

CONFIG.alert_system_enabled = true
CONFIG.alert_armour = true
CONFIG.alert_weapons = true
CONFIG.alert_orbs = true
CONFIG.alert_talismans = true
CONFIG.alert_staff_resists = true
CONFIG.alert_one_time_items = true
one_time_alerts = {
  "broad axe", "executioner's axe", "eveningstar", "demon whip",
  "sacred scourge", "lajatang", "bardiche", "demon trident", "trishula",
  "quick blade", "demon blade", "double sword", "triple sword", "eudemon blade",
  "crystal plate armour", "gold dragon scales", "pearl dragon scales",
  "storm dragon scales", "shadow dragon scales", "wand of digging",
  "triple crossbow", "hand cannon", "buckler", "kite shield", "tower shield"
} -- one_time_alerts (do not remove this comment)

-- Startup
CONFIG.show_skills_on_startup = true
CONFIG.auto_set_skill_targets = {
  {"Stealth", 2},
  {"Fighting", 2}
} -- auto_set_skill_targets (do not remove this comment)