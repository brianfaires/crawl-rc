---------------------------------------------------------------------------------------------------
-- BRC feature module: dynamic-options
-- @module f_dynamic_options
-- Contains options that change based on game state: xl, class, race, god, skills.
---------------------------------------------------------------------------------------------------

f_dynamic_options = {}
f_dynamic_options.BRC_FEATURE_NAME = "dynamic-options"
f_dynamic_options.Config = {
  meaningful_spellcasting_skill = 5, -- Skill level to switch on "spellcaster-specific" options

  --- XL-based force more messages: patterns active when XL <= specified level
  xl_force_mores = {
    { pattern = "monster_warning:wielding.*of electrocution", xl = 5 },
    { pattern = "You.*re more poisoned", xl = 7 },
    { pattern = "^(?!.*Your?).*speeds? up", xl = 10 },
    { pattern = "danger:goes berserk", xl = 18 },
    { pattern = "monster_warning:carrying a wand of", xl = 15 },
  },

  --- Call each function for the corresponding race
  race_options = {
    Gnoll = function()
      BRC.opt.message_mute("intrinsic_gain:skill increases to level", true)
    end,
  },

  --- Call each function for the corresponding class
  class_options = {
    Hunter = function()
      crawl.setopt("view_delay = 30")
    end,
    Shapeshifter = function()
      BRC.opt.autopickup_exceptions("<flux bauble", true)
    end,
  },

  --- Call each function when joining/leaving a god
  god_options = {
    ["No God"] = function(joined)
      BRC.opt.force_more_message("Found.*the Ecumenical Temple", not joined)
      BRC.opt.flash_screen_message("Found.*the Ecumenical Temple", joined)
      BRC.opt.runrest_stop_message("Found.*the Ecumenical Temple", joined)
    end,
    Beogh = function(joined)
      BRC.opt.runrest_ignore_message("no longer looks.*", joined)
      BRC.opt.force_more_message("Your orc.*dies", joined)
    end,
    Cheibriados = function(joined)
      BRC.util.add_or_remove(BRC.RISKY_EGOS, "Ponderous", not joined)
    end,
    Jiyva = function(joined)
      BRC.opt.flash_screen_message("god:splits in two", joined)
      BRC.opt.message_mute("You hear a.*(slurping|squelching) noise", joined)
    end,
    Lugonu = function(joined)
      BRC.util.add_or_remove(BRC.RISKY_EGOS, "distort", not joined)
    end,
    Trog = function(joined)
      BRC.util.add_or_remove(BRC.ARTPROPS_BAD, "-Cast", not joined)
      BRC.util.add_or_remove(BRC.RISKY_EGOS, "antimagic", not joined)
    end,
    Xom = function(joined)
      BRC.opt.flash_screen_message("god:", joined)
    end,
  },
} -- f_dynamic_options.Config (do not remove this comment)

---- Local constants ----
local IGNORE_SPELLBOOKS_STRING = table.concat(BRC.SPELLBOOKS, ", ")
local HIGH_LVL_MAGIC_STRING = "scrolls? of amnesia, potions? of brilliance, ring of wizardry"

---- Local variables ----
local C -- config alias
local cur_god
local ignore_all_magic
local ignore_advanced_magic
local spellcaster_options_active
local xl_force_mores_active

---- Initialization ----
function f_dynamic_options.init()
  C = f_dynamic_options.Config

  cur_god = "No God"
  ignore_advanced_magic = false
  ignore_all_magic = false
  spellcaster_options_active = false
  xl_force_mores_active = {}

  -- Class options
  local handler = C.class_options[you.class()]
  if handler then handler() end

  -- Race options
  local race = you.race()
  handler = C.race_options[race]
  if handler then handler() end
  if util.contains(BRC.UNDEAD_RACES, race) then
    BRC.opt.force_more_message("monster_warning:wielding.*of holy wrath", true)
  end
  if not util.contains(BRC.POIS_RES_RACES, race) then
    BRC.opt.force_more_message("monster_warning:curare", true)
  end
end

---- Local functions ----
local function set_god_options()
  if cur_god == you.god() then return end
  local prev_god = cur_god
  cur_god = you.god()

  local abandoned = C.god_options[prev_god]
  if abandoned then abandoned(false) end

  local joined = C.god_options[cur_god]
  if joined then joined(true) end
end

local function set_xl_options()
  for i, v in ipairs(C.xl_force_mores) do
    local should_be_active = you.xl() <= v.xl
    if xl_force_mores_active[i] ~= should_be_active then
      xl_force_mores_active[i] = should_be_active
      BRC.opt.force_more_message(v.pattern, should_be_active)
    end
  end
end

local function set_skill_options()
  local spellcasting_skill = you.skill("Spellcasting")
  -- If zero spellcasting or no spells, don't stop on spellbook pickup, and allow -Cast / antimagic
  local no_spells = spellcasting_skill == 0 or #you.spells() == 0
  if ignore_all_magic ~= no_spells then
    ignore_all_magic = no_spells
    BRC.opt.explore_stop_pickup_ignore(IGNORE_SPELLBOOKS_STRING, no_spells)
    BRC.util.add_or_remove(BRC.ARTPROPS_BAD, "-Cast", not no_spells)
    BRC.util.add_or_remove(BRC.RISKY_EGOS, "antimagic", not no_spells)
  end

  -- If heavy armour and low armour skill, ignore spellcasting items
  if ignore_all_magic and you.race() ~= "Mountain Dwarf" then
    local worn = items.equipped_at("armour")
    local encumbered_magic = worn and worn.encumbrance > (4 + you.skill("Armour") / 2)
    if ignore_advanced_magic ~= encumbered_magic then
      ignore_advanced_magic = encumbered_magic
      BRC.opt.autopickup_exceptions(HIGH_LVL_MAGIC_STRING, encumbered_magic)
    end
  end

  -- If spellcaster, add stop for mana drain
  if spellcasting_skill > C.meaningful_spellcasting_skill and not spellcaster_options_active then
    spellcaster_options_active = true
    BRC.opt.force_more_message("You feel your power leaking away", true)
  end
end

---- Crawl hook functions ----
function f_dynamic_options.ready()
  set_god_options()
  set_xl_options()
  set_skill_options()
end
