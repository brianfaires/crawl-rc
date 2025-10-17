--[[
Feature: alert-monsters
Description: Dynamic force_more configuration for monsters based on player HP, xl, willpower, resistances, etc.
    WARNINGS:
      - Never put a '}' on a line by itself. This breaks crawl's RC parser.
      - POSIX regex are required for this feature to use '|' in patterns.
Author: original by gammafunk, extended by buehler
Dependencies: core/util.lua
--]]

f_alert_monsters = {}
f_alert_monsters.BRC_FEATURE_NAME = "alert-monsters"
f_alert_monsters.Config = {
  sensitivity = 1.0, -- 0 to disable all; at 2.0, alerts will fire at 1/2 HP
  fm_on_uniques = true, -- Stop on all Uniques & Pan lords
  pack_timeout = 10, -- # turns to wait before repeating an alert for a pack of monsters. 0 to disable
  disable_alert_monsters_in_zigs = true, -- Disable dynamic force_mores in Ziggurats
  debug_alert_monsters = false, -- Get a message when alerts toggle off/on
} -- f_alert_monsters.Config (do not remove this comment)

---- Local config alias ----
local Config = f_alert_monsters.Config

--[[
Config.Alerts configures all alerts. Each table within it creates one alert, using the following fields:
  - `name` is for debugging.
  - `pattern` is either a string or a table of monster names, that will file a force_more when they come into view.
  - `is_pack` (optional) indicates the alert is for a pack of monsters.
    Packs only fire once every few turns - as defined in Config.pack_timeout (default 15).
  - `flash_screen` (optional) indicates the alert should flash the screen instead of using force_more.
  - `cutoff` sets the point when the alert is active (usually how much HP you have)
  - `cond` defines HOW the character stats are compared against `cutoff` (HP/will/etc).
      Ex:
        `always` alerts are always on.
        `hp` alerts are active when you have < `cutoff` HP.
        `will` alerts are active when you have <= `cutoff` pips of willpower.
        `int` alerts are active when you have < `cutoff` Int.
        `xl` alerts are active when your XL is < `cutoff`.
        `elec` alerts are active when you have no rElec and < `cutoff` HP.
        `fire`, `cold`, etc are active < `cutoff` HP with no resistance. Pips of res reduce the cutoff to 50/33/20% 
--]]
f_alert_monsters.Config.Alerts = {
  { name = "always_fm",
    pattern = {
      -- High damage/speed
      "flayed ghost", "juggernaut", "orbs? of (entropy|fire|winter)",
      --Summoning
      "boundless tesseract", "demonspawn corrupter", "draconian stormcaller", "dryad",
      "guardian serpent", "halazid warlock", "shadow demon", "spriggan druid", "worldbinder",
      --Dangerous abilities
      "iron giant", "merfolk aquamancer", "shambling mangrove", "starflower",
      "torpor snail", "water nymph", "wretched star", "wyrmhole",
      --Dangerous clouds
      "apocalypse crab","catoblepas",
    } },

  { name = "always_flash",
    flash_screen = true,
    pattern = {
      -- Noteworthy abilities
      "air elemental", "elemental wellspring", "ghost crab", "ironbound convoker",
      "vault guardian", "vault warden", "wendingo",
      -- Displacement
      "deep elf knight", "swamp worm",
      -- Summoning
      "deep elf elementalist",
    } },

  { name = "always_fm_pack",
    is_pack = true,
    pattern = { "boggart", "dream sheep", "floating eye", "shrike", } },

  -- Early game Dungeon problems for chars with low mhp. (adder defined below)
  { name = "30hp", cond = "hp", cutoff = 30,
    pattern = { "hound", "gnoll" } },

  -- Monsters dangerous until a certain point
  { name = "xl_7", cond = "xl", cutoff = 7,
    pattern = { "orc wizard" } },
  { name = "xl_12", cond = "xl", cutoff = 12,
    pattern = { "hydra", "bloated husk" } },

  -- Monsters that can hit for ~50% of hp from range with unbranded attacks
  { name = "40hp", cond = "hp", cutoff = 40,
    pattern = { "orc priest" } },
  { name = "50hp", cond = "hp", cutoff = 50,
    pattern = { "orc high priest", "manticore" } },
  { name = "60hp", cond = "hp", cutoff = 60,
    pattern = { "yaktaur(?! captain)", "cyclops", "centaur(?! warrior)" } },
  { name = "70hp_melai", cond = "hp", cutoff = 70,
    is_pack = true,
    pattern = "meliai" },
  { name = "80hp", cond = "hp", cutoff = 80,
    pattern = { "gargoyle" } },
  { name = "90hp", cond = "hp", cutoff = 90,
    pattern = { "deep elf archer", "tengu conjurer" } },
  { name = "110hp", cond = "hp", cutoff = 110,
    pattern = { "centaur warrior", "yaktaur captain", "hellion", "eye of devastation",
                "sun moth", "deep elf high priest", "deep troll earth mage",
                "stone giant", "cacodemon" } },
  { name = "120hp", cond = "hp", cutoff = 120,
    pattern = { "quicksilver (dragon|elemental)", "magenta draconian", "thorn hunter" } },
  { name = "160hp", cond = "hp", cutoff = 160,
    pattern = { "brimstone fiend", "deep elf sorcererhell sentinal", "war gargoyle",
                "draconian (knight|scorcher)" } },
  { name = "200hp", cond = "hp", cutoff = 200,
    pattern = { "(draconian|deep elf) annihilator", "iron (dragon|elemental)" } },

  -- Monsters that can crowd-control you without sufficient willpower
  -- Cutoff ~10% for most spells; lower for more significant spells like banish
  { name = "willpower2", cond = "will", cutoff = 2,
    pattern = { "basilisk", "naga ritualist", "vampire(?! (bat|mage|mosquito))", "sphinx marauder" } },
  { name = "willpower3", cond = "will", cutoff = 3,
    pattern = { "deep elf (demonologist|sorcerer|archer)", "occultist", "merfolk siren", "fenstrider witch",
                "cacodemon", "imperial myrmidon", "guardian sphinx", "nagaraja", "draconian shifter",
                "glowing orange brain", "orc sorcerer", "ogre mage", "satyr", "vault sentinel", "iron elemental",
                "death knight", "vampire knight" } },
  { name = "willpower3_great_orb_of_eyes", cond = "will", cutoff = 3,
    is_pack = true,
    pattern = "great orb of eyes" },
  { name = "willpower3_golden_eye", cond = "will", cutoff = 3,
    is_pack = true,
    pattern = "golden eye" },
  { name = "willpower4", cond = "will", cutoff = 4,
    pattern = { "merfolk avatar", "tainted leviathan", "nargun" } },

  -- Brain feed with low int
  { name = "brainfeed", cond = "int", cutoff = 6,
    pattern = { "glowing orange brain", "neqoxec" } },

  -- Alert if no resist and HP below cutoff
  { name = "pois_30", cond = "pois", cutoff = 30,
    pattern = { "adder" } },
  { name = "pois_80", cond = "pois", cutoff = 80,
    pattern = { "golden dragon", "green draconian", "swamp dragon" } },
  { name = "pois_120", cond = "pois", cutoff = 120,
    pattern = { "green death", "naga mage", "nagaraja", "fenstrider witch" } },
  { name = "pois_140", cond = "pois", cutoff = 140,
    pattern = { "tengu reaver" } },

  { name = "elec_40", cond = "elec", cutoff = 40, is_pack = true,
    pattern = "electric eel" },
  { name = "elec_80", cond = "elec", cutoff = 80,
    pattern = { "shock serpent", "raiju", "spark wasp" } },
  { name = "elec_120", cond = "elec", cutoff = 120,
    pattern = { "black draconian", "blizzard demon", "deep elf zephyrmancer", "storm dragon", "tengu conjurer" } },
  { name = "elec_140", cond = "elec", cutoff = 140,
    pattern = { "electric golem", "titan", "servants? of whisper", "spriggan air mage",
                "ball lightning", "tengu reaver" } },

  { name = "corr_60", cond = "corr", cutoff = 60,
    pattern = { "acid dragon" } },
  { name = "corr_140", cond = "corr", cutoff = 140,
    pattern = { "tengu reaver", "entropy weaver", "demonspawn corrupter", "moon troll" } },

  { name = "fire_60", cond = "fire", cutoff = 60,
    pattern = { "steam dragon", "lindwurm", "fire crab", "lava snake" } },
  { name = "fire_100", cond = "fire", cutoff = 100,
    pattern = { "efreet", "deep elf pyromancer", "smoke demon", "sun moth" } },
  { name = "fire_120", cond = "fire", cutoff = 120,
    pattern = { "orc sorcerer", "hell hound", "demonspawn blood saint", "red draconian", "ogre mage",
                "molten gargoyle", "hell knight" } },
  { name = "fire_140", cond = "fire", cutoff = 140,
    pattern = { "balrug" } },
  { name = "fire_160", cond = "fire", cutoff = 160,
    pattern = { "will-o-the-wisp", "ophan", "fire giant", "golden dragon", "fire dragon", "salamander tyrant",
                "tengu reaver" } },
  { name = "fire_240", cond = "fire", cutoff = 240,
    pattern = { "hellephant", "crystal (guardian|echidna)", "draconian scorcher" } },

  { name = "cold_80", cond = "cold", cutoff = 80,
    pattern = { "rime drake" } },
  { name = "cold_120", cond = "cold", cutoff = 120,
    pattern = { "blizzard demon", "bog body", "ironbound frostheart", "demonspawn blood saint",
                "white draconian" } },
  { name = "cold_160", cond = "cold", cutoff = 160,
    pattern = { "golden dragon", "draconian knight", "frost giant", "ice dragon", "tengu reaver" } },
  { name = "cold_180", cond = "cold", cutoff = 180,
    pattern = { "(?<!dread)(?<!ancient) lich", "lich king" } },
  { name = "cold_240", cond = "cold", cutoff = 240,
    pattern = { "crystal (guardian|echidna)" } },

  { name = "drain_100", cond = "drain", cutoff = 100,
    pattern = { "orc sorcerer" } },
  { name = "drain_120", cond = "drain", cutoff = 120,
    pattern = { "necromancer" } },
  { name = "drain_150", cond = "drain", cutoff = 150,
    pattern = { "revenant", "demonspawn blood saint" } },
  { name = "drain_190", cond = "drain", cutoff = 190,
    pattern = { "shadow dragon" } },
} -- fm_patterns (do not remove this comment)

f_alert_monsters.Config.init = [[
    local alert_list = f_alert_monsters.Config.Alerts
    -- Conditionally add miasma monsters
    if not BRC.you.miasma_immune() then
      util.append(alert_list, {
        name = "miasma", cond = "always", cutoff = 0,
        pattern = { "death drake", "tainted leviathan", "putrid mouth", }
      })
    end

    -- Conditionally add tormentors
    if not you.torment_immune() then
      util.append(alert_list, {
        name = "torment", cond = "always", cutoff = 0,
        pattern = { "tormentor", "curse (toe|skull)", "Fiend", "tzitzimi", "royal mummy",
                    "mummy priest", "(dread|ancient) lich", "lurking horror", }
      })
    end

    -- Set mutators to either flash (if undead) or a conditional fm
    local mutator_str = "cacodemon|neqoxec|shining eye"
    if BRC.you.mutation_immune() then
      BRC.set.flash_screen_message("monster_warning:" .. mutator_str, true)
    else
      util.append(alert_list, { name = "malmutate", cond = "mut", cutoff = 1, pattern = mutator_str })
    end

    -- If configured, add fm for all uniques and pan lords
    if f_alert_monsters.Config.fm_on_uniques then
      BRC.set.force_more_message("monster_warning:(?-i:[A-Z]).*(?<!rb Guardian) comes? into view", true)
    end
]]
------------------- End config section -------------------

---- Local variables ----
local patterns_to_mute = nil -- which packs to mute at next ready()

---- Local constants ----
local WARN_PREFIX = "monster_warning:(?<!spectral )("
local WARN_SUFFIX = ")(?! (zombie|skeleton|simulacrum)).*comes? into view"

---- Local functions ----
local function check_alert_three_pip(hp, dmg_threshold, resistance)
  -- Dmg taken is 1/1; 1/2; 1/3; 1/5 (for 0; 1; 2; 3 resistance)
  if resistance >= 3 then return hp < dmg_threshold / 5 end
  return hp < dmg_threshold / (resistance + 1)
end

local function update_pack_mutes()
  -- Put pending mutes into effect
  for _, v in ipairs(patterns_to_mute) do
    if v.flash_screen then
      BRC.set.flash_screen_message(v, false)
    else
      BRC.set.force_more_message(v, false)
    end
    if Config.debug_alert_monsters then BRC.mpr.blue(string.format("Muted pack: %s", v)) end
  end
  patterns_to_mute = {}

  -- Remove expired mutes
  for _, v in ipairs(Config.Alerts) do
    if v.is_pack and v.last_fm_turn ~= -1 and you.turns() >= v.last_fm_turn + Config.pack_timeout then
      v.last_fm_turn = -1
      v.active_alert = false -- Set to false and let the main logic decide if it should reactivate it.
      if Config.debug_alert_monsters then BRC.mpr.blue(string.format("Unmuted pack: %s", v.pattern)) end
    end
  end
end

---- Hook functions ----
function f_alert_monsters.init()
  patterns_to_mute = {}

  -- Break packs with tables into individual alerts
  local add_patterns = {}
  local remove_patterns = {}
  for _, v in ipairs(Config.Alerts) do
    if v.is_pack and type(v.pattern) == "table" and #v.pattern > 1 then
      remove_patterns[#remove_patterns + 1] = v
      for _, m in ipairs(v.pattern) do
        local to_add = util.copy_table(v)
        to_add.name = (to_add.name or "") .. "_" .. m:gsub(" ", "_")
        to_add.pattern = m
        add_patterns[#add_patterns + 1] = to_add
      end
    end
  end
  util.append(Config.Alerts, add_patterns)
  for _, v in ipairs(remove_patterns) do
    util.remove(Config.Alerts, v)
  end

  -- Convert patterns to regex
  for _, v in ipairs(Config.Alerts) do
    v.active_alert = false
    v.last_fm_turn = -1
    if type(v.pattern) == "table" then
      v.pattern = table.concat(v.pattern, "|")
    end
    v.pattern = WARN_PREFIX .. v.pattern .. WARN_SUFFIX
    v.regex = crawl.regex(v.pattern:gsub("monster_warning:", ""))
  end
end

function f_alert_monsters.c_message(text, channel)
  if channel ~= "monster_warning" or not text:find("comes? into view") or Config.pack_timeout <= 0 then return end
  -- Identify when a mute should be turned on
  for _, v in ipairs(Config.Alerts) do
    if v.is_pack and v.regex:matches(text) then
      if v.last_fm_turn == -1 then
        patterns_to_mute[#patterns_to_mute + 1] = v.pattern
        if Config.debug_alert_monsters then BRC.mpr.blue(string.format("To mute: %s", v.pattern)) end
      else
        if Config.debug_alert_monsters then BRC.mpr.blue(string.format("Extending mute: %s", v.pattern)) end
      end
      v.last_fm_turn = you.turns()
    end
  end
end

function f_alert_monsters.ready()
  local activated = {}
  local deactivated = {}

  -- Load all stats before loop. Most of them are used multiple times.
  local hp, _ = you.hp()
  local amulet = items.equipped_at("amulet")
  if (you.race() == "Vine Stalker") or (amulet and amulet.name() == "amulet of guardian spirit") then
    local mp, _ = you.mp()
    hp = hp + mp
  end
  local xl = you.xl()
  local int = you.intelligence()
  local willpower = you.willpower()
  local res_mut = you.res_mutation()
  local res_pois = you.res_poison()
  local res_elec = you.res_shock()
  local res_corr = you.res_corr()
  local res_fire = you.res_fire()
  local res_cold = you.res_cold()
  local res_drain = you.res_draining()

  for _, v in ipairs(Config.Alerts) do
    local should_be_active = nil

    if Config.disable_alert_monsters_in_zigs and you.branch() == "Zig" then
      should_be_active = false
    elseif not v.cond then
      should_be_active = true
    elseif v.cond == "xl" then
      should_be_active = xl < v.cutoff * Config.sensitivity
    elseif v.cond == "hp" then
      should_be_active = hp < v.cutoff * Config.sensitivity
    elseif v.cond == "int" then
      should_be_active = int < v.cutoff * Config.sensitivity
    elseif v.cond == "will" then
      should_be_active = willpower < v.cutoff * Config.sensitivity
    elseif v.cond == "mut" then
      should_be_active = res_mut == 0
    elseif v.cond == "pois" then
      should_be_active = res_pois == 0 and hp < v.cutoff * Config.sensitivity
    elseif v.cond == "elec" then
      should_be_active = res_elec == 0 and hp < v.cutoff * Config.sensitivity
    elseif v.cond == "corr" then
      should_be_active = not res_corr and hp < v.cutoff * Config.sensitivity
    elseif v.cond == "fire" then
      should_be_active = check_alert_three_pip(hp, v.cutoff * Config.sensitivity, res_fire)
    elseif v.cond == "cold" then
      should_be_active = check_alert_three_pip(hp, v.cutoff * Config.sensitivity, res_cold)
    elseif v.cond == "drain" then
      should_be_active = check_alert_three_pip(hp, v.cutoff * Config.sensitivity, res_drain)
    end

    if should_be_active ~= v.active_alert then
      v.active_alert = should_be_active
      if v.flash_screen then
        BRC.set.flash_screen_message(v.pattern, should_be_active)
      else
        BRC.set.force_more_message(v.pattern, should_be_active)
      end

      if Config.debug_alert_monsters then
        if v.active_alert then
          activated[#activated + 1] = v.name or v.pattern
        else
          deactivated[#deactivated + 1] = v.name or v.pattern
        end
      end
    end
  end

  if Config.debug_alert_monsters then
    if #activated > 0 then BRC.mpr.blue(string.format("Activating f_m: %s", table.concat(activated, ", "))) end
    if #deactivated > 0 then BRC.mpr.blue(string.format("Deactivating f_m: %s", table.concat(deactivated, ", "))) end
  end

  if Config.pack_timeout > 0 then update_pack_mutes() end
end
