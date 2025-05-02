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

COLORS = {
  darkgrey = "darkgrey", lightgrey = "lightgrey", white = "white",
  blue = "blue", lightblue = "lightblue", green = "green",
  lightgreen = "lightgreen", cyan = "cyan", lightcyan = "lightcyan",
  red = "red", lightred = "lightred", magenta = "magenta",
  lightmagenta = "lightmagenta", yellow = "yellow", brown = "brown",
  black = "black",
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