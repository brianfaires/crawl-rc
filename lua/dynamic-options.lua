----- Set any options based on game state -----
loadfile("lua/cache.lua")

local dynopt_cur_god = "No God"
local ignoring_spellcasting = false
local ignoring_spellbooks = false
local warn_early_levels = false
local warn_mid_levels = false
local warn_late_levels = false

local early_warnings = {
} -- early_warnings (do not remove this comment)

local mid_warnings = {
  "wielding.*of electrocution",
  "You.*re more poisoned"
} -- mid_warnings (do not remove this comment)

local late_warnings = {
  "(?<!You)(?<!yourself) speeds? up",
  "danger:goes berserk"
} -- late_warnings (do not remove this comment)


local function set_dyn_fm(warnings, create)
  for _, v in ipairs(warnings) do
    if create then
      crawl.setopt("force_more_message += "..v)
    else
      crawl.setopt("force_more_message -= "..v)
    end
  end
end


---- race-specific ---
local function set_race_options()
  if l_cache.undead then
    crawl.setopt("force_more_message += monster_warning:wielding.*of holy wrath")
  end

  if l_cache.poison_immune then
    crawl.setopt("force_more_message -= monster_warning:curare")
  end

  if l_cache.race == "Gnoll" then
    crawl.setopt("message_colour ^= mute:intrinsic_gain:skill increases to level")
  end
end

---- class-specific ---
local function set_class_options()
  if l_cache.class == "Hunter" then
    crawl.setopt("view_delay = 30")
  end
end

---- god-specific ----
-- force_mores that you don't mind on everyone are in fm-message.rc
local function set_god_options()
  local new_god = l_cache.god
  if new_god then
    crawl.setopt("force_more_message -= Found.*the Ecumenical Temple")
    crawl.setopt("flash_screen_message += Found.*the Ecumenical Temple")
    crawl.setopt("runrest_stop_message += Found.*the Ecumenical Temple")
  end
  if new_god ~= dynopt_cur_god then
    if new_god == "Beogh" then
      crawl.setopt("runrest_ignore_message += no longer looks.*")
      crawl.setopt("force_more_message += Your orc.*dies")
    elseif new_god == "Jiyva" then
      crawl.setopt("force_more_message += god:splits in two")
      crawl.setopt("force_more_message += god:Your prayer is over.")
      crawl.setopt("message_colour ^= mute:You hear a.*(slurping|squelching) noise")
      crawl.setopt("message_colour ^= mute:You feel a little less hungry")
    elseif new_god == "Qazlal" then
      crawl.setopt("force_more_message -= god:You feel.*protected")
    elseif new_god == "Xom" then
      crawl.setopt("force_more_message += god:")
    end

    dynopt_cur_god = new_god
  end
end

---- xl-specific ----
local function set_xl_options()
  if not warn_early_levels and l_cache.xl <= 5 then
    warn_early_levels = true
    set_dyn_fm(early_warnings, true)
  elseif warn_early_levels and l_cache.xl > 5 then
    warn_early_levels = false
    set_dyn_fm(early_warnings, false)
  end

  if not warn_mid_levels and l_cache.xl <= 10 then
    warn_mid_levels = true
    set_dyn_fm(mid_warnings, true)
  elseif warn_mid_levels and l_cache.xl > 10 then
    warn_mid_levels = false
    set_dyn_fm(mid_warnings, false)
  end

  if not warn_late_levels and l_cache.xl <= 15 then
    warn_late_levels = true
    set_dyn_fm(late_warnings, true)
  elseif not warn_late_levels and l_cache.xl > 15 then
    warn_late_levels = false
    set_dyn_fm(late_warnings, false)
  end
end


---- skill-specific ----
local function set_skill_options()
  -- Ignore spellbook reading if you have no spellcasting skill
  -- Ignore all spellcaster items if wearing heavy armour or not much armour skill
  local zero_spellcasting = l_cache.s_spellcasting == 0
  if not ignoring_spellbooks and zero_spellcasting then
    ignoring_spellbooks = true
    crawl.setopt("explore_stop_pickup_ignore += ^book of")
  elseif ignoring_spellbooks and not zero_spellcasting then
    ignoring_spellbooks = false
    crawl.setopt("explore_stop_pickup_ignore -= ^book of")
  end

  local arm = items.equipped_at("armour")
  local heavy_arm = zero_spellcasting and arm ~= nil and arm.encumbrance > 4 + l_cache.s_armour/2
  if not ignoring_spellcasting and heavy_arm then
    ignoring_spellcasting = true
    crawl.setopt("autopickup_exceptions ^= >scrolls? of amnesia, >potions? of brilliance, >ring of wizardry")
    crawl.setopt("runrest_ignore_message += You add the spell")
  elseif ignoring_spellcasting and not heavy_arm then
    ignoring_spellcasting = false
    crawl.setopt("autopickup_exceptions -= >scrolls? of amnesia, >potions? of brilliance, >ring of wizardry")
    crawl.setopt("runrest_ignore_message -= You add the spell")
  end
end


------------------ Hook ------------------
function ready_dynamic_options()
  if l_cache.turn == 0 then
    set_race_options()
    set_class_options()
  end

  set_god_options()
  set_xl_options()
  set_skill_options()
end
