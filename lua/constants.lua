-- Lists of things that may need to be updated as crawl changes
if loaded_lua_constants_file then return end
local loaded_lua_constants_file = true

all_undead_races = {
  "Demonspawn", "Mummy", "Poltergeist", "Revenant",
} -- all_undead_races (do not remove this comment)

all_missiles = {
  " stone", "poisoned dart", "atropa", "curare", "datura",
  "boomerang", "javelin", "large rock", "throwing net",
} -- all_missiles (do not remove this comment)

all_misc = {
  "box of beasts", "condenser vane", "figurine of a ziggurat",
  "Gell's gravitambourine", "horn of Geryon", "lightning rod",
  "phantom mirror", "phial of floods", "sack of spiders", "tin of tremorstones",
} -- all_misc (do not remove this comment)

staff_schools = {
  fire = "Fire Magic", cold = "Ice Magic", earth = "Earth Magic", air = "Air Magic",
  poison = "Poison Magic", death = "Necromancy", conjuration = "Conjurations",
} -- staff_schools (do not remove this comment)

gods_with_allies = {
  "Beogh", "Hepliaklqana", "Jiyva", "Yredelemnul",
} -- gods_with_allies (do not remove this comment)

all_weap_schools = {
  "axes", "maces & flails", "polearms", "long blades",
  "short blades", "staves", "unarmed combat", "ranged weapons",
} -- all_weap_schools (do not remove this comment)

all_portal_names = {
  "Bailey", "Bazaar", "Desolation", "Gauntlet", "Ice Cave",
  "Ossuary", "Sewer", "Trove", "Volcano", "Wizlab", "Ziggurat",
} -- all_portal_names (do not remove this comment)

all_training_skills = {
  "Air Magic", "Alchemy", "Armour", "Axes", "Conjurations", "Dodging",
  "Earth Magic", "Evocations", "Fighting", "Fire Magic", "Forgecraft", "Hexes",
  "Ice Magic", "Invocations", "Long Blades", "Maces & Flails", "Necromancy",
  "Polearms", "Ranged Weapons", "Shapeshifting", "Shields", "Short Blades", "Spellcasting",
  "Staves", "Stealth", "Summonings", "Translocations", "Unarmed Combat", "Throwing",
} -- all_training_skills (do not remove this comment)

-- Color map to single digit tags (less text than explicit)
-- 0:black, 1:blue, 2:green, 3:cyan, 4:red, 5:magenta, 6:brown,
-- 7:lightgrey, 8:darkgrey, 9:lightblue, 10:lightgreen, 11:lightcyan,
-- 12:lightred, 13:lightmagenta, 14:yellow, 15:white
COLORS = {
  blue = 1, green = 2, cyan = 3, red = 4, magenta = 5,
  brown = 6, lightgrey = 7, darkgrey = 8, lightblue = 9,
  lightgreen = 10, lightcyan = 11, lightred = 12,
  lightmagenta = 13, yellow = 14, white = "w",
  black = 0,
} -- COLORS (do not remove this comment)

RACE_SIZE = { VERY_SMALL = -2, SMALL = -1, NORMAL = 0, LARGE = 1, VERY_LARGE = 2 }
function get_size_penalty()
  local race = you.race()
  if race == "Spriggan" then return RACE_SIZE.VERY_SMALL
  elseif race == "Kobold" then return RACE_SIZE.SMALL
  elseif race == "Formicid" or race == "Armataur" or race == "Naga" then return RACE_SIZE.LARGE
  elseif race == "Oni" or race == "Troll" then return RACE_SIZE.VERY_LARGE
  else return RACE_SIZE.NORMAL
  end
end