--[[
Feature: fm-monsters
Description: Dynamic force_more configuration for monsters based on player HP, experience level, and willpower thresholds
    hp-specific force_mores() by gammafunk, extended by buehler
    WARNING: Never put a '}' on a line by itself. This breaks crawl's RC parser.
Author: gammafunk, buehler
Dependencies: CONFIG, util.append, is_miasma_immune, you.torment_immune
--]]

f_fm_monsters = {}
f_fm_monsters.BRC_FEATURE_NAME = "fm-monsters"

-- Local configuration
local ALWAYS_FLASH_SCREEN_MONSTERS = {
  -- Noteworthy abilities
  "air elemental", "elemental wellspring", "ghost crab", "ironbound convoker",
  "vault guardian", "vault warden", "wendingo", 
  -- Displacement
  "deep elf knight", "swamp worm",
  -- Summoning
  "deep elf elementalist", 
} -- always_flash_screen_monsters (do not remove this comment)

local ALWAYS_FORCE_MORE_MONSTERS = {
  -- High damage/speed
  "juggernaut", "orbs? of fire", "flayed ghost",
  --Summoning
  "shadow demon", "guardian serpent",
  "draconian stormcaller", "spriggan druid", "dryad", "worldbinder",
  "halazid warlock", "demonspawn corrupter",
  --Dangerous abilities
  "wyrmhole",
  "torpor snail", "water nymph", "shambling mangrove", "iron giant",
  "starflower", "merfolk aquamancer", "wretched star",
  --Dangerous clouds
  "catoblepas", "apocalypse crab",
} -- always_force_more_monsters (do not remove this comment)

-- Conditional adds to ALWAYS_FORCE_MORE_MONSTERS
if not is_miasma_immune() then
  util.append(ALWAYS_FORCE_MORE_MONSTERS, { "death drake", "putrid mouth" })
end

if not you.torment_immune() then
  util.append(ALWAYS_FORCE_MORE_MONSTERS, {
    "tormentor", "curse (toe|skull)", "Fiend", "tzitzimi",
    "royal mummy", "mummy priest", "(dread|ancient) lich", "lurking horror"
  })
end


local FM_PACK = {
-- Only alert once per pack
  "boggart", "dream sheep",  "floating eye", "shrike"
} -- fm_pack (do not remove this comment)


local FM_PACK_NO_CREATE = {
  -- Once per pack, but alerts are created through dynamic-fms below.
  -- NOTE: The correesponding dynamic-fm must be on an alert by itself (not part of a multi-monster pattern)
  "electric eel", "golden eye", "great orb of eyes", "meliai"
} -- FM_PACK_NO_CREATE (do not remove this comment)


local FM_PATTERNS = {
  -- Early game Dungeon problems for chars with low mhp. (adder defined below)
  {name = "30hp", cond = "hp", cutoff = 30,
    pattern = "hound|gnoll"},

  -- Monsters dangerous until a certain point
  {name = "xl_7", cond = "xl", cutoff = 7,
    pattern = "orc wizard"},
  {name = "xl_12", cond = "xl", cutoff = 12,
    pattern = "hydra|bloated husk"},

  -- Monsters that can hit for ~50% of hp from range with unbranded attacks
  {name = "40hp", cond = "hp", cutoff = 40,
    pattern = "orc priest" },
  {name = "50hp", cond = "hp", cutoff = 50,
    pattern = "orc high priest|manticore" },
  {name = "60hp", cond = "hp", cutoff = 60,
    pattern = "yaktaur(?! captain)|cyclops|centaur(?! warrior)" },
  {name = "70hp_melai", cond = "hp", cutoff = 70,
    pattern = "meliai"},
  {name = "80hp", cond = "hp", cutoff = 80,
    pattern = "gargoyle" },
  {name = "90hp", cond = "hp", cutoff = 90,
    pattern = "deep elf archer|tengu conjurer" },
  {name = "110hp", cond = "hp", cutoff = 110,
    pattern = "centaur warrior|yaktaur captain|hellion|eye of devastation|sun moth" ..
              "deep elf high priest|deep troll earth mage|stone giant|cacodemon" },
  {name = "120hp", cond = "hp", cutoff = 120,
    pattern = "quicksilver (dragon|elemental)|magenta draconian|thorn hunter" },
  {name = "160hp", cond = "hp", cutoff = 160,
    pattern = "brimstone fiend|deep elf sorcerer" ..
              "hell sentinal|war gargoyle|draconian (knight|scorcher)" },
  {name = "200hp", cond = "hp", cutoff = 200,
    pattern = "(draconian|deep elf) annihilator|iron (dragon|elemental)" },

  -- Monsters that can crowd-control you without sufficient willpower
  -- Cutoff ~10% for most spells; lower for more significant spells like banish
  {name = "willpower2", cond = "will", cutoff = 2,
    pattern = "basilisk|naga ritualist|vampire(?! (bat|mage|mosquito))|sphinx marauder" },
  {name = "willpower3", cond = "will", cutoff = 3,
    pattern = "deep elf (demonologist|sorcerer|archer)|occultist|" ..
              "merfolk siren|fenstrider witch|cacodemon|" ..
              "imperial myrmidon|guardian sphinx|nagaraja|draconian shifter|" ..
              "glowing orange brain|orc sorcerer|" ..
              "ogre mage|satyr|vault sentinel|iron elemental|" ..
              "death knight|vampire knight" },
  {name = "willpower3_great_orb_of_eyes", cond = "will", cutoff = 3,
    pattern = "great orb of eyes" },
  {name = "willpower3_golden_eye", cond = "will", cutoff = 3,
    pattern = "golden eye" },
  {name = "willpower4", cond = "will", cutoff = 4,
    pattern = "merfolk avatar|tainted leviathan|nargun" },

  -- Brain feed with low int
  {name = "brainfeed", cond = "int", cutoff = 6,
    pattern = "glowing orange brain|neqoxec" },

  -- Alert if no resist and HP below cutoff
  {name = "pois_30", cond = "pois", cutoff = 30,
    pattern = "adder"},
  {name = "pois_80", cond = "pois", cutoff = 80,
    pattern = "golden dragon|green draconian|swamp dragon" },
  {name = "pois_120", cond = "pois", cutoff = 120,
    pattern = "green death|naga mage|nagaraja|fenstrider witch" },
  {name = "pois_140", cond = "pois", cutoff = 140,
    pattern = "tengu reaver" },

  {name = "elec_40", cond = "elec", cutoff = 40,
    pattern = "electric eel" },
  {name = "elec_80", cond = "elec", cutoff = 80,
    pattern = "shock serpent|raiju|spark wasp" },
  {name = "elec_120", cond = "elec", cutoff = 120,
    pattern = "black draconian|blizzard demon|deep elf zephyrmancer|" ..
              "storm dragon|tengu conjurer" },
  {name = "elec_140", cond = "elec", cutoff = 140,
    pattern = "electric golem|titan|servants? of whisper|spriggan air mage|" ..
              "ball lightning|tengu reaver" },

  {name = "corr_60", cond = "corr", cutoff = 60,
    pattern = "acid dragon" },
  {name = "corr_140", cond = "corr", cutoff = 140,
    pattern = "tengu reaver|entropy weaver|demonspawn corrupter|moon troll" },

  {name = "fire_60", cond = "fire", cutoff = 60,
    pattern = "steam dragon|lindwurm|fire crab|lava snake" },
  {name = "fire_100", cond = "fire", cutoff = 100,
    pattern = "efreet|deep elf pyromancer|smoke demon|sun moth" },
  {name = "fire_120", cond = "fire", cutoff = 120,
    pattern = "orc sorcerer|hell hound|demonspawn blood saint|red draconian|" ..
              "ogre mage|molten gargoyle|hell knight" },
  {name = "fire_140", cond = "fire", cutoff = 140,
    pattern = "balrug" },
  {name = "fire_160", cond = "fire", cutoff = 160,
    pattern = "will-o-the-wisp|ophan|fire giant|golden dragon|" ..
              "fire dragon|salamander tyrant|tengu reaver" },
  {name = "fire_240", cond = "fire", cutoff = 240,
    pattern = "hellephant|crystal (guardian|echidna)|draconian scorcher" },

  {name = "cold_80", cond = "cold", cutoff = 80,
    pattern = "rime drake" },
  {name = "cold_120", cond = "cold", cutoff = 120,
    pattern = "blizzard demon|bog body|ironbound frostheart|" ..
              "demonspawn blood saint|white draconian" },
  {name = "cold_160", cond = "cold", cutoff = 160,
    pattern = "golden dragon|draconian knight|frost giant|ice dragon|tengu reaver" },
  {name = "cold_180", cond = "cold", cutoff = 180,
    pattern = "(?<!dread)(?<!ancient) lich" },
  {name = "cold_240", cond = "cold", cutoff = 240,
    pattern = "crystal (guardian|echidna)" },

  {name = "drain_100", cond = "drain", cutoff = 100,
    pattern = "orc sorcerer" },
  {name = "drain_120", cond = "drain", cutoff = 120,
    pattern = "necromancer" },
  {name = "drain_150", cond = "drain", cutoff = 150,
    pattern = "revenant|demonspawn blood saint" },
  {name = "drain_190", cond = "drain", cutoff = 190,
    pattern = "shadow dragon" },
} -- end fm_patterns (do not remove this comment)

-- Set mutators to either flash (if undead) or a conditional fm
if is_mutation_immune() then
  crawl.setopt("flash_screen_message += monster_warning:cacodemon|neqoxec|shining eye")
else
  table.insert(FM_PATTERNS,
    -- Malmutate without rMut
    {name = "malmutate", cond = "mut", cutoff = 1,
      pattern = "cacodemon|neqoxec|shining eye" }
  )
end
------------------- End config section -------------------

-- Local state
local active_fm -- which ones are on
local active_fm_index -- lookup table for speed
local monsters_to_mute -- which packs are muted
local last_fm_turn -- when the mute started

-- Local functions
local function get_three_pip_action(is_active, hp, dmg_threshold, resistance)
  -- Dmg taken is 1/2; 1/3; 1/5 (for 1,2,3 resistance)
  local divisor = resistance + 1
  if divisor == 4 then divisor = 5 end

  if is_active then
    if hp >= dmg_threshold / divisor then return "-" end
  else
    if hp < dmg_threshold / divisor then return "+" end
  end
end

local MONSTER_OPTION_TOKENS = {
  "monster_warning:(?<!spectral )(",
  "",
  ")(?! (zombie|skeleton|simulacrum)).*comes? into view"
}
local function set_monster_option(sign, monster_str, option)
  MONSTER_OPTION_TOKENS[2] = monster_str
  local fm_str = table.concat(MONSTER_OPTION_TOKENS)
  crawl.setopt(option .. " " .. sign .. "= " .. fm_str)
end

local function set_all(monster_list, option)
  local mon_str = nil
  for _, v in ipairs(monster_list) do
    if not mon_str then
      mon_str = v
    else
      mon_str = mon_str .. "|" .. v
    end
  end
  set_monster_option("+", mon_str, option)
end

local function set_monster_flash(sign, monster_str)
  set_monster_option(sign, monster_str, "flash_screen_message")
end

local function set_monster_fm(sign, monster_str)
  set_monster_option(sign, monster_str, "force_more_message")
end

local function do_pack_mutes()
  -- Put pending mutes into effect
  for _, v in ipairs(monsters_to_mute) do
    set_monster_fm("-", v) -- Mute the fm-alert by removing the fm
  end
  monsters_to_mute = {}

  -- Remove mutes that have expired (FM_PACK includes FM_PACK_NO_CREATE)
  for _, v in ipairs(FM_PACK) do
    if last_fm_turn[v] ~= -1 and you.turns() >= last_fm_turn[v] + CONFIG.fm_pack_duration then
      last_fm_turn[v] = -1
      if util.contains(FM_PACK_NO_CREATE, v) then
        active_fm[active_fm_index[v]] = false -- Set to false so the main logic can conditionally re-enable it
      else 
        set_monster_fm("+", v) -- Reenable the fm, which is always active
      end
    end
  end
end


function f_fm_monsters.init()
  active_fm = {}
  active_fm_index = {}
  monsters_to_mute = {}
  last_fm_turn = {}

  if CONFIG.fm_on_uniques then
    crawl.setopt("force_more_message += monster_warning:(?-i:[A-Z].*(?<!rb Guardian) comes? into view")
  end

  set_all(ALWAYS_FLASH_SCREEN_MONSTERS, "flash_screen_message")
  set_all(ALWAYS_FORCE_MORE_MONSTERS, "force_more_message")

  -- Init packs
  for _, v in ipairs(FM_PACK) do
    set_monster_fm("+", v)
    last_fm_turn[v] = -1
  end

  for _,v in ipairs(FM_PACK_NO_CREATE) do
    FM_PACK[#FM_PACK+1] = v
    last_fm_turn[v] = -1
  end

  -- Build table of indexes, used for fm_pack logic
  for i,v in ipairs(FM_PATTERNS) do
    if not v.pattern:find("|") then
      active_fm_index[v.pattern] = i
    end
  end

  -- Init all active_fm to false
  for _,_ in ipairs(FM_PATTERNS) do
    active_fm[#active_fm+1] = false
  end
end


------------------- Hooks -------------------
function f_fm_monsters.c_message(text, channel)
  if channel ~= "monster_warning" then return end
  if CONFIG.fm_pack_duration == 0 then return end
  
  -- Identifies when a mute should be turned on
  if not text:find("comes? into view") then return end
  for _, v in ipairs(FM_PACK) do
    if text:find(v) and last_fm_turn[v] == -1 then
      last_fm_turn[v] = you.turns()
      monsters_to_mute[#monsters_to_mute+1] = v
    end
  end
end

function f_fm_monsters.ready()
  local activated = {}
  local deactivated = {}

  local hp, mhp = you.hp()
  local amulet = items.equipped_at("amulet")
  if amulet and amulet.name() == "amulet of guardian spirit" or you.race() == "Vine Stalker" then
    local mp, mmp = you.mp()
    hp = hp + mp
    mhp = mhp + mmp
  end
  local willpower = you.willpower()
  local res_mut = you.res_mutation()
  local res_pois = you.res_poison()
  local res_elec = you.res_shock()
  local res_corr = you.res_corr()
  local res_fire = you.res_fire()
  local res_cold = you.res_cold()
  local res_drain = you.res_draining()
  local int = you.intelligence()

  local is_zig_condition = CONFIG.disable_fm_monsters_in_zigs and you.branch() == "Zig"

  for i,v in ipairs(FM_PATTERNS) do
    local action = nil

    if is_zig_condition then
      action = "-"
    elseif not v.cond and not active_fm[i] then
      action = "+"
    elseif v.cond == "xl" then
      if active_fm[i] and you.xl() >= v.cutoff then action = "-"
      elseif not active_fm[i] and you.xl() < v.cutoff then action = "+"
      end
    elseif v.cond == "hp" then
      if active_fm[i] and hp >= v.cutoff then action = "-"
      elseif not active_fm[i] and hp < v.cutoff then action = "+"
      end
    elseif v.cond == "int" then
      if active_fm[i] and int >= v.cutoff then action = "-"
      elseif not active_fm[i] and int < v.cutoff then action = "+"
      end
    elseif v.cond == "will" then
      if active_fm[i] and willpower >= v.cutoff then action = "-"
      elseif not active_fm[i] and willpower < v.cutoff then action = "+"
      end
    elseif v.cond == "mut" then
      if active_fm[i] and res_mut > 0 then action = "-"
      elseif not active_fm[i] and res_mut == 0 then action = "+"
      end
    elseif v.cond == "pois" then
      if active_fm[i] and (res_pois > 0 or hp >= v.cutoff) then action = "-"
      elseif not active_fm[i] and res_pois == 0 and hp < v.cutoff then action = "+"
      end
    elseif v.cond == "elec" then
      if active_fm[i] and (res_elec > 0 or hp >= v.cutoff) then action = "-"
      elseif not active_fm[i] and res_elec == 0 and hp < v.cutoff then action = "+"
      end
    elseif v.cond == "corr" then
      if active_fm[i] and (res_corr or hp >= v.cutoff) then action = "-"
      elseif not active_fm[i] and not res_corr and hp < v.cutoff then action = "+"
      end
    elseif v.cond == "fire" then
      action = get_three_pip_action(active_fm[i], hp, v.cutoff, res_fire)
    elseif v.cond == "cold" then
      action = get_three_pip_action(active_fm[i], hp, v.cutoff, res_cold)
    elseif v.cond == "drain" then
      action = get_three_pip_action(active_fm[i], hp, v.cutoff, res_drain)
    end

    if action then
      fm_mon_str = nil
      local fm_name = v.pattern
      if v.name then fm_name = v.name end

      if type(v.pattern) == "table" then
        for _, p in ipairs(v.pattern) do
          if not fm_mon_str then
            fm_mon_str = p
          else
            fm_mon_str = fm_mon_str .. "|" .. p
          end
        end
      else
        fm_mon_str = v.pattern
      end

      set_monster_fm(action, fm_mon_str)
      active_fm[i] = not active_fm[i]

      if CONFIG.debug_fm_monsters then
        if action == "+" then
          activated[#activated+1] = fm_name
        elseif action == "-" then
          deactivated[#deactivated+1] = fm_name
        end
      end
    end
  end

  if CONFIG.debug_fm_monsters then
    if #activated > 0 then
      crawl.mpr("Activating force_mores: " .. table.concat(activated, ", "))
    end
    if #deactivated > 0 then
      crawl.mpr("Deactivating force_mores: " .. table.concat(deactivated, ", "))
    end
  end

  if CONFIG.fm_pack_duration > 0 then do_pack_mutes() end
end
