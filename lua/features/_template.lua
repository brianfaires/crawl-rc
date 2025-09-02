--[[
Feature: template_feature
Description: Brief description of what this feature does
Author: Your Name
Dependencies: List any dependencies (e.g., CONFIG, ALL_TRAINING_SKILLS)
--]]

-- Define the feature module here, in the global namespace for auto-loading
f_template = {}
-- Define BRC_FEATURE_NAME to mark it for auto-loading
f_template.BRC_FEATURE_NAME = "template_feature"

-- Define private (local) constants, variables, and functions here

-- Public hooks (Remove any hooks you don't use)
function f_template.init()
    -- Called when feature is registered
end

function f_template.ready()
    -- Called every turn
end

function f_template.c_message(text, channel)
    -- Respond to incoming messages
end

function f_template.c_answer_prompt(prompt)
    -- Respond to prompts (return true/false or nil)
    return nil
end

function f_template.c_assign_invletter(it)
    -- Respond to inventory letter assignment on new item pickup
    return nil
end

function f_template.cleanup()
    -- Called when feature is unregistered
end
