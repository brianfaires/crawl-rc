BRC = {}

--- All other configs start with these values
BRC.Config = {
  emojis = false, -- Include emojis in alerts

  --- Specify which config (defined below) to use, or how to choose one.
  --   "<config name>": Use the named config
  --   "ask": Prompt at start of each new game
  --   "previous": Keep using the last config
  use_config = "ask",

  --- For local games, use store_config to a different configs across multiple characters.
  --   "none": Normal behavior: Read use_config, and load it from the RC.
  --   "name": Remember the config name and reload it from the RC. Ignore new values of use_config.
  --   "full": Remember the config and all of its values. Ignore RC changes.
  store_config = "none",
} -- BRC.Config (do not remove this comment)
