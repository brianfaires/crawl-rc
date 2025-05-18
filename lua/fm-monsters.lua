------------------- Dynamic force_mores config -------------------
-- hp-specific force_mores() by gammafunk, edits by buehler
-- WARNING: Never put a '}' on a line by itself. This breaks crawl's RC parser.
-- Note: If you want an alert to silenceable by the fm_pack feature,
-- It must be on an alert by itself (not part of a multi-monster pattern)
local debug_fm_monsters = false -- Set to true to get a message when the fm change
local turns_to_delay = 15 -- Turns before alerting for a pack monster again

-- Stop on all Uniques & Pan lords
crawl.setopt("force_more_message += monster_warning:" ..
              "(?-i:[A-Z]).*comes? into view")

-- Always screen flash
local always_flash_screen_monsters = {
  -- Noteworthy abilities
  "vault warden", "vault guardian", "ghost crab"
} -- always_flash_screen_monsters (do not remove this comment)

-- Always more prompt
local always_force_more_monsters = {
  -- High damage/speed
    "juggernaut", "orbs? of fire", "flayed ghost",
  -- Torment
    "tormentor", "curse (toe|skull)", "Fiend", "tzitzimi", "royal mummy",
    "mummy priest", "(dread|ancient) lich", "lurking horror",
  --Summoning
    "shadow demon", "guardian serpent", "ironbound convoker",
    "draconian stormcaller", "spriggan druid", "dryad", "worldbinder",
    "halazid warlock", "deep elf elementalist", "demonspawn corrupter",
    "elemental wellspring",
  --Dangerous abilities
    "swamp worm", "air elemental", "wendingo", "wyrmhole",
    "torpor snail", "water nymph", "shambling mangrove", "iron giant",
    "starflower", "merfolk aquamancer", "deep elf knight", "wretched star",
  --Dangerous clouds
    "catoblepas", "death drake", "apocalypse crab", "putrid mouth",
} -- always_force_more_monsters (do not remove this comment)

-- Only alert once per pack
local fm_pack = {
  "dream sheep", "shrike", "boggart", "floating eye"
} -- fm_pack (do not remove this comment)

-- Once per pack, but alerts created through dynamic adds
local fm_pack_no_init_add = {
  "electric eel", "golden eye", "great orb of eyes"
} -- fm_pack_no_init_add (do not remove this comment)


local fm_patterns = {
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
  {name = "70hp", cond = "hp", cutoff = 70,
      pattern = "yaktaur(?! captain)|cyclops|centaur(?! warrior)" },
  {name = "70hp_melai", cond = "hp", cutoff = 70,
      pattern = "meliai"},
  {name = "80hp", cond = "hp", cutoff = 80,
      pattern = "gargoyle" },
  {name = "90hp", cond = "hp", cutoff = 90,
      pattern = "deep elf archer|tengu conjurer" },
  {name = "110hp", cond = "hp", cutoff = 110,
      pattern = "centaur warrior|yaktaur captain|hellion|eye of devastation|sun moth"..
                  "deep elf high priest|deep troll earth mage|stone giant|cacodemon" },
  {name = "120hp", cond = "hp", cutoff = 120,
      pattern = "quicksilver (dragon|elemental)|magenta draconian|thorn hunter" },
  {name = "160hp", cond = "hp", cutoff = 160,
      pattern = "brimstone fiend|deep elf sorcerer"..
              "hell sentinal|war gargoyle|draconian (knight|scorcher)" },
  {name = "200hp", cond = "hp", cutoff = 200,
      pattern = "(draconian|deep elf) annihilator|iron (dragon|elemental)" },

  -- Monsters that can crowd-control you without sufficient willpower
  -- Cutoff ~10% for most spells; lower for more significant spells like banish
  {name = "willpower2", cond = "will", cutoff = 2,
      pattern = "basilisk|naga ritualist|vampire(?! bat)(?! mage)(?! mosquito)|sphinx marauder" },
  {name = "willpower3", cond = "will", cutoff = 3,
      pattern = "deep elf (demonologist|sorcerer|archer)|(?<!orc )wizard|"..
              "merfolk siren|fenstrider witch|cacodemon|"..
              "imperial myrmidon|guardian sphinx|nagaraja|draconian shifter|"..
              "glowing orange brain|orc sorcerer|"..
              "ogre mage|satyr|vault sentinel|iron elemental|"..
              "death knight|vampire knight" },
  {name = "willpower3_great_orb_of_eyes", cond = "will", cutoff = 3,
      pattern = "great orb of eyes" },
  {name = "willpower3_golden_eye", cond = "will", cutoff = 3,
      pattern = "golden eye" },
  {name = "willpower4", cond = "will", cutoff = 4,
      pattern = "merfolk avatar|tainted leviathan|nargun" },

  -- Malmutate without rMut
  {name = "malmutate", cond = "mut", cutoff = 1,
      pattern = "cacodemon|neqoxec|shining eye" },
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
      pattern = "black draconian|blizzard demon|deep elf zephyrmancer|"..
                "storm dragon|tengu conjurer" },
  {name = "elec_140", cond = "elec", cutoff = 140,
      pattern = "electric golem|titan|servants? of whisper|spriggan air mage|"..
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
      pattern = "orc sorcerer|hell hound|demonspawn blood saint|red draconian|"..
                "ogre mage|molten gargoyle|hell knight" },
  {name = "fire_140", cond = "fire", cutoff = 140,
      pattern = "balrug" },
  {name = "fire_160", cond = "fire", cutoff = 160,
      pattern = "will-o-the-wisp|ophan|fire giant|golden dragon|"..
                "fire dragon|salamander tyrant|tengu reaver" },
  {name = "fire_240", cond = "fire", cutoff = 240,
      pattern = "hellephant|crystal (guardian|echidna)|draconian scorcher" },

  {name = "cold_80", cond = "cold", cutoff = 80,
      pattern = "rime drake" },
  {name = "cold_120", cond = "cold", cutoff = 120,
      pattern = "blizzard demon|bog body|ironbound frostheart|"..
                "demonspawn blood saint|white draconian" },
  {name = "cold_160", cond = "cold", cutoff = 160,
      pattern = "golden dragon|draconian knight|frost giant|ice dragon|tengu reaver" },
  {name = "cold_180", cond = "cold", cutoff = 180,
      pattern = "(?>!dread)(?>!ancient) lich" },
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
------------------- End config section -------------------

local active_fm = {} -- which ones are on
local active_fm_index = {} -- lookup table for speed
local monsters_to_mute = {} -- which packs are muted
local last_fm_turn = {} -- when the mute started


local function set_monster_option(sign, monster_str, option)
  local fm_str = "monster_warning:(?<!spectral )("..monster_str..
      ")(?! (zombie|skeleton|simulacrum)).*comes? into view"
  crawl.setopt(option .. " " .. sign .. "= "..fm_str)
end

local function set_monster_fm(sign, monster_str)
  set_monster_option(sign, monster_str, "force_more_message")
end

local function set_monster_flash(sign, monster_str)
  set_monster_option(sign, monster_str, "flash_screen_message")
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

local function get_three_pip_action(active, hp, cutoff, res)
  -- Util for checks against resistance and hp
  local div = res+1
  if div == 4 then div = 5 end

  if active then
    if hp >= cutoff/div then return "-" end
  else
    if hp < cutoff/div then return "+" end
  end
end


------------------- Hooks -------------------
function ready_force_mores()
  local activated = {}
  local deactivated = {}

  local hp, maxhp = you.hp()
  local willpower = you.willpower()
  local res_mut = you.res_mutation()
  local res_pois = you.res_poison()
  local res_elec = you.res_shock()
  local res_corr = you.res_corr()
  local res_fire = you.res_fire()
  local res_cold = you.res_cold()
  local res_drain = you.res_draining()
  local int, _ = l_cache.int

  for i,v in ipairs(fm_patterns) do
    local action = nil

    if not v.cond and not active_fm[i] then
      action = "+"
    elseif v.cond == "xl" then
      if active_fm[i] and l_cache.xl >= v.cutoff then action = "-"
      elseif not active_fm[i] and l_cache.xl < v.cutoff then action = "+"
      end
    elseif v.cond == "maxhp" then
      if active_fm[i] and maxhp >= v.cutoff then action = "-"
      elseif not active_fm[i] and maxhp < v.cutoff then action = "+"
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

      if debug_fm_monsters then
        if action == "+" then
          activated[#activated + 1] = fm_name
        elseif action == "-" then
          deactivated[#deactivated + 1] = fm_name
        end
      end
    end
  end

  if debug_fm_monsters then
    if #activated > 0 then
      crawl.mpr("Activating force_mores: " .. table.concat(activated, ", "), "plain")
    end
    if #deactivated > 0 then
      crawl.mpr("Deactivating force_mores: " .. table.concat(deactivated, ", "), "plain")
    end
  end
end

function c_message_fm_pack(text, _)
  -- Identifies when a mute should be turned on
  if not text:find("comes? into view") then return end
  for _, v in ipairs(fm_pack) do
    if text:find(v) and last_fm_turn[v] == -1 then
      last_fm_turn[v] = you.turns()
      monsters_to_mute[#monsters_to_mute+1] = v
    end
  end
end

function ready_fm_pack()
  -- Put pending mutes into effect
  for _, v in ipairs(monsters_to_mute) do
    set_monster_fm("-", v)
  end
  monsters_to_mute = {}

  -- Remove mutes that have expired
  for _, v in ipairs(fm_pack) do
    if you.turns() == last_fm_turn[v] + turns_to_delay then
      set_monster_fm("+", v)
      last_fm_turn[v] = -1
    end
  end

  -- For no-init pack monsters, just deactivate the fm
  for _, v in ipairs(fm_pack_no_init_add) do
    if you.turns() == last_fm_turn[v] + turns_to_delay then
      active_fm[active_fm_index[v]] = false
      last_fm_turn[v] = -1
    end
  end
end


------ Startup code ------
set_all(always_flash_screen_monsters, "flash_screen_message")
set_all(always_force_more_monsters, "force_more_message")

-- Init packs
for _, v in ipairs(fm_pack) do
  set_monster_fm("+", v)
  last_fm_turn[v] = -1
end

for _,v in ipairs(fm_pack_no_init_add) do
  fm_pack[#fm_pack+1] = v
  last_fm_turn[v] = -1
end

-- Build table of indexes, used for fm_pack logic
for i,v in ipairs(fm_patterns) do
  if not v.pattern:find("|") then
    active_fm_index[v.pattern] = i
  end
end

-- Init all active_fm to false
for _,_ in ipairs(fm_patterns) do
  active_fm[#active_fm + 1] = false
end
