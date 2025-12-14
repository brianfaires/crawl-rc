---------------------------------------------------------------------------------------------------
-- BRC core module
-- @module BRC
-- Constants and definitions used throughout BRC.
---------------------------------------------------------------------------------------------------

---- Cosmetic settings
BRC.EMOJI = {}
BRC.init_emojis = function()
  if BRC.Config.emojis then
    BRC.EMOJI.CAUTION = "⚠️"
    BRC.EMOJI.EXCLAMATION = "❗"
    BRC.EMOJI.EXCLAMATION_2 = "‼️"
    BRC.EMOJI.SUCCESS = "✅"
  else
    BRC.EMOJI.CAUTION = "<!yellow>!</yellow>"
    BRC.EMOJI.EXCLAMATION = "<!magenta>!</magenta>"
    BRC.EMOJI.EXCLAMATION_2 = "<!lightmagenta>!!</lightmagenta>"
    BRC.EMOJI.SUCCESS = nil
  end
end

---- Items ----
BRC.MISC_ITEMS = {
  "box of beasts", "condenser vane", "figurine of a ziggurat", "Gell's gravitambourine",
  "horn of Geryon", "lightning rod", "phantom mirror", "phial of floods", "sack of spiders",
  "tin of tremorstones",
} -- BRC.MISC_ITEMS (do not remove this comment)

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
BRC.UNDEAD_RACES = { "Demonspawn", "Mummy", "Poltergeist", "Revenant" }
BRC.NONLIVING_RACES = { "Djinni", "Gargoyle" }
BRC.POIS_RES_RACES = { "Djinni", "Gargoyle", "Mummy", "Naga", "Poltergeist", "Revenant" }
BRC.LITTLE_RACES = { "Spriggan" }
BRC.SMALL_RACES = { "Kobold" }
BRC.LARGE_RACES = { "Armataur", "Naga", "Oni", "Troll" }

---- Skills ----
BRC.MAGIC_SCHOOLS = {
  air = "Air Magic", alchemy = "Alchemy", cold = "Ice Magic", conjuration = "Conjurations",
  death = "Necromancy", earth = "Earth Magic", fire = "Fire Magic", necromancy = "Necromancy",
} -- BRC.MAGIC_SCHOOLS (do not remove this comment)

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
BRC.HELL_BRANCHES = { "Coc", "Dis", "Geh", "Hell", "Tar" }
BRC.PORTAL_FEATURE_NAMES = {
  "Bailey", "Bazaar", "Desolation", "Gauntlet", "IceCv", "Necropolis", "Ossuary",
  "Sewer", "Trove", "Volcano", "Wizlab", "Zig",
} -- BRC.PORTAL_FEATURE_NAMES (do not remove this comment)

---- Egos ----
BRC.RISKY_EGOS = { "antimagic", "chaos", "distort", "harm", "heavy", "Infuse", "Ponderous" }
BRC.NON_ELEMENTAL_DMG_EGOS = { "distort", "heavy", "spect" }
BRC.ADJECTIVE_EGOS = { -- Egos whose English modifier comes before item name
  antimagic = "antimagic", heavy = "heavy", spectralising = "spectral", vampirism = "vampiric"
} -- BRC.ADJECTIVE_EGOS (do not remove this comment)

---- Artefact properties ----
BRC.ARTPROPS_BAD = {
  "Bane", "-Cast", "-Move", "-Tele",
  "*Corrode", "*Noise", "*Rage", "*Silence", "*Slow", "*Tele",
} -- BRC.ARTPROPS_BAD (do not remove this comment)

BRC.ARTPROPS_EGO = { -- Corresponding ego
  rF = "fire resistance", rC = "cold resistance", rPois = "poison resistance",
  rN = "positive energy", rCorr = "corrosion resistance",
  Archmagi = "the Archmagi", Rampage = "rampaging", Will = "willpower",
  Air = "air", Earth = "earth", Fire = "fire", Ice = "ice", Necro = "death", Summ = "command",
} -- BRC.ARTPROPS_EGO (do not remove this comment)

---- Other ----
BRC.KEYS = { ENTER = 13, ESC = 27, ["Cntl-S"] = 20, ["Cntl-E"] = 5 }

BRC.COL = {
  black = "0", blue = "1", green = "2", cyan = "3", red = "4", magenta = "5", brown = "6",
  lightgrey = "7", darkgrey = "8", lightblue = "9", lightgreen = "10",
  lightcyan = "11", lightred = "12", lightmagenta = "13", yellow = "14", white = "15",
} -- BRC.COL (do not remove this comment)

BRC.DMG_TYPE = {
  unbranded = 1, -- No brand
  plain = 2, -- Include brand dmg for non-elemental brands
  branded = 3, -- Include full brand dmg
  scoring = 4, -- Include boosts for non-damaging brands
} -- BRC.DMG_TYPE (do not remove this comment)

BRC.SIZE_PENALTY = { LITTLE = -2, SMALL = -1, NORMAL = 0, LARGE = 1, GIANT = 2 }
