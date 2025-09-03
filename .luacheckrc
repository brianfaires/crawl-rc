-- luacheck configuration file for crawl-rc project
-- This file tells luacheck which globals are intentionally defined

-- Suppress "unused global variable" warnings for crawl engine globals
globals = {
    -- Crawl game engine globals
    "add_autopickup_func",
    "crawl",
    "you",
    "items",
    "view",
    "iter",
    "util",

    -- Crawl hooks (intentionally global)
    "ready",
    "c_message",
    "c_assign_invletter",
    "c_answer_prompt",
    "chk_force_autopickup",
    "chk_lua_save",

    -- Macro functions (intentionally global)
    "macro_do_safe_upstairs",
    "macro_do_safe_downstairs",
    "macro_exploore_fully_recover",
    "macro_save_with_message",
    
    -- BRC module globals (intentionally global)
    "BRC",
    
    -- Feature module globals (intentionally global)
    "f_pickup_alert",
    "f_pickup_alert_misc",
    "f_pickup_alert_data",
    "f_pickup_alert_weapons",
    "f_pickup_alert_armour",
    "f_exclude_dropped",
    "f_weapon_slots",
    "f_inscribe_stats",
    "f_fm_monsters",
    
    -- Configuration and constants (intentionally global)
    "CONFIG",
    "COLORS",
    "EMOJI",
    "TUNING",
    "MUTS",
    "ALL_STAFF_SCHOOLS",
    "RISKY_EGOS",
    "ALL_POIS_RES_RACES",
    "ALL_UNDEAD_RACES",
    "ALL_NONLIVING_RACES",
    "ALL_HELL_BRANCHES",
    "ALL_WEAP_SCHOOLS",
    "ALL_MISC_ITEMS",
    "ALL_MISSILES",
    "ALL_LITTLE_RACES",
    "ALL_SMALL_RACES",
    "ALL_LARGE_RACES",
    "SIZE_PENALTY",
    "DMG_TYPE",
    "WEAPON_BRAND_BONUSES",
    "PLAIN_DMG_EGOS",
    "ARMOUR_ALERT",
    "WEAP_CACHE",
    "pa_OTA_items",
    "pa_recent_alerts",
    "pa_items_picked",
    "pa_items_alerted",
    "ac_high_score",
    "weapon_high_score",
    "plain_dmg_high_score",
    "dropped_item_exclusions",

    -- BRC Functions (intentionally global)
    "add_exclusion",
    "remove_exclusion",
    "get_OTA_index",
    "remove_from_OTA",
    "add_to_pa_table",
    "already_contains",
    "get_ego",
    "get_armour_info_strings",
    "get_weapon_info_string",
    "get_pa_keys",
    "get_plussed_name",
    "has_ego",
    "get_unadjusted_armour_pen",
    "get_adjusted_armour_pen",
    "get_adjusted_dodge_bonus",
    "get_armour_ac",
    "get_armour_ev",
    "get_shield_penalty",
    "get_shield_sh",
    "get_weap_delay",
    "get_weap_min_delay",
    "get_weap_dps",
    "get_weap_damage",
    "get_weap_score",
    "get_hands",
    "get_skill",
    "get_slay_bonuses",
    "get_staff_bonus_dmg",
    "get_size_penalty",
    "adjust_delay_for_ego",
    "is_weapon_upgrade",
    "need_first_weapon",
    "alert_first_of_skill",
    "alert_early_weapons",
    "alert_interesting_weapon",
    "alert_interesting_weapons",
    "alert_weap_high_scores",
    "pa_alert_item",
    "pa_alert_OTA",
    "pa_alert_staff",
    "pa_alert_talisman",
    "pa_alert_orb",
    "pa_alert_armour",
    "pa_alert_weapon",
    "pa_pickup_armour",
    "pa_pickup_staff",
    "pa_pickup_weapon",
    "pickup_body_armour",
    "pickup_shield",
    "pickup_aux_armour",
    "alert_body_armour",
    "alert_shield",
    "alert_aux_armour",
    "send_armour_alert",
    "is_new_ego",
    "should_alert_body_armour",
    "alert_ac_high_score",
    "get_ego_change_type",
    "get_adjusted_ev_delta",
    "is_unneeded_ring",
    "update_high_scores",
    "format_stat",
    
    -- Variables (intentionally global)
    "prev_turn",
    "do_more",
    "active_fm",
    "active_fm_index",
    "monsters_to_mute",
    "last_fm_turn",
    "priorities_ab",
    "priorities_w",
    "top_attack_skill",
    "slots_changed",
    "do_cleanup_weapon_slots",
    "loaded_pa_armour",
    "loaded_pa_misc",
    "loaded_pa_weapons",
    "pause_pa_system"
}

-- Suppress specific warning types
ignore = {
    "W113"   -- accessing undefined variable
}

-- Suppress "unused function argument" warnings for callback functions
unused_args = false

-- Suppress "unused loop variable" warnings for iterator loops
unused_loop_vars = false

-- Allow unused variables in specific contexts
allow_defined_top = true

-- Set reasonable line length limit
max_line_length = 120

-- Suppress "indentation" warnings (crawl code style)
no_trailing_spaces = false
no_tabs = false

-- Suppress "empty block" warnings (some functions are intentionally empty)
no_empty_blocks = false

-- Suppress "redundant whitespace" warnings
no_spaces = false
no_semicolons = false

-- Suppress "unbalanced assignments" warnings
no_balanced_assignments = false

-- Suppress "global variable written" warnings for intentionally global variables
no_global = false
