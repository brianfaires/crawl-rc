-- Feature Module Template
-- This file shows the proper structure for feature modules in the BRC system
-- Copy this file and modify it for your new features

-- Feature metadata (optional but recommended)
local FEATURE_META = {
    name = "template_feature",
    version = "1.0.0",
    description = "A template feature showing the proper structure",
    author = "Your Name",
    dependencies = {} -- List any dependencies here
}

-- Local variables and state
local local_state = {}

-- Feature module table
local template_feature = {}

-- IMPORTANT: Set the BRC feature name to identify this as a feature module
-- This serves as both the identification flag and the feature name
template_feature.BRC_FEATURE_NAME = "template_feature"

-- Required: Initialize function
-- This is called when the feature is registered with BRC
function template_feature.init()
    -- Initialize your feature here
    -- Set up any necessary state, event handlers, etc.
    
    if CONFIG and CONFIG.debug_init then 
        crawl.mpr("Initializing template feature") 
    end
    
    -- Example: Set up local state
    local_state.initialized = true
    local_state.some_value = 0
    
    -- Example: Register with BRC (this would be done by the loader)
    -- BRC:register_feature("template_feature", template_feature)
end

-- Optional: Ready function
-- Called every turn via the ready() hook
function template_feature.ready()
    -- Your per-turn logic here
    -- This replaces the old ready_template_feature() pattern
    
    -- Example: Do something every turn
    if local_state.initialized then
        -- Your logic here
    end
end

-- Optional: Message handling function
-- Called when messages arrive via the ch_message() hook
function template_feature.ch_message(text, channel)
    -- Handle incoming messages
    -- This replaces the old c_message_template_feature() pattern
    
    -- Example: React to specific messages
    if text:find("template", 1, true) then
        -- Handle template-related messages
    end
end

-- Optional: Prompt handling function
-- Called when prompts arrive via the c_answer_prompt() hook
function template_feature.c_answer_prompt(prompt)
    -- Handle prompts
    -- This replaces the old c_answer_prompt_template_feature() pattern
    
    -- Example: Auto-answer specific prompts
    if prompt:find("template", 1, true) then
        return true -- or false, or nil for no action
    end
    
    return nil -- Don't handle this prompt
end

-- Optional: Cleanup function
-- Called when the feature is unregistered
function template_feature.cleanup()
    -- Clean up any resources, event handlers, etc.
    local_state.initialized = false
    local_state.some_value = nil
end

-- Optional: Configuration function
-- Called to get feature-specific configuration
function template_feature.get_config()
    return {
        enabled = true,
        some_setting = "default_value"
    }
end

-- The feature module is now available as template_feature
-- It will be automatically discovered and registered by the feature loader
-- because it has BRC_FEATURE_NAME defined
