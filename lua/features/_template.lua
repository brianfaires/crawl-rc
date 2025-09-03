--[[
Feature: _template
Description: Template for new features
Author: buehler
Dependencies: CONFIG
--]]

-- Define the feature module here, in the global namespace for auto-loading
f_template = {}
-- Define BRC_FEATURE_NAME to mark it for auto-loading
f_template.BRC_FEATURE_NAME = "template_feature"

-- Define persistent variables globally
template_counter = BRC.data.create("template_counter", 0)
template_flag = BRC.data.create("template_flag", false)
template_list = BRC.data.create("template_list", {})
template_dict = BRC.data.create("template_dict", {})

-- Define local (private) constants and configuration

-- Define local (private) variables. Recommended to only use init() for setting their initial values.

-- Define private (local) functions here
-- Hook functions
function f_template.init()
  -- Called when the feature is registered; once on startup.
  template_counter = template_counter + 1
  
  BRC.debug("Template feature initialized, counter: " .. template_counter)
end

function f_template.ready()
  -- Called at the start of each turn
  if not template_flag then
    template_flag = true
  end
end

function f_template.c_message(text, channel)
  -- Respond to incoming messages
  crawl.mpr("echo: " .. text, channel)
end

function f_template.c_answer_prompt(prompt)
  -- Respond to prompts (return true/false or nil)
  if prompt == "Do you want to live?" then return true end
  return nil -- Abstain from answering
end

function f_template.c_assign_invletter(it)
  -- Respond to inventory letter assignment on new item pickup
  if it.name() == "Item headed for slot b" then return 3 end
  return nil
end

function f_template.cleanup()
  -- Do stuff when feature is unregistered
  template_flag = false
end
