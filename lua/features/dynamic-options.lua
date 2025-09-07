--[[
Feature: dynamic-options
Description: Changes options based on game state: xl, class, race, god, skills
Author: buehler
Dependencies: core/config.lua, core/constants.lua
--]]

f_dynamic_options = {}
f_dynamic_options.BRC_FEATURE_NAME = "dynamic-options"

-- Local constants / configuration
local EARLY_XL = 5
local MID_XL = 10
local LATE_XL = 15

local EARLY_XL_FMs = {} -- EARLY_XL_FMs (do not remove this comment)

local MID_XL_FMs = {
  "monster_warning:wielding.*of electrocution",
  "You.*re more poisoned",
} -- MID_XL_FMs (do not remove this comment)

local LATE_XL_FMs = {
  "^(?!.*Your?).*speeds? up",
  "danger:goes berserk",
  "monster_warning:carrying a wand of",
} -- LATE_XL_FMs (do not remove this comment)

local IGNORE_SPELLBOOKS_STRING = table.concat(BRC.ALL_SPELLBOOKS, ", ")
local SPELLCASTING_ITEMS_STRING = "scrolls? of amnesia, potions? of brilliance, ring of wizardry"

-- Local state
local cur_god
local ignoring_spellcasting
local ignoring_spellbooks
local early_xl_alerts_on
local mid_xl_alerts_on
local late_xl_alerts_on

-- Local functions
local function set_dyn_fm(warnings, create)
  for _, v in ipairs(warnings) do
    BRC.set.force_more(v, create)
  end
end

local function set_class_options()
  if you.class() == "Hunter" then
    crawl.setopt("view_delay = 30")
  elseif you.class() == "Shapeshifter" then
    BRC.set.autopickup_exception("<flux bauble", true)
  end
end

local function set_god_options()
  local new_god = you.god()
  if new_god ~= cur_god then
    if cur_god == "No God" then
      BRC.set.force_more("Found.*the Ecumenical Temple", false)
      BRC.set.flash_screen_message("Found.*the Ecumenical Temple", true)
      BRC.set.runrest_stop_message("Found.*the Ecumenical Temple", true)
    elseif new_god == "Beogh" then
      BRC.set.runrest_ignore_message("no longer looks.*", true)
      BRC.set.force_more("Your orc.*dies", true)
    elseif new_god == "Jiyva" then
      BRC.set.force_more("god:splits in two", true)
      BRC.set.force_more("god:Your prayer is over.", true)
      BRC.set.message_mute("You hear a.*(slurping|squelching) noise", true)
    elseif new_god == "Qazlal" then
      BRC.set.force_more("god:You feel.*protected", false)
    elseif new_god == "Xom" then
      BRC.set.force_more("god:", true)
    end

    cur_god = new_god
  end
end

local function set_race_options()
  if util.contains(BRC.ALL_UNDEAD_RACES, you.race()) then
    BRC.set.force_more("monster_warning:wielding.*of holy wrath", true)
  end

  if not util.contains(BRC.ALL_POIS_RES_RACES, you.race()) then
    BRC.set.force_more("monster_warning:curare", true)
  end

  if you.race() == "Gnoll" then BRC.set.message_mute("intrinsic_gain:skill increases to level", true) end
end

local function set_xl_options()
  if not early_xl_alerts_on and you.xl() <= EARLY_XL then
    early_xl_alerts_on = true
    set_dyn_fm(EARLY_XL_FMs, true)
  elseif early_xl_alerts_on and you.xl() > EARLY_XL then
    early_xl_alerts_on = false
    set_dyn_fm(EARLY_XL_FMs, false)
  end

  if not mid_xl_alerts_on and you.xl() <= MID_XL then
    mid_xl_alerts_on = true
    set_dyn_fm(MID_XL_FMs, true)
  elseif mid_xl_alerts_on and you.xl() > MID_XL then
    mid_xl_alerts_on = false
    set_dyn_fm(MID_XL_FMs, false)
  end

  if not late_xl_alerts_on and you.xl() <= LATE_XL then
    late_xl_alerts_on = true
    set_dyn_fm(LATE_XL_FMs, true)
  elseif not late_xl_alerts_on and you.xl() > LATE_XL then
    late_xl_alerts_on = false
    set_dyn_fm(LATE_XL_FMs, false)
  end
end

local function set_skill_options()
  -- If zero spellcasting, don't stop on spellbook pickup
  local zero_spellcasting = you.skill("Spellcasting") == 0
  -- If current ignore behavior doesn't match desired behavior, update it
  if ignoring_spellbooks ~= zero_spellcasting then
    ignoring_spellbooks = zero_spellcasting
    BRC.set.explore_stop_pickup_ignore(IGNORE_SPELLBOOKS_STRING, zero_spellcasting)
  end

  -- If heavy armour and low armour skill, ignore spellcasting items
  if you.race() ~= "Mountain Dwarf" then
    local worn = items.equipped_at("armour")
    local heavy_arm = worn ~= nil and worn.encumbrance > 4 + you.skill("Armour") / 2
    local skip_items = zero_spellcasting and heavy_arm
    -- If current ignore behavior doesn't match desired behavior, update it
    if ignoring_spellcasting ~= skip_items then
      ignoring_spellcasting = skip_items
      BRC.set.autopickup_exception(SPELLCASTING_ITEMS_STRING, skip_items)
    end
  end
end

-- Hook functions
function f_dynamic_options.init()
  cur_god = "No God"
  ignoring_spellcasting = false
  ignoring_spellbooks = false
  early_xl_alerts_on = false
  mid_xl_alerts_on = false
  late_xl_alerts_on = false

  set_race_options()
  set_class_options()
  set_god_options()
end

function f_dynamic_options.ready()
  set_god_options()
  set_xl_options()
  set_skill_options()
end
