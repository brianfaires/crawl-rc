BRC = {}
BRC.Config = {}

---- High-level config settings ----
BRC.Config.emojis = false -- Only defined here; can't be set in a config profile

--- BRC.use_config: Specify which config to use, or how to select it.
-- "<config name>": Use the named config
-- "ask": Prompt at start of each new game
-- "previous": Keep using the last config
BRC.use_config = "ask"

-- BRC.store_config: Each game tracks the config being used, ignoring changes in the RC.
-- "none": Always reload "BRC.use_config" from current RC
-- "name": Remember the config name, and reload its values from the RC
-- "full": Remember the config and all of its values
BRC.store_config = "none"
