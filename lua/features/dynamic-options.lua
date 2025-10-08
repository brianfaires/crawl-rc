--[[
Feature: dynamic-options
Description: Changes options based on game state: xl, class, race, god, skills
Author: buehler
Dependencies: core/constants.lua, core/util.lua
--]]

f_dynamic_options = {}
f_dynamic_options.BRC_FEATURE_NAME = "dynamic-options"

-- Local constants / configuration
local XL_FORCE_MORES = {
  { pattern = "monster_warning:wielding.*of electrocution", xl = 5 },
  { pattern = "You.*re more poisoned", xl = 7 },
  { pattern = "^(?!.*Your?).*speeds? up", xl = 10 },
  { pattern = "danger:goes berserk", xl = 18 },
  { pattern = "monster_warning:carrying a wand of", xl = 15 },
} -- XL_FORCE_MORES (do not remove this comment)

local IGNORE_SPELLBOOKS_STRING = table.concat(BRC.SPELLBOOKS, ", ")
local HIGH_LVL_MAGIC_STRING = "scrolls? of amnesia, potions? of brilliance, ring of wizardry"

-- Local variables
local cur_god = nil
local ignore_all_magic = nil
local ignore_advanced_magic = nil
local xl_force_mores_active = nil

-- Local functions
local function set_class_options()
  if you.class() == "Hunter" then
    crawl.setopt("view_delay = 30")
  elseif you.class() == "Shapeshifter" then
    BRC.set.autopickup_exceptions("<flux bauble", true)
  end
end

local function set_god_options()
  if cur_god == you.god() then return end
  local prev_god = cur_god
  local new_god = you.god()
  cur_god = new_god

  if prev_god == "No God" or new_god == "No God" then
    local abandoned_god = new_god == "No God"
    BRC.set.force_more_message("Found.*the Ecumenical Temple", abandoned_god)
    BRC.set.flash_screen_message("Found.*the Ecumenical Temple", not abandoned_god)
    BRC.set.runrest_stop_message("Found.*the Ecumenical Temple", not abandoned_god)
  end

  if new_god == "Beogh" or prev_god == "Beogh" then
    local joined_beogh = new_god == "Beogh"
    BRC.set.runrest_ignore_message("no longer looks.*", joined_beogh)
    BRC.set.force_more_message("Your orc.*dies", joined_beogh)
  end

  if new_god == "Cheibriados" then
    util.remove(BRC.RISKY_EGOS, "Ponderous")
  elseif prev_god == "Cheibriados" then
    BRC.RISKY_EGOS[#BRC.RISKY_EGOS + 1] = "Ponderous"
  end

  if new_god == "Jiyva" or prev_god == "Jiyva" then
    local joined_jiyva = new_god == "Jiyva"
    BRC.set.flash_screen_message("god:splits in two", joined_jiyva)
    BRC.set.message_mute("You hear a.*(slurping|squelching) noise", joined_jiyva)
  end

  if new_god == "Lugonu" then
    util.remove(BRC.RISKY_EGOS, "distort")
  elseif prev_god == "Lugonu" then
    BRC.RISKY_EGOS[#BRC.RISKY_EGOS + 1] = "distort"
  end

  if new_god == "Trog" then
    util.remove(BRC.BAD_ART_PROPS, "-Cast")
    util.remove(BRC.RISKY_EGOS, "antimagic")
  elseif prev_god == "Trog" then
    BRC.BAD_ART_PROPS[#BRC.BAD_ART_PROPS + 1] = "-Cast"
    BRC.RISKY_EGOS[#BRC.RISKY_EGOS + 1] = "antimagic"
  end

  if new_god == "Xom" or prev_god == "Xom" then
    BRC.set.force_more_message("god:", new_god == "Xom")
  end
end

local function set_race_options()
  if util.contains(BRC.UNDEAD_RACES, you.race()) then
    BRC.set.force_more_message("monster_warning:wielding.*of holy wrath", true)
  end

  if not util.contains(BRC.POIS_RES_RACES, you.race()) then
    BRC.set.force_more_message("monster_warning:curare", true)
  end

  if you.race() == "Gnoll" then BRC.set.message_mute("intrinsic_gain:skill increases to level", true) end
end

local function set_xl_options()
  for i, v in ipairs(XL_FORCE_MORES) do
    local should_be_active = you.xl() <= v.xl
    if xl_force_mores_active[i] ~= should_be_active then
      xl_force_mores_active[i] = should_be_active
      BRC.set.force_more_message(v.pattern, should_be_active)
    end
  end
end

local function set_skill_options()
  -- If zero spellcasting, don't stop on spellbook pickup, and allow -Cast / antimagic
  local no_spells = #you.spells() == 0
  if ignore_all_magic ~= no_spells then
    ignore_all_magic = no_spells
    BRC.set.explore_stop_pickup_ignore(IGNORE_SPELLBOOKS_STRING, no_spells)
    if no_spells then
      util.remove(BRC.BAD_ART_PROPS, "-Cast")
      util.remove(BRC.RISKY_EGOS, "antimagic")
    else
      BRC.BAD_ART_PROPS[#BRC.BAD_ART_PROPS + 1] = "-Cast"
      BRC.RISKY_EGOS[#BRC.RISKY_EGOS + 1] = "antimagic"
    end
  end

  -- If heavy armour and low armour skill, ignore spellcasting items
  if ignore_all_magic and (you.race() ~= "Mountain Dwarf") then
    local worn = items.equipped_at("armour")
    local encumbered_magic = worn and worn.encumbrance > (4 + you.skill("Armour") / 2)
    if ignore_advanced_magic ~= encumbered_magic then
      ignore_advanced_magic = encumbered_magic
      BRC.set.autopickup_exceptions(HIGH_LVL_MAGIC_STRING, encumbered_magic)
    end
  end
end

-- Hook functions
function f_dynamic_options.init()
  cur_god = "No God"
  ignore_advanced_magic = false
  ignore_all_magic = false
  xl_force_mores_active = {}

  set_race_options()
  set_class_options()
  set_god_options()
end

function f_dynamic_options.ready()
  set_god_options()
  set_xl_options()
  set_skill_options()
end
