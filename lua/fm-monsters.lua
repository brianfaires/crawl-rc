------------------------------------------------------------------------------------------
------------------------------- Monster force_mores config -------------------------------
------------------------------------------------------------------------------------------
local function create_fm_string(monster_name)
  return "monster_warning:(?<!spectral )("..monster_name..")(?! (zombie|skeleton|simulacrum)).*comes? into view"
end

-- This stops on all Uniques & Pan lords
crawl.setopt("force_more_message += monster_warning:" ..
              "(?!Orb)(?!Guardian)(?-i:[A-Z]).*comes? into view")

---- Everything included in this list will cause a more() prompt.
---- It should contain monsters that always need alerts, regardless of HP, xl, willpower, and resistances
local force_more_monsters = {
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
    "swamp worm", "vault warden", "air elemental", "wendingo",
    "torpor snail", "water nymph", "shambling mangrove", "iron giant",
    "starflower", "merfolk aquamancer", "deep elf knight", "wretched star",
  --Dangerous clouds
    "catoblepas", "death drake", "apocalypse crab", "putrid mouth" }


-----------------------------------------------------------------------------------------
------------------------------- force_mores w/ turn delay -------------------------------
-----------------------------------------------------------------------------------------
-- The following monsters will only cause a force_more() once every # of turns; ie one alert per pack
local fm_delayed = { "dream sheep", "shrike", "boggart", "floating eye" }
local turns_to_delay = 10

local last_fm_turn = {}
local monsters_to_mute = {}

for v in iter.invent_iterator:new(fm_delayed) do
  crawl.setopt("force_more_message += "..create_fm_string(v))
  last_fm_turn[v] = -1
end

-------------------
------ Hooks ------
-------------------
function c_message_fm_delayed(text, _)
  for v in iter.invent_iterator:new(fm_delayed) do
    if text:find(v..".*comes? into view") and last_fm_turn[v] == -1 then
      last_fm_turn[v] = you.turns()
      monsters_to_mute[#monsters_to_mute+1] = v
    end
  end
end

function ready_fm_delayed()
  for v in iter.invent_iterator:new(monsters_to_mute) do
    crawl.setopt("force_more_message -= "..create_fm_string(v))
  end
  monsters_to_mute = {}

  for v in iter.invent_iterator:new(fm_delayed) do
    if you.turns() == last_fm_turn[v] + turns_to_delay then
	  crawl.setopt("force_more_message += "..create_fm_string(v))
	  last_fm_turn[v] = -1
	end
  end
end


------------------------------------------------------------------------------------------
------------------------------- Dynamic force_mores config -------------------------------
------------------------------------------------------------------------------------------
-- hp-specific force_mores() by gammafunk, extended by buehler
local fm_patterns = {
  -- Fast, early game Dungeon problems for chars with low mhp.
  {name = "30hp", cond = "hp", cutoff = 30, pattern = "hound"},

  -- Monsters dangerous until a certain point
  {name = "xl_7", cond = "xl", cutoff = 7, pattern = "orc wizard"},
  {name = "xl_12", cond = "xl", cutoff = 12, pattern = "hydra|bloated husk"},


  -- Monsters that can hit for ~50% of hp from range with unbranded attacks
  {name = "40hp", cond = "hp", cutoff = 40,
      pattern = "orc priest" },
  {name = "50hp", cond = "hp", cutoff = 50,
      pattern = "orc high priest|manticore" },
  {name = "70hp", cond = "hp", cutoff = 70,
      pattern = "meliai|yaktaur(?! captain)|cyclops|centaur(?! warrior)" },
  {name = "80hp", cond = "hp", cutoff = 80,
      pattern = "gargoyle" },
  {name = "90hp", cond = "hp", cutoff = 90,
      pattern = "deep elf archer|tengu conjurer" },
  {name = "110hp", cond = "hp", cutoff = 110,
      pattern = {"centaur warrior|yaktaur captain|hellion|eye of devastation|sun moth",
                  "deep elf high priest|deep troll earth mage|stone giant|cacodemon"} },
  {name = "120hp", cond = "hp", cutoff = 120,
      pattern = "quicksilver (dragon|elemental)|magenta draconian|thorn hunter" },
  {name = "160hp", cond = "hp", cutoff = 160,
      pattern = {"brimstone fiend|deep elf sorcerer",
              "hell sentinal|war gargoyle|draconian (knight|scorcher)"} },
  {name = "200hp", cond = "hp", cutoff = 200,
      pattern = "(draconian|deep elf) annihilator|iron (dragon|elemental)" },

  -- Monsters that can crowd-control you without sufficient willpower
  -- Cutoff ~10% for most spells; lower for more significant spells like banish
  {name = "willpower2", cond = "will", cutoff = 2,
      pattern = "basilisk|naga ritualist|vampire(?! bat)(?! mage)(?! mosquito)" },
  {name = "willpower3", cond = "will", cutoff = 3,
      pattern = {"deep elf (demonologist|sorcerer|archer)|(?<!orc )wizard|",
              "merfolk siren|fenstrider witch|great orb of eyes|cacodemon|"..
              "imperial myrmidon|sphinx|nagaraja|draconian shifter|"..
              "orange crystal statue|glowing orange brain|orc sorcerer|"..
              "ogre mage|satyr|vault sentinel|iron elemental|golden eye|"..
              "death knight|vampire knight" } },
  {name = "willpower4", cond = "will", cutoff = 4,
      pattern = "merfolk avatar|tainted leviathan|nargun" },

  -- Malmutate without rMut
  {name = "malmutate", cond = "mut", cutoff = 1,
      pattern = "cacodemon|neqoxec|shining eye" },

  -- Brain feed with low int
  {name = "brainfeed", cond = "int", cutoff = 6,
      pattern = "glowing orange brain|neqoxec|orange crystal statue" },

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

} -- end fm_patterns

----------------------------------------------------------------------------------
------------------------------- End config section -------------------------------
----------------------------------------------------------------------------------



-- Add the non-dynamic force_mores()  (moved code down here for easier configuration)
local fm_mon_str = nil
for v in iter.invent_iterator:new(force_more_monsters) do
  if fm_mon_str == nil then
    fm_mon_str = "monster_warning:(?<!spectral )("..v
  else
    fm_mon_str = fm_mon_str.."|"..v
  end
end
fm_mon_str = fm_mon_str..")(?! (zombie|skeleton|simulacrum)).*comes? into view"
crawl.setopt("force_more_message += "..fm_mon_str)




-- Set to true to get a message when the fm change
local notify_fm = false

-- Keep track of active force_mores()
local active_fm = {}
for _ in iter.invent_iterator:new(fm_patterns) do
  active_fm[#active_fm + 1] = false
end

-- Util for checks against resistance and hp
local function get_three_pip_action(active, hp, cutoff, res)
  local div = res+1
  if div == 4 then div = 5 end

  if active then
    if hp >= cutoff/div then return "-" end
  else
    if hp < cutoff/div then return "+" end
  end
end



--------------------------------------------
------------------- Hook -------------------
--------------------------------------------
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
  local int, _ = you.intelligence()

  for i,v in ipairs(fm_patterns) do
    local msg = nil
    if type(v.pattern) == "table" then
      for p in iter.invent_iterator:new(v.pattern) do
        if not msg then
          msg = p
        else
          msg = msg .. "|" .. p
        end
      end
    else
      msg = v.pattern
    end

    msg = create_fm_string(msg)

    local action = nil
    local fm_name = v.pattern
    if v.name then fm_name = v.name end

    if not v.cond and not active_fm[i] then
      action = "+"
    elseif v.cond == "xl" then
      if active_fm[i] and you.xl() >= v.cutoff then action = "-"
      elseif not active_fm[i] and you.xl() < v.cutoff then action = "+"
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


    if action == "+" then
      activated[#activated + 1] = fm_name
    elseif action == "-" then
      deactivated[#deactivated + 1] = fm_name
    end
    if action then
      local opt = "force_more_message " .. action .. "= " .. msg
      crawl.setopt(opt)
      active_fm[i] = not active_fm[i]
    end
  end
  if #activated > 0 and notify_fm then
    crawl.mpr("Activating force_mores: " .. table.concat(activated, ", "), "plain")
  end
  if #deactivated > 0 and notify_fm then
    crawl.mpr("Deactivating force_mores: " .. table.concat(deactivated, ", "), "plain")
  end
end
