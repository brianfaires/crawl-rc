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
    -- BRC macro functions
    "macro_brc_dump_character",
    "macro_f_fully_recover_explore",
    "macro_f_misc_alerts_save_with_message",
    "macro_f_safe_stairs_down",
    "macro_f_safe_stairs_up",
}

globals = {
    -- Crawl hooks
    "ready",
    "c_message",
    "c_assign_invletter",
    "c_answer_prompt",
    "chk_force_autopickup",
    "chk_lua_save",
    -- BRC macro functions
    "macro_brc_dump_character",
    "macro_f_fully_recover_explore",
    "macro_f_misc_alerts_save_with_message",
    "macro_f_safe_stairs_down",
    "macro_f_safe_stairs_up",

    
    -- BRC module globals
    "BRC",

    -- Configuration and constants
    "CONFIG",
    "TUNING",
    "WEAP_CACHE",

}

-- Suppress specific warning types
ignore = {
    "unused global variable macro_brc_dump_character",
    "unused global variable macro_f_fully_recover_explore", 
    "unused global variable macro_f_misc_alerts_save_with_message",
    "unused global variable macro_f_safe_stairs_down",
    "unused global variable macro_f_safe_stairs_up",
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
