---------------------------------------------------------------------------------------------------
-- BRC core module
-- @module BRC.Profiles
-- Manages config profiles and feature config overrides.
--
-- TL;DR: Each feature defines its own config, including default values for each field.
--   Define the same fields in a config profile to override the default value.
--
-- When a config profile loads, it is applied on top of BRC.Profiles.Default.
-- If a profile defines a field, that value is used.
--   If not defined in the profile, the value in BRC.Profiles.Default is used.
--   If not defined in either, the default value from the feature config is used.
-- @warning BRC.Profiles.Default defines all fields not in a feature config. Do not remove them.
--
-- @usage: Adding a field in BRC.Profiles.Default will apply to all config profiles.
--   Ex: To disable the color-inscribe feature in all profiles, add this to BRC.Profiles.Default:
--     ["color-inscribe"] = { disabled = true }
---------------------------------------------------------------------------------------------------

BRC.Profiles = {}

---- Persistent variables ----
brc_full_persistant_config = BRC.Data.persist("brc_full_persistant_config", nil)
brc_profile_name = BRC.Data.persist("brc_profile_name", nil)

--- BRC Default Profile - (defines default values for everything not in a feature config)
-- Profile configs are applied on top of this.
BRC.Profiles.Default = {
  emojis = BRC.Config.emojis, -- Follow the value in _header.lua
  mpr = {
    show_debug_messages = false,
    debug_to_stderr = false,
  },

  dump = {
    max_lines_per_table = 200, -- Avoid huge tables (alert_monsters.Config.Alerts) in debug dumps
    omit_pointers = true, -- Don't dump functions and userdata (they only show a hex address)
  },

  unskilled_egos_usable = false, -- Does "Armour of <MagicSkill>" have an ego when skill is 0?

  --- How weapon damage is calculated for inscriptions+pickup/alert: (factor * DMG + offset)
  BrandBonus = {
    chaos = { factor = 1.15, offset = 2.0 }, -- Approximate weighted average
    distort = { factor = 1.0, offset = 6.0 },
    drain = { factor = 1.25, offset = 2.0 },
    elec = { factor = 1.0, offset = 4.5 },   -- 3.5 on avg; fudged up for AC pen
    flame = { factor = 1.25, offset = 0 },
    freeze = { factor = 1.25, offset = 0 },
    heavy = { factor = 1.8, offset = 0 },    -- Speed is accounted for elsewhere
    pain = { factor = 1.0, offset = you.skill("Necromancy") / 2 },
    spect = { factor = 1.7, offset = 0 },    -- Fudged down for increased incoming damage
    venom = { factor = 1.0, offset = 5.0 },  -- 5 dmg per poisoning

    subtle = { -- Values to use for weapon "scores" (not damage)
      antimagic = { factor = 1.1, offset = 0 },
      holy = { factor = 1.15, offset = 0 },
      penet = { factor = 1.3, offset = 0 },
      protect = { factor = 1.15, offset = 0 },
      reap = { factor = 1.3, offset = 0 },
      vamp = { factor = 1.2, offset = 0 },
    },
  },
} -- BRC.Profiles.Default (do not remove this comment)

---- Local functions ----
--- Accept a profile name, or a method to obtain a config name.
-- @return string a valid name of a config profile
local function get_validated_profile_name(input_name)
  if type(input_name) ~= "string" then
    BRC.mpr.warning("Non-string config name: " .. tostring(input_name))
  else
    local config_name = input_name:lower()
    if config_name == "ask" then
      -- If game has started, restore the previously saved profile name
      if you.turns() > 0 and brc_profile_name then
        return get_validated_profile_name(brc_profile_name)
      end
    elseif config_name == "previous" then
      -- Restore profile name from c_persist (cross-game persistence), or display warning
      if c_persist.BRC and c_persist.BRC.current_config then
        return get_validated_profile_name(c_persist.BRC.current_config)
      else
        BRC.mpr.warning("No previous config profile found.")
      end
    else
      -- Find by name in BRC.Profiles, or display warning
      for k, _ in pairs(BRC.Profiles) do
        if config_name == k:lower() then return k end
      end
      BRC.mpr.warning("Could not load config profile: " .. tostring(input_name))
    end
  end

  return BRC.mpr.select("Select a config profile", util.keys(BRC.Profiles))
end

local function is_config_module(p)
  return p
    and type(p) == "table"
    and p.BRC_CONFIG_NAME
    and type(p.BRC_CONFIG_NAME) == "string"
    and #p.BRC_CONFIG_NAME > 0
end

local function safe_call_string(str, module_name)
  local chunk, err = loadstring(str)
  if not chunk then
    BRC.mpr.error("Error loading " .. module_name .. ".Config.init string: ", err)
  else
    local success, result = pcall(chunk)
    if not success then
      BRC.mpr.error("Error executing " .. module_name .. ".Config.init string: ", result)
    end
  end
end

local function execute_config_init(config, module_name)
  if type(config) ~= "table" then return end
  if type(config.init) == "function" then
    config.init()
  elseif type(config.init) == "string" then
    safe_call_string(config.init, module_name)
  end
end

--- Override values in dest, with values from source. Take care not to clear existing tables.
local function override_table(source, dest)
  if type(source) ~= "table" then return end

  for key, value in pairs(source) do
    if BRC.util.is_map(value) then
      if not dest[key] then dest[key] = {} end
      override_table(value, dest[key])
    elseif key ~= "init" then
      dest[key] = value
    end
  end
end

--- Load a config profile, either from a table or from a name.
-- @param input_config table of config values, or string name of a profile
local function load_profile(input_config)
  if type(input_config) == "table" then
    BRC.Config = input_config
  else
    local profile_name = get_validated_profile_name(input_config)
    BRC.Config = util.copy_table(BRC.Profiles.Default)
    for k, v in pairs(BRC.Profiles[profile_name]) do
      BRC.Config[k] = v
    end
    execute_config_init(BRC.Config, "BRC")
  end

  brc_profile_name = BRC.Config.BRC_CONFIG_NAME

  -- Init all features and apply any overrides from the profile
  for _ , value in pairs(BRC.get_registered_features()) do
    BRC.process_feature_config(value)
  end

  BRC.mpr.white("[BRC] Using config: " .. BRC.txt.lightcyan(BRC.Config.BRC_CONFIG_NAME))
end

local function load_all_profiles()
  for _, c in pairs(_G) do
    if is_config_module(c) then BRC.Profiles[c.BRC_CONFIG_NAME] = c end
  end
end

--- Determine which config input to use based on store_config setting
-- @return table of config values, or string name of a profile
local function get_config_input()
  local store_mode = BRC.store_config and BRC.store_config:lower() or nil
  if store_mode == "full" then
    return brc_full_persistant_config or brc_profile_name or BRC.use_config
  elseif store_mode == "name" then
    return brc_profile_name or BRC.use_config
  else
    return BRC.use_config
  end
end

---- Public API ----
--- Main config loading entry point
function BRC.load_config()
  load_all_profiles()
  local config_input = get_config_input()
  load_profile(config_input)
  if BRC.store_config and BRC.store_config:lower() == "full" then
    brc_full_persistant_config = BRC.Config
  end
end

--- Process a feature config: Ensure default values, init(), then override with profile values
function BRC.process_feature_config(feature)
  if type(feature.ConfigDefaults) == "table" then
    feature.Config = util.copy_table(feature.ConfigDefaults)
  else
    feature.Config = feature.Config or {}
    execute_config_init(feature.Config, feature.BRC_FEATURE_NAME)
    feature.ConfigDefaults = util.copy_table(feature.Config)
  end
  override_table(BRC.Config[feature.BRC_FEATURE_NAME], feature.Config)
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
