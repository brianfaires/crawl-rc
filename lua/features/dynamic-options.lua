----- Set any options based on game state -----
local EARLY_XL = 5
local MID_XL = 10
local LATE_XL = 15

local EARLY_XL_FMs = {
} -- EARLY_XL_FMs (do not remove this comment)

local MID_XL_FMs = {
  "wielding.*of electrocution",
  "You.*re more poisoned"
} -- MID_XL_FMs (do not remove this comment)

local LATE_XL_FMs = {
  "^(?!.*Your?).*speeds? up",
  "danger:goes berserk"
} -- LATE_XL_FMs (do not remove this comment)

local IGNORE_SPELLBOOKS_STRING = table.concat(ALL_SPELLBOOKS, ", ")
local SPELLCASTING_ITEMS_STRING = "scrolls? of amnesia, potions? of brilliance, ring of wizardry"

local dynopt_cur_god
local ignoring_spellcasting
local ignoring_spellbooks
local early_xl_alerts_on
local mid_xl_alerts_on
local late_xl_alerts_on

local function set_dyn_fm(warnings, create)
  for _, v in ipairs(warnings) do
    if create then
      crawl.setopt("force_more_message += " .. v)
    else
      crawl.setopt("force_more_message -= " .. v)
    end
  end
end

local function set_class_options()
  if CACHE.class == "Hunter" then
    crawl.setopt("view_delay = 30")
  end
end

-- Some god-specific force_mores also in fm-message.rc
local function set_god_options()
  local new_god = CACHE.god
  if new_god ~= dynopt_cur_god then
    if dynopt_cur_god == "No God" then
      crawl.setopt("force_more_message -= Found.*the Ecumenical Temple")
      crawl.setopt("flash_screen_message += Found.*the Ecumenical Temple")
      crawl.setopt("runrest_stop_message += Found.*the Ecumenical Temple")
    elseif new_god == "Beogh" then
      crawl.setopt("runrest_ignore_message += no longer looks.*")
      crawl.setopt("force_more_message += Your orc.*dies")
    elseif new_god == "Jiyva" then
      crawl.setopt("force_more_message += god:splits in two")
      crawl.setopt("force_more_message += god:Your prayer is over.")
      crawl.setopt("message_colour ^= mute:You hear a.*(slurping|squelching) noise")
    elseif new_god == "Qazlal" then
      crawl.setopt("force_more_message -= god:You feel.*protected")
    elseif new_god == "Xom" then
      crawl.setopt("force_more_message += god:")
    end

    dynopt_cur_god = new_god
  end
end

local function set_race_options()
  if CACHE.undead then
    crawl.setopt("force_more_message += monster_warning:wielding.*of holy wrath")
  end

  if CACHE.poison_immune then
    crawl.setopt("force_more_message -= monster_warning:curare")
  end

  if CACHE.race == "Gnoll" then
    crawl.setopt("message_colour ^= mute:intrinsic_gain:skill increases to level")
  end
end

local function set_xl_options()
  if not early_xl_alerts_on and CACHE.xl <= EARLY_XL then
    early_xl_alerts_on = true
    set_dyn_fm(EARLY_XL_FMs, true)
  elseif early_xl_alerts_on and CACHE.xl > EARLY_XL then
    early_xl_alerts_on = false
    set_dyn_fm(EARLY_XL_FMs, false)
  end

  if not mid_xl_alerts_on and CACHE.xl <= MID_XL then
    mid_xl_alerts_on = true
    set_dyn_fm(MID_XL_FMs, true)
  elseif mid_xl_alerts_on and CACHE.xl > MID_XL then
    mid_xl_alerts_on = false
    set_dyn_fm(MID_XL_FMs, false)
  end

  if not late_xl_alerts_on and CACHE.xl <= LATE_XL then
    late_xl_alerts_on = true
    set_dyn_fm(LATE_XL_FMs, true)
  elseif not late_xl_alerts_on and CACHE.xl > LATE_XL then
    late_xl_alerts_on = false
    set_dyn_fm(LATE_XL_FMs, false)
  end
end

local function set_skill_options()
  -- If zero spellcasting, don't stop on spellbook pickup
  local zero_spellcasting = CACHE.s_spellcasting == 0
  if not ignoring_spellbooks and zero_spellcasting then
    ignoring_spellbooks = true
    crawl.setopt("explore_stop_pickup_ignore += " .. IGNORE_SPELLBOOKS_STRING)
  elseif ignoring_spellbooks and not zero_spellcasting then
    ignoring_spellbooks = false
    crawl.setopt("explore_stop_pickup_ignore -= " .. IGNORE_SPELLBOOKS_STRING)
  end

  -- If heavy armour and low armour skill, ignore spellcasting items
  if CACHE.race ~= "Mountain Dwarf" then
    local worn = items.equipped_at("armour")
    local heavy_arm = worn ~= nil and worn.encumbrance > 4 + CACHE.s_armour/2
    local skip_items = zero_spellcasting and heavy_arm
    if not ignoring_spellcasting and skip_items then
      ignoring_spellcasting = true
      crawl.setopt("autopickup_exceptions += " .. SPELLCASTING_ITEMS_STRING)
    elseif ignoring_spellcasting and not skip_items then
      ignoring_spellcasting = false
      crawl.setopt("autopickup_exceptions -= " .. SPELLCASTING_ITEMS_STRING)
    end
  end
end


function init_dynamic_options()
  if CONFIG.debug_init then crawl.mpr("Initializing dynamic-options") end

  dynopt_cur_god = CACHE.god
  ignoring_spellcasting = false
  ignoring_spellbooks = false
  early_xl_alerts_on = false
  mid_xl_alerts_on = false
  late_xl_alerts_on = false

  set_race_options()
  set_class_options()
end


------------------ Hooks ------------------
function ready_dynamic_options()
  set_god_options()
  set_xl_options()
  set_skill_options()
end
