-- luacheck configuration file for crawl-rc project

-- Suppress "unused global variable" warnings
read_globals = {
    -- Crawl game engine globals
    "crawl",
    "add_autopickup_func",
    "you",
    "items",
    "view",
    "iter",
    "util",
}

globals = {
    -- Crawl hooks
    "ready",
    "c_message",
    "c_assign_invletter",
    "c_answer_prompt",
    "chk_force_autopickup",
    "chk_lua_save",
    
    -- BRC module globals
    "BRC",

    -- Configuration and constants
    "CONFIG",
    "COLORS",
    "EMOJI",
    "KEYS",
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

}

-- Suppress specific warning types
ignore = {
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
