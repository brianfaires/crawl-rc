--[[
Feature: template_feature
Description: Brief description of what this feature does
Author: Your Name
Dependencies: List any dependencies (e.g., BRC.data)
--]]

-- Global definitions: feature module, name, and config
f_template = {}
f_template.BRC_FEATURE_NAME = "template_feature"
f_template.Config = {
  example_boolean = true,
  example_number = 42,
  example_list = { "Done exploring.", "A gnoll comes into view." },
  example_dict = {
    key1 = 1,
    key2 = 2,
    ["100"] = "value for key=100",
  },
} -- f_template.Config (Always add a comment to a line only containing "}"), or crawl's RC parser will break

-- Persistent variables (Defined globally, so give them unique names)
persistent_int = BRC.data.persist("persistent_int", 0)
persistent_bool = BRC.data.persist("persistent_bool", false)
persistent_list = BRC.data.persist("persistent_list", {})
persistent_dict = BRC.data.persist("persistent_dict", {})

-- Local config (Optional local alias, for more concise code)
local Config = f_template.Config

-- Local constants
-- Local variables
-- Local functions

-- Public hook functions (Remove any hooks you don't use)
function f_template.init()
  -- Called when game opens
  persistent_int = persistent_int + 1
  persistent_dict.num_startups = persistent_int

  if Config.example_boolean then
    BRC.log.debug("Template feature initialized.")
  end
end

function f_template.ready()
  -- Called at the start of each turn
  if you.turns() == Config.example_number then
    BRC.mpr.blue("Hit magic number!")
  end
end

function f_template.c_message(text, channel)
  -- React to incoming messages
  crawl.mpr(string.format("Got message: '%s' on channel %s", text, channel), channel)
end

function f_template.c_answer_prompt(prompt)
  -- Respond to prompts (return true/false or nil)
  if util.contains(persistent_list, prompt) then return true end
  return nil -- Don't answer
end

function f_template.c_assign_invletter(it)
  -- Inventory letter assignment; fires on every pickup of a new item
  if it.name() == "Item for slot d" then return 3 end
  return nil
end
