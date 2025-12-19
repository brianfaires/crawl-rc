---------------------------------------------------------------------------------------------------
-- BRC core module
-- @module BRC.Configs
-- Manages user-defined configs and feature config overrides.
--
-- TL;DR: Each feature has its own config, with default values for every field.
--   To change those values, define the same fields in a user-defined config.
--
-- When a user-defined config is loaded, it inherits values from BRC.Configs.Default.
-- If a user-defined config defines a field, that value is used.
--   If not defined in the config, the value in BRC.Configs.Default is used.
--   If not defined in either, the default value in the feature config is used.
-- @warning BRC.Configs.Default defines all fields not in a feature config. Do not remove them.
---------------------------------------------------------------------------------------------------

BRC.Configs = {}

---- Persistent variables ----
brc_full_persistant_config = BRC.Data.persist("brc_full_persistant_config", nil)
brc_config_name = BRC.Data.persist("brc_config_name", nil)

---- BRC Default Config - Every user-defined config inherits these
-- Define config fields that aren't feature-specific, and set their default values

BRC.Configs.Default = util.copy_table(BRC.Config) -- Include values from BRC.Config in _header.lua
BRC.Configs.Default.BRC_CONFIG_NAME = "Default"

BRC.Configs.Default.emojis = true -- Include emojis in alerts

-- Does "Armour of <MagicSkill>" have an ego when skill is 0?
BRC.Configs.Default.unskilled_egos_usable = false

BRC.Configs.Default.mpr = {
  show_debug_messages = false,
  logs_to_stderr = false,
} -- BRC.Configs.Default.mpr (do not remove this comment)

BRC.Configs.Default.dump = {
    max_lines_per_table = 200, -- Avoid huge tables (alert_monsters.Config.Alerts) in debug dumps
    omit_pointers = true, -- Don't dump functions and userdata (they only show a hex address)
} -- BRC.Configs.Default.dump (do not remove this comment)

--- How weapon damage is calculated for inscriptions+pickup/alert: (factor * DMG + offset)
BRC.Configs.Default.BrandBonus = {
  chaos = { factor = 1.15, offset = 2.0 }, -- Approximate weighted average
  distort = { factor = 1.0, offset = 6.0 },
  drain = { factor = 1.25, offset = 2.0 },
  elec = { factor = 1.0, offset = 4.5 },   -- 3.5 on avg; fudged up for AC pen
  entangle = { factor = 1.1, offset = 3 },
  flame = { factor = 1.25, offset = 0 },
  freeze = { factor = 1.25, offset = 0 },
  heavy = { factor = 1.8, offset = 0 },    -- Speed is accounted for elsewhere
  pain = { factor = 1.0, offset = you.skill("Necromancy") / 2 },
  spect = { factor = 1.7, offset = 0 },    -- Fudged down for increased incoming damage
  sunder = { factor = 1.2, offset = 0 },
  valour = { factor = 1.15, offset = 0 },
  venom = { factor = 1.0, offset = 5.0 },  -- 5 dmg per poisoning

  subtle = { -- Values to use for weapon "scores" (not damage)
    antimagic = { factor = 1.1, offset = 0 },
    concuss = { factor = 1.2, offset = 0 },
    devious = { factor = 1.1, offset = 0 },
    holy = { factor = 1.15, offset = 0 },
    penet = { factor = 1.3, offset = 0 },
    protect = { factor = 1.15, offset = 0 },
    reap = { factor = 1.3, offset = 0 },
    rebuke = { factor = 1.2, offset = 0 },
    vamp = { factor = 1.2, offset = 0 },
  },
} -- BRC.Configs.Default.BrandBonus (do not remove this comment)

---- Local functions ----
local function is_config_module(p)
  return p
    and type(p) == "table"
    and p.BRC_CONFIG_NAME
    and type(p.BRC_CONFIG_NAME) == "string"
    and #p.BRC_CONFIG_NAME > 0
end

local function find_config_modules()
  for _, c in pairs(_G) do
    if is_config_module(c) then BRC.Configs[c.BRC_CONFIG_NAME] = c end
  end
end

--- @param input_name string "ask" or a config name
-- @return string The valid name of a config
local function get_valid_config_name(input_name)
  if #BRC.Configs == 1 then return util.keys(BRC.Configs)[1] end

  if type(input_name) ~= "string" then
    BRC.mpr.warning("Non-string config name: " .. tostring(input_name))
  else
    local config_name = input_name:lower()
    if config_name == "ask" then
      -- If game has started, restore from the previously saved config name
      if you.turns() > 0 and brc_config_name then
        return get_valid_config_name(brc_config_name)
      end
    else
      -- Find by name in BRC.Configs, or display warning
      for k, _ in pairs(BRC.Configs) do
        if config_name == k:lower() then return k end
      end
      BRC.mpr.warning("Could not load config: " .. tostring(input_name))
    end
  end

  local config_names = util.keys(BRC.Configs)
  util.sort(config_names)
  return BRC.mpr.select("Select a config", config_names)
end

local function execute_config_init(config)
  if type(config) ~= "table" then return end
  if type(config.init) == "function" then
    config.init()
  end
end

--- Override values in dest, with values from source. Take care not to clear existing tables.
-- Does not override "init"
local function override_table(dest, source)
  if type(source) ~= "table" then return end

  for key, value in pairs(source) do
    if BRC.util.is_map(value) then
      if not dest[key] then dest[key] = {} end
      override_table(dest[key], value)
    else
      dest[key] = value
    end
  end
end

---- Public API ----
--- Main config loading entry point
-- @param config_name string name of a config
function BRC.init_config(config_name)
  find_config_modules()
  BRC.Config = util.copy_table(BRC.Configs.Default)
  local name = get_valid_config_name(config_name or BRC.Config.to_use)
  if BRC.Configs[brc_config_name] and (name ~= brc_config_name) and you.turns() > 0 then
    if not BRC.mpr.yesno(string.format(
      "Switch config from %s to %s?",
      BRC.txt.lightcyan(brc_config_name),
      BRC.txt.lightcyan(name)
    )) then
      name = brc_config_name
    end
  end

  override_table(BRC.Config, BRC.Configs[name])
  execute_config_init(BRC.Config)

  for _ , value in pairs(BRC.get_registered_features()) do
    BRC.process_feature_config(value)
  end

  brc_config_name = name
  local m = BRC.mpr.brc_prefix .. "Using config: " .. BRC.txt.lightcyan(BRC.Config.BRC_CONFIG_NAME)
  BRC.mpr.white(m)
  BRC.init_emojis() -- Updates constant values based on BRC.Config.emojis
end

--- Process a feature config: Load defaults, then override w BRC.Config
function BRC.process_feature_config(feature)
  if type(feature.ConfigDefaults) == "table" then
    feature.Config = util.copy_table(feature.ConfigDefaults)
  else
    -- Save the defaults after default init(), so they can be used later w a diff config
    feature.Config = feature.Config or {}
    local preinit_defaults = util.copy_table(feature.Config)
    execute_config_init(feature.Config)
    feature.ConfigDefaults = util.copy_table(feature.Config)

    -- If init() is overridden, restore to the pre-init defaults and only apply the new init()
    if type(BRC.Config[feature.BRC_FEATURE_NAME].init) == "function" then
      feature.Config = util.copy_table(preinit_defaults)
    end
  end

  override_table(feature.Config, BRC.Config[feature.BRC_FEATURE_NAME])
  execute_config_init(BRC.Config[feature.BRC_FEATURE_NAME])
end

--- Stringify BRC.Config and each feature config, with headers
-- @return table of strings, one for each config section (1 big string will overflow crawl.mpr())
function BRC.serialize_config()
  local tokens = {}
  tokens[#tokens + 1] = BRC.txt.lightcyan("\n---BRC Config---\n") .. BRC.txt.tostr(BRC.Config, true)

  local all_features = BRC.get_registered_features()
  local keys = util.keys(all_features)
  util.sort(keys)

  for i = 1, #keys do
    local name = keys[i]
    local feature = all_features[name]
    if feature.Config then
      local header = BRC.txt.cyan("\n\n---Feature Config: " .. name .. "---\n")
      tokens[#tokens + 1] = header .. BRC.txt.tostr(feature.Config, true)
    end
  end

  return tokens
end

---- Initialize BRC.Config for debugging during startup + data.persist() calls ----
override_table(BRC.Config, BRC.Configs.Default)
