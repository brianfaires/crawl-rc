---------------------------------------------------------------------------------------------------
-- BRC feature module: template_feature
-- @module f_template
-- @author Your Name
-- Description of what this feature does.
---------------------------------------------------------------------------------------------------

-- Core definitions: module, feature name, and config
f_template = {}
f_template.BRC_FEATURE_NAME = "template_feature"
f_template.Config = {
  example_boolean = true,
  example_number = 42,
  example_list = { "Done exploring.", "A gnoll comes into view." },
  example_map = {
    key1 = 1,
    key2 = 2,
    ["100"] = "value for key=100",
  }, -- Include comma or comment after a lone "}" to avoid RC parser errors
} -- f_template.Config (Always add a comment to a line with only "}"). Or crawl's RC parser breaks

---- Persistent variables ---- (Defined globally, so give them unique names)
persistent_int = BRC.Data.persist("persistent_int", 0)
persistent_bool = BRC.Data.persist("persistent_bool", false)
persistent_list = BRC.Data.persist("persistent_list", {})
persistent_map = BRC.Data.persist("persistent_map", {})

---- Local config alias ---- (Optional local alias, for more concise code)
local Config = f_template.Config

---- Local constants ----
local CONSTANT_STRING = "Hand Weapons"

---- Local variables ----
-- Declare locals, but initialize their values in init()
local local_var
local local_table

---- Local functions ----

-- Public hook functions (Remove any hooks you don't use)
function f_template.init()
  -- Called when game opens
  local_var = CONSTANT_STRING
  local_table = { local_var }

  persistent_int = persistent_int + 1
  persistent_map.num_startups = persistent_int

  if Config.example_boolean then BRC.mpr.debug("Template feature initialized.") end
end

function f_template.ready()
  -- Called at the start of each turn
  if you.turns() == Config.example_number then BRC.mpr.blue("Hit magic number!") end
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
  if util.contains(local_table, it.class()) then return 0 end -- Equipment slot 'a'
  return nil
end
