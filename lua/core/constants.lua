-- Lists of things that may need to be updated with future changes
BUEHLER_RC_VERSION = "1.0"

---- Items ----
ALL_MISC_ITEMS = {
  "box of beasts", "condenser vane", "figurine of a ziggurat",
  "Gell's gravitambourine", "horn of Geryon", "lightning rod",
  "phantom mirror", "phial of floods", "sack of spiders", "tin of tremorstones",
} -- ALL_MISC_ITEMS (do not remove this comment)

-- This is checked against the full text of the pickup message, so use patterns to match
ALL_MISSILES = {
  "poisoned dart", "atropa-tipped dart", "curare-tipped dart", "datura-tipped dart", "darts? of dispersal",
  " stone", "boomerang", "silver javelin", "javelin", "large rock", "throwing net",
} -- ALL_MISSILES (do not remove this comment)

-- Could be removed after https://github.com/crawl/crawl/issues/4606 is addressed
ALL_SPELLBOOKS = {
  "book of", "Necronomicon", "Grand Grimoire", "tome of obsoleteness", "Everburning Encyclopedia",
  "Ozocubu's Autobiography", "Maxwell's Memoranda", "Young Poisoner's Handbook", "Fen Folio",
  "Inescapable Atlas", "There-And-Back Book", "Great Wizards, Vol. II", "Great Wizards, Vol. VII",
  "Trismegistus Codex", "the Unrestrained Analects", "Compendium of Siegecraft", "Codex of Conductivity",
  "Handbook of Applied Construction", "Treatise on Traps", "My Sojourn through Swampland", "Akashic Record",
  -- Include prefixes for randart books
  "Almanac", "Anthology", "Atlas", "Book", "Catalogue", "Codex", "Compendium", "Compilation", "Cyclopedia",
  "Directory", "Elucidation", "Encyclopedia", "Folio", "Grimoire", "Handbook", "Incunable", "Incunabulum",
  "Octavo", "Omnibus", "Papyrus", "Parchment", "Precepts", "Quarto", "Secrets", "Spellbook", "Tome", "Vellum",
  "Volume",
} -- ALL_SPELLBOOKS (do not remove this comment)


---- Races ----
ALL_UNDEAD_RACES = {
  "Demonspawn", "Mummy", "Poltergeist", "Revenant",
} -- ALL_UNDEAD_RACES (do not remove this comment)

ALL_LITTLE_RACES = {
  "Spriggan",
} -- ALL_LITTLE_RACES (do not remove this comment)

ALL_SMALL_RACES = {
  "Kobold",
} -- ALL_SMALL_RACES (do not remove this comment)

ALL_LARGE_RACES = {
  "Armataur", "Naga", "Oni", "Troll",
} -- ALL_LARGE_RACES (do not remove this comment)


---- Skills ----
ALL_STAFF_SCHOOLS = {
  fire = "Fire Magic", cold = "Ice Magic", earth = "Earth Magic", air = "Air Magic",
  poison = "Poison Magic", death = "Necromancy", conjuration = "Conjurations",
} -- ALL_STAFF_SCHOOLS (do not remove this comment)

ALL_TRAINING_SKILLS = {
  "Air Magic", "Alchemy", "Armour", "Axes", "Conjurations", "Dodging",
  "Earth Magic", "Evocations", "Fighting", "Fire Magic", "Forgecraft", "Hexes",
  "Ice Magic", "Invocations", "Long Blades", "Maces & Flails", "Necromancy",
  "Polearms", "Ranged Weapons", "Shapeshifting", "Shields", "Short Blades", "Spellcasting",
  "Staves", "Stealth", "Summonings", "Translocations", "Unarmed Combat", "Throwing",
} -- ALL_TRAINING_SKILLS (do not remove this comment)

ALL_WEAP_SCHOOLS = {
  "axes", "maces & flails", "polearms", "long blades",
  "short blades", "staves", "unarmed combat", "ranged weapons",
} -- ALL_WEAP_SCHOOLS (do not remove this comment)


---- Other ----
ALL_PORTAL_NAMES = {
  "Bailey", "Bazaar", "Desolation", "Gauntlet", "Ice Cave", "Necropolis",
  "Ossuary", "Sewer", "Trove", "Volcano", "Wizlab", "Ziggurat",
} -- ALL_PORTAL_NAMES (do not remove this comment)

-- Would prefer to use integer values, but they don't work in all menus
COLORS = {
  blue = "blue", green = "green", cyan = "cyan", red = "red", magenta = "magenta",
  brown = "brown", lightgrey = "lightgrey", darkgrey = "darkgrey", lightblue = "lightblue",
  lightgreen = "lightgreen", lightcyan = "lightcyan", lightred = "lightred",
  lightmagenta = "lightmagenta", yellow = "yellow", white = "w",
  black = 0,
} -- COLORS (do not remove this comment)

DANGEROUS_BRANDS = {
  "chaos", "distortion", "harm", "infusion"
} -- DANGEROUS_BRANDS (do not remove this comment)

GODS_WITH_ALLIES = {
  "Beogh", "Hepliaklqana", "Jiyva", "Yredelemnul",
} -- GODS_WITH_ALLIES (do not remove this comment)

KEYS = {
  LF = string.char(10), CR = string.char(13)
} -- KEYS (do not remove this comment)

MUTS = {
  antennae = "antennae", augmentation = "augmentation", beak = "beak", claws = "claws",
  deformed = "deformed body", demonic_touch = "demonic touch", hooves = "hooves",
  horns = "horns", missing_hand = "missing a hand", pseudopods = "pseudopods",
  sharp_scales = "sharp scales", sturdy_frame = "sturdy frame", talons = "talons"
} -- MUTS (do not remove this comment)

SIZE_PENALTY = {
  LITTLE = -2, SMALL = -1, NORMAL = 0, LARGE = 1, GIANT = 2
} -- SIZE_PENALTY (do not remove this comment)
