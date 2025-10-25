--[[
BRC Configuration - Various configs, overriding default values in feature configs.
Author: buehler
Dependencies: (none)
Usage:
  - Update BRC.use_config to load the corresponding config.
  - Update each config or create new ones.
  - Undefined values first fall back to Configs.Default, then defaults in feature.Config.
  - `init` (function or multi-line comment of lua) executes after config loads, before overrides.
  - If using config_memory == "full", the function needs to be saved as a string instead. --]]
-- To do this, just replace `function()` and `end` with double square brackets: [[ ... ]]

---- Persistent variables ----
brc_config_full = BRC.Data.persist("brc_config_full", nil)
brc_config_name = BRC.Data.persist("brc_config_name", nil)

-- Default Config Profile (defines all non-feature values)
BRC.Config = {
  mpr = {
    emojis = false, -- Use emojis in alerts and announcements
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
BRC.Config = BRC.Profiles.Default -- Always init to Default profile

---- Local functions ----
local function get_validated_config_name(input_name)
  if type(input_name) ~= "string" then
    BRC.mpr.warning("Non-string config name: " .. tostring(input_name))
  else
    local config_name = input_name:lower()
    if config_name == "ask" then
      if you.turns() > 0 and brc_config_name then
        return get_validated_config_name(brc_config_name)
      end
    elseif config_name == "previous" then
      if c_persist.BRC and c_persist.BRC.current_config then
        return get_validated_config_name(c_persist.BRC.current_config)
      else
        BRC.mpr.warning("No previous config found.")
      end
    else
      for k, _ in pairs(BRC.Profiles) do
        if config_name == k:lower() then return k end
      end
      BRC.mpr.warning("Could not load config: " .. tostring(input_name))
    end
  end

  return BRC.mpr.select("Select a config", util.keys(BRC.Profiles))
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

local function load_profile(input_config)
  local config_name
  if type(input_config) == "table" then
    BRC.Config = input_config
    config_name = brc_config_name or "Unknown"
  else
    config_name = get_validated_config_name(input_config)
    BRC.Config = util.copy_table(BRC.Profiles.Default)
    for k, v in pairs(BRC.Profiles[config_name]) do
      BRC.Config[k] = v
    end
  end

  -- Do config init() and feature overrides
  if type(BRC.Config.init) == "function" then
    BRC.Config.init()
  elseif type(BRC.Config.init) == "string" then
    safe_call_string(BRC.Config.init, "BRC")
  end
  for name, _ in pairs(BRC.get_registered_features()) do
    BRC.process_feature_config(name)
  end

  BRC.mpr.info("Using config: " .. BRC.txt.lightcyan(config_name))
  return config_name
end

---- Public API ----
function BRC.load_config()
  if BRC.store_config and BRC.store_config:lower() == "full" then
    brc_config_name = load_profile(brc_config_full or brc_config_name or BRC.use_config)
    brc_config_full = BRC.Config
  elseif BRC.store_config and BRC.store_config:lower() == "name" then
    brc_config_name = load_profile(brc_config_name or BRC.use_config)
  else
    brc_config_name = load_profile(BRC.use_config)
  end
end

function BRC.process_feature_config(feature_name)
  local f = BRC.get_registered_features()[feature_name]
  if not f.Config then
    f.Config = {}
  elseif type(f.Config.init) == "function" then
    f.Config.init()
  elseif type(f.Config.init) == "string" then
    safe_call_string(f.Config.init, feature_name)
  end

  override_table(BRC.Config[feature_name], f.Config)
end

--- Stringify BRC.Config and all feature configs, including headers
function BRC.serialize_config()
  local tokens = {}
  tokens[#tokens + 1] = BRC.txt.lightcyan("\n---BRC Config---\n")
  tokens[#tokens + 1] = BRC.txt.tostr(BRC.Config, true)

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

  return table.concat(tokens)
end
