-- BRC Initialization System
-- Replaces the old init_buehler function with the new modular system

-- Initialize the BRC system
function init_brc_system(reset_persistent_data)
    if CONFIG and CONFIG.debug_init then
        crawl.mpr("Initializing BRC system")
    end
    
    -- Initialize core modules first (these are required)
    init_config()
    init_emojis()
    init_util()
    init_persistent_data(reset_persistent_data)
    
    -- Load and register all features with BRC
    local loader_success = FEATURE_LOADER.load_features()
    
    if not loader_success then
        crawl.mpr(with_color(COLORS.lightred, "Failed to load features. BRC system is inactive."))
        return false
    end
    
    -- Success!
    local success_emoji = CONFIG.emojis and EMOJI.SUCCESS or ""
    local success_text = string.format(" Successfully initialized BRC system v%s! ", BRC:get_version())
    crawl.mpr("\n" .. success_emoji .. with_color(COLORS.lightgreen, success_text) .. success_emoji)
    
    -- Log loaded features
    local loaded_features = FEATURE_LOADER.get_loaded_features()
    local feature_count = 0
    for _ in pairs(loaded_features) do
        feature_count = feature_count + 1
    end
    
    if CONFIG.debug_init then
        crawl.mpr(string.format("Loaded %d features", feature_count))
        for feature_name, _ in pairs(loaded_features) do
            crawl.mpr(string.format("  - %s", feature_name))
        end
    end
    
    return true
end

-- Hook functions that delegate to BRC
function ready()
    if BRC then BRC:ready() end
end

function ch_message(text, channel)
    if BRC then BRC:ch_message(text, channel) end
end

function c_answer_prompt(prompt)
    if BRC then BRC:c_answer_prompt(prompt) end
end

-- Backward compatibility: Keep the old function name
function init_buehler(reset_persistent_data)
    return init_brc_system(reset_persistent_data)
end
