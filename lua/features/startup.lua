---------------------------------------------------------------------------------------------------
-- BRC feature module: startup
-- @module f_startup
-- @author rwbarton (display skills menu), gammafunk (training targets), buehler
-- Handles startup actions, like displaying skills menu and auto-setting skill targets.
---------------------------------------------------------------------------------------------------

f_startup = {}
f_startup.BRC_FEATURE_NAME = "startup"
f_startup.Config = {
  -- Race+class training targets. When this successfully loads targets, skip remaining startup
  use_saved_training_targets = true, -- Allow save/load of race+class training targets
  save_targets_keycode = BRC.util.cntl("t"), -- Keycode to save training targets
  allow_race_only_targets = true, -- Also save targets for just race (always prompts before loading)
  allow_class_only_targets = true, -- Also save targets for just class (always prompts before loading)
  prompt_before_load = false, -- Prompt before loading training targets for race+class combo

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

---- Local config alias ----
local Config = f_startup.Config

---- Local functions ----
local function ensure_training_targets_table()
  if type(c_persist.BRC) ~= "table" then c_persist.BRC = {} end
  if type(c_persist.BRC.training_targets) ~= "table" then c_persist.BRC.training_targets = {} end
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
  local saved = c_persist.BRC.training_targets[key]
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
  if not Config.use_saved_training_targets then return false end
  ensure_training_targets_table()

  return load_training_targets(you.race() .. " " .. you.class(), Config.prompt_before_load)
    or (Config.allow_race_only_targets and load_training_targets(you.race(), true))
    or (Config.allow_class_only_targets and load_training_targets(you.class(), true))
end

---- Macro function: Save current skill targets (training levels and targets) for race/class ----
function macro_brc_save_training_targets()
  if not BRC.active or Config.disabled or you.race() == "Gnoll" then
    BRC.mpr.info("BRC not active, or startup feature is disabled. Training targets not saved.")
    return
  end

  ensure_training_targets_table()
  local race = you.race()
  local class = you.class()
  local race_class_key = race .. " " .. class

  local skill_table = create_skill_table()

  -- Always save to race+class
  c_persist.BRC.training_targets[race_class_key] = util.copy_table(skill_table)
  BRC.mpr.green(string.format("Saved training targets for %s", race_class_key))

  -- For just race: auto-save if doesn't exist, ask if it does
  if not c_persist.BRC.training_targets[race] then
    c_persist.BRC.training_targets[race] = util.copy_table(skill_table)
    BRC.mpr.green(string.format("Saved training targets for %s", race))
  elseif BRC.mpr.yesno(string.format("Overwrite saved training targets for %s?", race)) then
    c_persist.BRC.training_targets[race] = util.copy_table(skill_table)
    BRC.mpr.magenta(string.format("Updated training targets for %s", race))
  end

  -- For just class: auto-save if doesn't exist, ask if it does
  if not c_persist.BRC.training_targets[class] then
    c_persist.BRC.training_targets[class] = util.copy_table(skill_table)
    BRC.mpr.green(string.format("Saved training targets for %s", class))
  elseif BRC.mpr.yesno(string.format("Overwrite saved training targets for %s?", class)) then
    c_persist.BRC.training_targets[class] = util.copy_table(skill_table)
    BRC.mpr.magenta(string.format("Updated training targets for %s", class))
  end
end

---- Hook functions ----
function f_startup.init()
  if Config.use_saved_training_targets and Config.save_targets_keycode then
    local keycode = "\\{" .. Config.save_targets_keycode .. "}"
    BRC.opt.macro(keycode, "macro_brc_save_training_targets")
  end
end

function f_startup.ready()
  if you.turns() == 0 then
    if you.race() ~= "Gnoll" and you.class() ~= "Wanderer" then
      if load_saved_training_targets() then return end
    end

    -- If no saved targets were loaded, use default config
    if Config.auto_set_skill_targets and you.race() ~= "Gnoll" then
      clear_skill_targets()

      local set_first = false
      for i, skill_target in ipairs(Config.auto_set_skill_targets) do
        local skill, target = unpack(skill_target)
        if you.skill(skill) < target then
          you.set_training_target(skill, target)
          if not set_first or not Config.focus_one_skill then
            you.train_skill(skill, 1)
            set_first = true
          end
          if not Config.set_all_targets then break end
        end
      end
    end
  end

  -- Show skills menu: Disable for non-Wanderer Gnolls
  if Config.show_skills_menu and (you.race() ~= "Gnoll" or you.class() == "Wanderer") then
    BRC.util.do_cmd("CMD_DISPLAY_SKILLS")
  end
end
