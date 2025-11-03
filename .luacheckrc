-- luacheck config for https://github.com/brianfaires/crawl-rc

max_line_length = 100

-- Suppress specific warning types
ignore = {}

-- Allow reading these globals without defining them
read_globals = {
  -- Crawl game engine globals
  "add_autopickup_func",
  "crawl",
  "items",
  "iter",
  "travel",
  "util",
  "view",
  "you",
}

-- Suppress "unused global variable" warnings
globals = {
  -- Crawl hooks
  "c_answer_prompt",
  "c_assign_invletter",
  "c_message",
  "c_persist",
  "chk_force_autopickup",
  "chk_lua_save",
  "ready",

  -- BRC macro functions
  "macro_brc_go_up",
  "macro_brc_downstairs",
  "macro_brc_dump_character",
  "macro_brc_explore",
  "macro_brc_fire",
  "macro_brc_hotkey",
  "macro_brc_save",
  "macro_brc_save_skills_and_config",
  "macro_brc_skip_hotkey",
  "macro_brc_upstairs",
  
  -- BRC global modules
  "BRC",

  -- BRC config modules
  "brc_config_custom",
  "brc_config_explicit",
  "brc_config_speed",
  "brc_config_streak",
  "brc_config_testing",
  "brc_config_turncount",

  -- Feature modules
  "f_alert_monsters",
  "f_announce_hp_mp",
  "f_answer_prompts",
  "f_color_inscribe",
  "f_drop_inferior",
  "f_dynamic_options",
  "f_exclude_dropped",
  "f_fm_disable",
  "f_fully_recover",
  "f_inscribe_stats",
  "f_fix_artefact_inscriptions",
  "f_misc_alerts",
  "f_mute_messages",
  "f_pa_armour",
  "f_pa_data",
  "f_pa_misc",
  "f_pa_weapons",
  "f_pickup_alert",
  "f_remind_id",
  "f_runrest_features",
  "f_safe_consumables",
  "f_safe_stairs",
  "f_startup",
  "f_template",
  "f_quiver_reminders",
  "f_weapon_slots",
  
  -- Persistent variables from BRC.Data.persist()
  "ad_prev",
  "brc_full_persistant_config",
  "brc_config_name",
  "ed_dropped_items",
  "fr_explore_after",
  "fr_start_turn",
  "ma_alerted_max_piety",
  "ma_prev_spell_levels",
  "ma_saved_msg",
  "pa_egos_alerted",
  "pa_high_score",
  "pa_items_alerted",
  "pa_lowest_hands_alerted",
  "pa_OTA_items",
  "pa_recent_alerts",
  "ri_found_scroll_of_id",
  "ri_max_potion_stack",
  "ri_max_scroll_stack",
  "rr_autosearched_gauntlet",
  "rr_autosearched_temple",
  "rr_shaft_location",
  "ss_cur_location",
  "ss_last_stair_turn",
  "ss_prev_location",
  "ss_v5_warned",
  "persistent_bool",
  "persistent_int",
  "persistent_list",
  "persistent_map",

}
