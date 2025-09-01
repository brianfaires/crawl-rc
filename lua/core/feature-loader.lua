-- Feature Loader for BRC
-- Automatically discovers and loads feature modules
-- Supports both multi-file and single-file compilation modes

-- Global feature loader table
FEATURE_LOADER = {}

-- Private state
local _loaded_features = {}
local _feature_modules = {}

-- Private helper functions
local function _log_info(message)
    crawl.mpr(string.format("[BRC Loader] %s", message), "lightgrey")
end

local function _is_feature_module(module_table)
    -- Check if the module has the BRC feature name defined
    return module_table and module_table.BRC_FEATURE_NAME and type(module_table.BRC_FEATURE_NAME) == "string"
end

-- Public API
function FEATURE_LOADER.discover_features()
    -- Discover features from global namespace
    local features = {}
    
    -- Scan the global namespace for feature modules
    for name, value in pairs(_G) do
        if type(value) == "table" and _is_feature_module(value) then
            features[module_table.BRC_FEATURE_NAME] = {
                module = value,
                source = "global",
                name = name
            }
        end
    end
    
    return features
end

function FEATURE_LOADER.load_features()
    if not BRC then
        crawl.mpr("[BRC Loader Error] BRC instance required for feature loading", "lightred")
        return false
    end
    
    -- Discover available features
    local discovered_features = FEATURE_LOADER.discover_features()
    
    -- Load and register each feature
    for feature_name, feature_info in pairs(discovered_features) do
        local success = BRC:register_feature(feature_name, feature_info.module)
        
        if success then
            _loaded_features[feature_name] = feature_info
            _log_info(string.format("Loaded feature: %s (%s)", feature_name, feature_info.source))
        else
            BRC:log_error(string.format("Failed to register feature: %s", feature_name))
        end
    end
    
    return true
end

function FEATURE_LOADER.get_loaded_features()
    return _loaded_features
end

function FEATURE_LOADER.reload_feature(feature_name)
    if not BRC then
        crawl.mpr("[BRC Loader Error] BRC instance required for feature reloading", "lightred")
        return false
    end
    
    local feature_info = _loaded_features[feature_name]
    if not feature_info then
        BRC:log_error(string.format("Feature '%s' is not loaded", feature_name))
        return false
    end
    
    -- Unregister the old feature
    BRC:unregister_feature(feature_name)
    
    -- For global features, we can't easily reload them
    BRC:log_error("Global feature reloading not yet implemented")
    
    return false
end
