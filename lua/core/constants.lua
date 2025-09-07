-- Initialize
BRC = BRC or {}

---- Items ----
BRC.ALL_MISC_ITEMS = {
  "box of beasts",
  "condenser vane",
  "figurine of a ziggurat",
  "Gell's gravitambourine",
  "horn of Geryon",
  "lightning rod",
  "phantom mirror",
  "phial of floods",
  "sack of spiders",
  "tin of tremorstones",
} -- BRC.ALL_MISC_ITEMS (do not remove this comment)

-- This is checked against the full text of the pickup message, so use patterns to match
BRC.ALL_MISSILES = {
  "poisoned dart",
  "atropa-tipped dart",
  "curare-tipped dart",
  "datura-tipped dart",
  "darts? of disjunction",
  "darts? of dispersal",
  " stone",
  "boomerang",
  "silver javelin",
  "javelin",
  "large rock",
  "throwing net",
} -- BRC.ALL_MISSILES (do not remove this comment)

-- Could be removed after https://github.com/crawl/crawl/issues/4606 is addressed
BRC.ALL_SPELLBOOKS = {
  "parchment of",
  "book of",
  "Necronomicon",
  "Grand Grimoire",
  "tome of obsoleteness",
  "Everburning Encyclopedia",
  "Ozocubu's Autobiography",
  "Maxwell's Memoranda",
  "Young Poisoner's Handbook",
  "Fen Folio",
  "Inescapable Atlas",
  "There-And-Back Book",
  "Great Wizards, Vol. II",
  "Great Wizards, Vol. VII",
  "Trismegistus Codex",
  "the Unrestrained Analects",
  "Compendium of Siegecraft",
  "Codex of Conductivity",
  "Handbook of Applied Construction",
  "Treatise on Traps",
  "My Sojourn through Swampland",
  "Akashic Record",
  -- Include prefixes for randart books
  "Almanac",
  "Anthology",
  "Atlas",
  "Book",
  "Catalogue",
  "Codex",
  "Compendium",
  "Compilation",
  "Cyclopedia",
  "Directory",
  "Elucidation",
  "Encyclopedia",
  "Folio",
  "Grimoire",
  "Handbook",
  "Incunable",
  "Incunabulum",
  "Octavo",
  "Omnibus",
  "Papyrus",
  "Parchment",
  "Precepts",
  "Quarto",
  "Secrets",
  "Spellbook",
  "Tome",
  "Vellum",
  "Volume",
} -- BRC.ALL_SPELLBOOKS (do not remove this comment)

---- Races ----
BRC.ALL_UNDEAD_RACES = {
  "Demonspawn",
  "Mummy",
  "Poltergeist",
  "Revenant",
} -- BRC.ALL_UNDEAD_RACES (do not remove this comment)

BRC.ALL_NONLIVING_RACES = {
  "Djinni",
  "Gargoyle",
} -- BRC.ALL_NONLIVING_RACES (do not remove this comment)

BRC.ALL_POIS_RES_RACES = {
  "Djinni",
  "Gargoyle",
  "Mummy",
  "Naga",
  "Poltergeist",
  "Revenant",
} -- BRC.ALL_POIS_RES_RACES (do not remove this comment)

BRC.ALL_LITTLE_RACES = {
  "Spriggan",
} -- BRC.ALL_LITTLE_RACES (do not remove this comment)

BRC.ALL_SMALL_RACES = {
  "Kobold",
} -- BRC.ALL_SMALL_RACES (do not remove this comment)

BRC.ALL_LARGE_RACES = {
  "Armataur",
  "Naga",
  "Oni",
  "Troll",
} -- BRC.ALL_LARGE_RACES (do not remove this comment)

---- Skills ----
BRC.ALL_STAFF_SCHOOLS = {
  air = "Air Magic",
  alchemy = "Alchemy",
  cold = "Ice Magic",
  death = "Necromancy",
  earth = "Earth Magic",
  fire = "Fire Magic",
  conjuration = "Conjurations",
} -- BRC.ALL_STAFF_SCHOOLS (do not remove this comment)

BRC.ALL_TRAINING_SKILLS = {
  "Air Magic",
  "Alchemy",
  "Armour",
  "Axes",
  "Conjurations",
  "Dodging",
  "Earth Magic",
  "Evocations",
  "Fighting",
  "Fire Magic",
  "Forgecraft",
  "Hexes",
  "Ice Magic",
  "Invocations",
  "Long Blades",
  "Maces & Flails",
  "Necromancy",
  "Polearms",
  "Ranged Weapons",
  "Shapeshifting",
  "Shields",
  "Short Blades",
  "Spellcasting",
  "Staves",
  "Stealth",
  "Summonings",
  "Translocations",
  "Unarmed Combat",
  "Throwing",
} -- BRC.ALL_TRAINING_SKILLS (do not remove this comment)

BRC.ALL_WEAP_SCHOOLS = {
  "axes",
  "maces & flails",
  "polearms",
  "long blades",
  "short blades",
  "staves",
  "unarmed combat",
  "ranged weapons",
} -- BRC.ALL_WEAP_SCHOOLS (do not remove this comment)

---- Branches ----
BRC.ALL_PORTAL_NAMES = {
  "Bailey",
  "Bazaar",
  "Desolation",
  "Gauntlet",
  "Ice Cave",
  "Necropolis",
  "Ossuary",
  "Sewer",
  "Trove",
  "Volcano",
  "Wizlab",
  "Zig",
} -- BRC.ALL_PORTAL_NAMES (do not remove this comment)

BRC.ALL_HELL_BRANCHES = {
  "Coc",
  "Dis",
  "Geh",
  "Hell",
  "Tar",
} -- BRC.ALL_HELL_BRANCHES (do not remove this comment)

---- Egos ----
BRC.PLAIN_DMG_EGOS = { -- Cause extra damage without a damage type
  "distortion",
  "heavy",
  "spectralizing",
} -- BRC.PLAIN_DMG_EGOS (do not remove this comment)

BRC.ALL_RISKY_EGOS = {
  "chaos",
  "distortion",
  "harm",
  "heavy",
  "infusion",
  "ponderous",
} -- BRC.ALL_RISKY_EGOS (do not remove this comment)

---- Other ----
-- Would prefer to use integer values, but they don't work in all menus
BRC.KEYS = {
  LF = string.char(10),
  CR = string.char(13),
  explore = crawl.get_command("CMD_EXPLORE") or "o",
  save_game = crawl.get_command("CMD_SAVE_GAME") or "S",
  go_upstairs = crawl.get_command("CMD_GO_UPSTAIRS") or "<",
  go_downstairs = crawl.get_command("CMD_GO_DOWNSTAIRS") or ">",
} -- BRC.KEYS (do not remove this comment)

BRC.MUTATIONS = {
  antennae = "antennae",
  augmentation = "augmentation",
  beak = "beak",
  claws = "claws",
  deformed = "deformed body",
  demonic_touch = "demonic touch",
  hooves = "hooves",
  horns = "horns",
  missing_hand = "missing a hand",
  pseudopods = "pseudopods",
  sharp_scales = "sharp scales",
  sturdy_frame = "sturdy frame",
  talons = "talons",
} -- BRC.MUTATIONS (do not remove this comment)

BRC.SIZE_PENALTY = {
  LITTLE = -2,
  SMALL = -1,
  NORMAL = 0,
  LARGE = 1,
  GIANT = 2,
} -- BRC.SIZE_PENALTY (do not remove this comment)

BRC.COLORS = {
  blue = "blue",
  green = "green",
  cyan = "cyan",
  red = "red",
  magenta = "magenta",
  brown = "brown",
  lightgrey = "lightgrey",
  darkgrey = "darkgrey",
  lightblue = "lightblue",
  lightgreen = "lightgreen",
  lightcyan = "lightcyan",
  lightred = "lightred",
  lightmagenta = "lightmagenta",
  yellow = "yellow",
  white = "w",
  black = "black",
} -- BRC.COLORS (do not remove this comment)

BRC.DMG_TYPE = {
  unbranded = 1, -- No brand
  plain = 2, -- Include brand dmg with no associated damage type
  branded = 3, -- Include full brand dmg
  scoring = 4, -- Include boosts for non-damaging brands
} -- BRC.DMG_TYPE (do not remove this comment)
