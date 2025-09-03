-- Luacheck configuration file
-- Global variables that are allowed in this project
globals = {
    -- Crawl-specific globals
    "crawl",
    "you",
    "view",
    "items",
    "monsters",
    "dungeon",
    "game",
    
    -- Common Lua globals that might be used
    "require",
    "package",
    "string",
    "table",
    "math",
    "io",
    "os",
    "debug",
    "coroutine",
    "utf8"
}

-- Ignore specific warning types
ignore = {
    "111",  -- setting non-standard global variable
    "113"   -- accessing undefined variable
}

-- Allow defining globals implicitly
allow_defined = true

-- Allow defining globals in top level scope
allow_defined_top = true

-- Maximum line length
max_line_length = 120

-- Show warning codes
codes = true

-- Use plain formatter to avoid color codes
formatter = "plain"

-- Exclude certain files/directories if needed
-- exclude_files = {"*.min.lua", "vendor/*"}
