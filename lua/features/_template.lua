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

-- Define local (private) constants and configuration

-- Define local (private) variables. Recommended to only use init() for setting their initial values.

-- Define private (local) functions here

-- Public hooks (Remove any hooks you don't use)
function f_template.init()
  -- Set up local state or one-time startup tasks
end

function f_template.ready()
  -- Do something every turn
end

function f_template.c_message(text, channel)
  -- Respond to incoming messages
  crawl.mpr("echo: " .. text, channel)
end

function f_template.c_answer_prompt(prompt)
  -- Respond to prompts (return true/false or nil)
  if prompt == "Do you want to live?" then return true end
  return nil
end

function f_template.c_assign_invletter(it)
  -- Respond to inventory letter assignment on new item pickup
  if it.name == "Item for slot b" then return 3 end
  return nil
end

function f_template.cleanup()
  -- Do stuff when feature is unregistered
end
