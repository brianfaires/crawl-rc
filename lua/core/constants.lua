--[[
BRC Constants - All constant definitions
Author: buehler
Dependencies: (none)
--]]

---- Initialize BRC namespace
BRC = BRC or {}

---- Cosmetic settings
BRC.EMOJI = {
  CAUTION = BRC.Config.emojis and "⚠️" or "<yellow>!</yellow>",
  EXCLAMATION = BRC.Config.emojis and "❗" or "<magenta>!</magenta>",
  EXCLAMATION_2 = BRC.Config.emojis and "‼️" or "<lightmagenta>!!</lightmagenta>",
  SUCCESS = BRC.Config.emojis and "✅" or nil,
} -- BRC.EMOJI (do not remove this comment)

---- Items ----
BRC.MISC_ITEMS = {
  "box of beasts", "condenser vane", "figurine of a ziggurat", "Gell's gravitambourine",
  "horn of Geryon", "lightning rod", "phantom mirror", "phial of floods", "sack of spiders",
  "tin of tremorstones",
} -- BRC.MISC_ITEMS (do not remove this comment)

-- This is checked against the full text of the pickup message, so use patterns to match
BRC.MISSILES = {
  "poisoned dart", "atropa-tipped dart", "curare-tipped dart", "datura-tipped dart",
  "darts? of disjunction", "darts? of dispersal", " stone", "boomerang",
  "silver javelin", "javelin", "large rock", "throwing net",
} -- BRC.MISSILES (do not remove this comment)

-- Could be removed after https://github.com/crawl/crawl/issues/4606 is addressed
BRC.SPELLBOOKS = {
  "parchment of", "book of", "Necronomicon", "Grand Grimoire", "tome of obsoleteness",
  "Everburning Encyclopedia", "Ozocubu's Autobiography", "Maxwell's Memoranda",
  "Young Poisoner's Handbook", "Fen Folio", "Inescapable Atlas", "There-And-Back Book",
  "Great Wizards, Vol. II", "Great Wizards, Vol. VII", "Trismegistus Codex",
  "the Unrestrained Analects", "Compendium of Siegecraft", "Codex of Conductivity",
  "Handbook of Applied Construction", "Treatise on Traps", "My Sojourn through Swampland",
  "Akashic Record",
  -- Include prefixes for randart books
  "Almanac", "Anthology", "Atlas", "Book", "Catalogue", "Codex", "Compendium",
  "Compilation", "Cyclopedia", "Directory", "Elucidation", "Encyclopedia", "Folio",
  "Grimoire", "Handbook", "Incunable", "Incunabulum", "Octavo", "Omnibus", "Papyrus",
  "Parchment", "Precepts", "Quarto", "Secrets", "Spellbook", "Tome", "Vellum", "Volume",
} -- BRC.SPELLBOOKS (do not remove this comment)

---- Races ----
BRC.UNDEAD_RACES = { "Demonspawn", "Mummy", "Poltergeist", "Revenant", }
BRC.NONLIVING_RACES = { "Djinni", "Gargoyle", }
BRC.POIS_RES_RACES = { "Djinni", "Gargoyle", "Mummy", "Naga", "Poltergeist", "Revenant", }
BRC.LITTLE_RACES = { "Spriggan", }
BRC.SMALL_RACES = { "Kobold", }
BRC.LARGE_RACES = { "Armataur", "Naga", "Oni", "Troll", }

---- Skills ----
BRC.STAFF_SCHOOLS = {
  air = "Air Magic", alchemy = "Alchemy", cold = "Ice Magic", necromancy = "Necromancy",
  earth = "Earth Magic", fire = "Fire Magic", conjuration = "Conjurations",
} -- BRC.STAFF_SCHOOLS (do not remove this comment)

BRC.TRAINING_SKILLS = {
  "Air Magic", "Alchemy", "Armour", "Axes", "Conjurations", "Dodging", "Earth Magic",
  "Evocations", "Fighting", "Fire Magic", "Forgecraft", "Hexes", "Ice Magic",
  "Invocations", "Long Blades", "Maces & Flails", "Necromancy", "Polearms",
  "Ranged Weapons", "Shapeshifting", "Shields", "Short Blades", "Spellcasting", "Staves",
  "Stealth", "Summonings", "Translocations", "Unarmed Combat", "Throwing",
} -- BRC.TRAINING_SKILLS (do not remove this comment)

BRC.WEAP_SCHOOLS = {
  "axes", "maces & flails", "polearms", "long blades", "short blades",
  "staves", "unarmed combat", "ranged weapons",
} -- BRC.WEAP_SCHOOLS (do not remove this comment)

---- Branches ----
BRC.HELL_BRANCHES = { "Coc", "Dis", "Geh", "Hell", "Tar", }
BRC.PORTAL_NAMES = {
  "Bailey", "Bazaar", "Desolation", "Gauntlet", "Ice Cave", "Necropolis",
  "Ossuary", "Sewer", "Trove", "Volcano", "Wizlab", "Zig",
} -- BRC.PORTAL_NAMES (do not remove this comment)

---- Egos + artefact properties ----
BRC.RISKY_EGOS = { "antimagic", "chaos", "distort", "harm", "heavy", "Infuse", "Ponderous", }
BRC.NON_ELEMENTAL_DMG_EGOS = { "distort", "heavy", "spect", }
BRC.BAD_ART_PROPS = {
  "Bane", "-Cast", "-Move", "-Tele",
  "*Corrode", "*Noise", "*Rage", "*Silence", "*Slow", "*Tele",
} -- BRC.BAD_ART_PROPS (do not remove this comment)

---- Other ----
-- BRC.COLOR:Would prefer to use integer values, but they don't work in all menus
BRC.COLOR = {
  black = "0", blue = "1", green = "2", cyan = "3", red = "4", magenta = "5", brown = "6",
  lightgrey = "7", darkgrey = "8", lightblue = "9", lightgreen = "10",
  lightcyan = "11", lightred = "12", lightmagenta = "13", yellow = "14", white = "15",
} -- BRC.COLOR (do not remove this comment)

BRC.DMG_TYPE = {
  unbranded = 1, -- No brand
  plain = 2, -- Include brand dmg with no associated damage type
  branded = 3, -- Include full brand dmg
  scoring = 4, -- Include boosts for non-damaging brands
} -- BRC.DMG_TYPE (do not remove this comment)

BRC.SIZE_PENALTY = { LITTLE = -2, SMALL = -1, NORMAL = 0, LARGE = 1, GIANT = 2, }
