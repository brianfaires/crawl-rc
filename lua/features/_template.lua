--[[
Feature: _template
Description: Brief description of what this feature does
Author: Your Name
Dependencies: List any dependencies (e.g., BRC.data)
--]]

-- Define the feature module here, in the global namespace for auto-loading
f_template = {}
-- Define BRC_FEATURE_NAME to mark it for auto-loading
f_template.BRC_FEATURE_NAME = "template_feature"

-- Define persistent variables globally (use unique names)
template_counter = BRC.data.create("template_counter", 0)
template_flag = BRC.data.create("template_flag", false)
template_list = BRC.data.create("template_list", {})
template_dict = BRC.data.create("template_dict", {})

-- Define local (private) constants and configuration

-- Define local (private) variables. Recommended to only use init() for setting their initial values.
local my_name

-- Define local (private) functions here

-- Public hook functions (Remove any hooks you don't use)
function f_template.init()
  -- Init local vars, and other one-time startup tasks
  my_name = "be" .. string.rep("u", template_counter) .. "hler"
end

function f_template.ready()
  -- Called at the start of each turn
  template_counter = template_counter + 1
  template_flag = not template_flag
  template_dict.num_startups = template_counter
end

function f_template.c_message(text, channel)
  -- React to incoming messages
  crawl.mpr(my_name .. " got the message: " .. text, channel)
end

function f_template.c_answer_prompt(prompt)
  -- Respond to prompts (return true/false or nil)
  if util.contains(template_list, prompt) then return true end
  return nil -- Abstain from answering
end

function f_template.c_assign_invletter(it)
  -- Inventory letter assignment; fires on every pickup of a new item
  if it.name() == "Item headed for slot b" then return 3 end
  return nil
end

function f_template.cleanup()
  -- Do stuff when feature is unregistered
  template_dict = nil
end
