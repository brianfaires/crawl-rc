---------------------------------------------------------------------------------------------------
-- BRC feature module: startup
-- @module f_startup
-- @author rwbarton (display skills menu), gammafunk (training targets), buehler
-- Handles startup actions, like displaying skills menu and auto-setting skill targets.
---------------------------------------------------------------------------------------------------

f_startup = {}
f_startup.BRC_FEATURE_NAME = "startup"
f_startup.Config = {
  -- Save current training targets and config, for race/class
  macro_save_key = BRC.util.cntl("t"), -- Keycode to save training targets and config
  save_training = true, -- Allow save/load of race/class training targets
  save_config = true, -- Allow save/load of BRC config
  prompt_before_load = true, -- Prompt before loading in a new game with same race+class
  allow_race_only_saves = true, -- Also save for race only (always prompts before loading)
  allow_class_only_saves = true, -- Also save for class only (always prompts before loading)

  -- Remaining values only used if no training targets were loaded by race/class
  show_skills_menu = false, -- Show skills menu on startup

  -- Settings to set skill targets, regardless of race/class
  set_all_targets = true, -- Set all targets, even if only focusing one
  focus_one_skill = true, -- Focus one skill at a time, even if setting all targets
  auto_set_skill_targets = {
    { "Stealth", 2.0 }, -- First, focus stealth to 2.0
    { "Fighting", 2.0 }, -- If already have stealth, focus fighting to 2.0
  },

  -- For non-spellcasters, add preferred weapon type as 3rd skill target
  init = [[
    if you.skill("Spellcasting") == 0 then
      local wpn_skill = BRC.you.top_wpn_skill()
      if wpn_skill then
        local t = f_startup.Config.auto_set_skill_targets
        t[#t + 1] = { wpn_skill, 6.0 }
      end
    end
  ]],
} -- f_startup.Config (do not remove this comment)

---- Local variables ----
local C -- config alias

---- Initialization ----
function f_startup.init()
  C = f_startup.Config

  if C.macro_save_key and (C.save_training or C.save_config) then
    BRC.opt.macro(C.macro_save_key, "macro_brc_save_skills_and_config")
  end
end

---- Local functions ----
local function ensure_tables_exist()
  if type(c_persist.BRC) ~= "table" then c_persist.BRC = {} end
  if type(c_persist.BRC.saved_training) ~= "table" then c_persist.BRC.saved_training = {} end
  if type(c_persist.BRC.saved_configs) ~= "table" then c_persist.BRC.saved_configs = {} end
end

local function clear_skill_targets()
  for _, s in ipairs(BRC.TRAINING_SKILLS) do
    you.train_skill(s, 0)
  end
end

local function create_skill_table()
  local skill_table = {}
  for _, skill_name in ipairs(BRC.TRAINING_SKILLS) do
    local training_level = you.train_skill(skill_name)
    local target = you.get_training_target(skill_name)
    if training_level > 0 or target > 0 then
      skill_table[skill_name] = { training_level = training_level, target = target, }
    end
  end
  return skill_table
end

local function apply_skill_table(skill_table)
  clear_skill_targets()
  for skill_name, data in pairs(skill_table) do
    you.train_skill(skill_name, data.training_level)
    you.set_training_target(skill_name, data.target)
  end
end

local function load_training_targets(key, require_confirmation)
  local saved = c_persist.BRC.saved_training[key]
  if type(saved) ~= "table" then return false end

  if require_confirmation
    and not BRC.mpr.yesno("Load training targets for " .. BRC.txt.lightcyan(key) .. "?")
  then
    return false
  end

  apply_skill_table(saved)
  BRC.mpr.green("Loaded training targets for "  .. BRC.txt.lightcyan(key))
  return true
end

local function load_saved_training_targets()
  ensure_tables_exist()

  return load_training_targets(you.race() .. " " .. you.class(), C.prompt_before_load)
    or (C.allow_race_only_saves and load_training_targets(you.race(), true))
    or (C.allow_class_only_saves and load_training_targets(you.class(), true))
end

local function load_config(key, require_confirmation)
  local saved = c_persist.BRC.saved_configs[key]
  if type(saved) ~= "table" and type(saved) ~= "string" then return false end

  if require_confirmation
    and not BRC.mpr.yesno("Load config for " .. BRC.txt.lightcyan(key) .. "?")
  then
    return false
  end

  return BRC.init(saved)
end

local function load_saved_config()
  ensure_tables_exist()

  return load_config(you.race() .. " " .. you.class(), C.prompt_before_load)
    or (C.allow_race_only_saves and load_config(you.race(), true))
    or (C.allow_class_only_saves and load_config(you.class(), true))
end

--- Save obj to storage_table, under keys: race/class/combo
local function save_race_class(desc, parent, child)
  local keys = { }
  keys[1] = you.race() .. " " .. you.class() -- Always save combo
  if C.allow_race_only_saves then keys[#keys + 1] = you.race() end
  if C.allow_class_only_saves then keys[#keys + 1] = you.class() end
  for i, key in ipairs(keys) do
    if i == 1 -- don't prompt for combo
      or not parent[key] -- don't prompt if empty
      or BRC.mpr.yesno(string.format("Overwrite saved %s for %s?", desc, BRC.txt.lightcyan(key)))
    then
      parent[key] = type(child) == "table" and util.copy_table(child) or child
      BRC.mpr.green(string.format("Saved %s for %s", desc, BRC.txt.lightcyan(key)))
    end
  end
end

--- Load configured skill targets, not saved by race/class in c_persist
local function load_generic_skill_targets()
  clear_skill_targets()

  local set_first = false
  for _, skill_target in ipairs(C.auto_set_skill_targets) do
    local skill, target = unpack(skill_target)
    if you.skill(skill) < target then
      you.set_training_target(skill, target)
      if not set_first or not C.focus_one_skill then
        you.train_skill(skill, 1)
        set_first = true
      end
      if not C.set_all_targets then break end
    end
  end
end

--- Since BRC.Config inherits from BRC.Configs.Default, remove the defaults to reduce size
-- Recursively walks through config, removing values that match those in defaults
-- @warning Does not check for circular references; there's no reason for them in BRC.Config
local function strip_defaults_from_map(config, defaults)
  if defaults == nil then return util.copy_table(config) end
  local stripped = {}
  for k, v in pairs(config) do
    if type(v) == "table" then
      -- If neither map nor list, it's {} and will be excluded
      if BRC.util.is_map(v) then
        local stripped_map = strip_defaults_from_map(v, defaults[k])
        if next(stripped_map) then stripped[k] = stripped_map end
      elseif BRC.util.is_list(v) then
        local default_list = defaults[k]
        local is_same = type(default_list) == "table" and #v == #default_list
        if is_same then
          for i = 1, #v do
            if v[i] ~= default_list[i] then
              is_same = false
              break
            end
          end
        end
        if not is_same then stripped[k] = v end
      end
    elseif v ~= defaults[k] then
      stripped[k] = v
    end
  end
  return stripped
end

---- Macro function: Save current skill targets (training levels and targets) for race/class ----
function macro_brc_save_skills_and_config()
  if BRC.active == false or f_startup.Config.disabled then
    BRC.mpr.info("BRC not active, or startup feature is disabled. Training targets not saved.")
    return
  end

  ensure_tables_exist()
  if f_startup.Config.save_training and you.race() ~= "Gnoll" then
    local do_save = not f_startup.Config.save_config
    if not do_save then
      do_save = BRC.mpr.yesno("Save training + targets?", BRC.COL.magenta)
      if not do_save then crawl.mpr.okay() end
    end
    if do_save then
      save_race_class("training targets", c_persist.BRC.saved_training, create_skill_table())
    end
  end

  if f_startup.Config.save_config then
    local do_save = not f_startup.Config.save_training
    if not do_save then
      do_save = BRC.mpr.yesno("Save config?", BRC.COL.magenta)
      if not do_save then crawl.mpr.okay() end
    end
    if do_save then
      local stripped_config = strip_defaults_from_map(BRC.Config, BRC.Configs.Default)
      save_race_class("config", c_persist.BRC.saved_configs, stripped_config)
    end
  end
end

---- Crawl hook functions ----
function f_startup.ready()
  if you.turns() ~= 0 then return end

  -- Check for saved config/targets in c_persist
  if C.save_config then load_saved_config() end
  if C.save_training and you.race() ~= "Gnoll" and you.class() ~= "Wanderer" then
    if load_saved_training_targets() then return end
  end

  -- If no saved targets were loaded, use other configured skill targets
  if C.auto_set_skill_targets and you.race() ~= "Gnoll" then
    load_generic_skill_targets()
  end

  -- Show skills menu: Disable for non-Wanderer Gnolls
  if C.show_skills_menu and (you.race() ~= "Gnoll" or you.class() == "Wanderer") then
    BRC.util.do_cmd("CMD_DISPLAY_SKILLS")
  end
end
