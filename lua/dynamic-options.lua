----------------------
---- race-specific ----
----------------------
if you.race() == "Demonspawn" then
  crawl.setopt("force_more_message += monster_warning:wielding.*of holy wrath")
elseif you.race() == "Formicid" then
  crawl.setopt("force_more_message -= monster_warning:curare")
elseif you.race() == "Gargoyle" then
  crawl.setopt("force_more_message -= monster_warning:curare")
elseif you.race() == "Ghoul" then
  crawl.setopt("force_more_message -= monster_warning:curare")
  crawl.setopt("force_more_message += monster_warning:wielding.*of holy wrath")
elseif you.race() == "Gnoll" then
  crawl.setopt("message_colour ^= mute:intrinsic_gain:skill increases to level")
elseif you.race() == "Mummy" then
  crawl.setopt("force_more_message -= monster_warning:curare")
  crawl.setopt("force_more_message += monster_warning:wielding.*of holy wrath")
end


-----------------------
---- class-specific ----
-----------------------
if you.class() == "Hunter" then
  crawl.setopt("view_delay = 20")
end


----------------------
---- god-specific ----
----------------------
local cur_god = "No God"
local function set_god_options()
  if you.god() ~= cur_god then
    cur_god = you.god()

    if cur_god == "Ashenzari" then
      crawl.setopt("runrest_stop_message += god:Ashenzari invites you to partake")
    elseif cur_god == "Beogh" then
      crawl.setopt("autopickup_exceptions ^= >scrolls? of immolation")
      crawl.setopt("runrest_ignore_message += no longer looks unusually strong")
      crawl.setopt("force_more_message += Your orc.*dies")
    elseif cur_god == "Dithmenos" then
      crawl.setopt("force_more_message += god:You are shrouded in an aura of darkness")
      crawl.setopt("force_more_message += god:You now sometimes bleed smoke")
      crawl.setopt("force_more_message += god:You.*no longer.*bleed smoke")
      crawl.setopt("force_more_message += god:Your shadow no longer tangibly mimics your actions")
      crawl.setopt("force_more_message += god:Your shadow now sometimes tangibly mimics your actions")
    elseif cur_god == "Fedhas" then
      crawl.setopt("force_more_message += god:Fedhas invokes the elements against you")
    elseif cur_god == "Hepliaklqana" then
      crawl.setopt("runrest_ignore_message ^= emerges from the mists of memory")
    elseif cur_god == "Jiyva" then
      crawl.setopt("force_more_message += god:will now unseal the treasures of the Slime Pits")
      crawl.setopt("force_more_message += god:Jiyva alters your body")
      crawl.setopt("force_more_message += god:splits in two")
      crawl.setopt("force_more_message += god:Your prayer is over.")
    elseif cur_god == "Kikubaaqudgha" then
      crawl.setopt("force_more_message += god:Kikubaaqudgha will grant you")
    elseif cur_god == "Lugonu" then
      crawl.setopt("force_more_message += god:Lugonu will now corrupt your weapon")
      crawl.setopt("force_more_message += god:Lugonu sends minions to punish you")
    elseif cur_god == "Okawaru" then
      crawl.setopt("force_more_message += god:Okawaru sends forces against you")
    elseif cur_god == "Ru" then
      crawl.setopt("runrest_stop_message += god:Ru believes you are ready to make a new sacrifice")
    elseif cur_god == "Qazlal" then
      crawl.setopt("force_more_message += god:resistances upon receiving elemental damage")
      crawl.setopt("force_more_message += god:You are surrounded by a storm which can block enemy attacks")
      crawl.setopt("force_more_message -= god:You feel.*protected")
    elseif cur_god == "The Shining One" then
      crawl.setopt("force_more_message += god:Your divine shield starts to fade.")
      crawl.setopt("force_more_message += god:Your divine shield fades away.")
    elseif cur_god == "Trog" then
      crawl.setopt("force_more_message += god:You feel the effects of Trog's Hand fading")
      crawl.setopt("force_more_message += god:You feel less resistant to hostile enchantments")
    elseif cur_god == "Wu Jian Council" then
      crawl.setopt("runrest_ignore_message += heavenly storm settles")
    elseif cur_god == "Xom" then
      crawl.setopt("force_more_message += god:")
      crawl.setopt("force_more_message += staircase.*moves")
      crawl.setopt("force_more_message += Some monsters swap places")
    elseif cur_god == "Yredelemnul" then
      crawl.setopt("force_more_message += god:soul is now ripe for the taking")
      crawl.setopt("force_more_message += god:soul is no longer ripe for the taking")
      crawl.setopt("force_more_message += god:dark mirror aura disappears")
    elseif cur_god == "Zin" then
      crawl.setopt("force_more_message += god:will now cure all your mutations")
    end
  end
end



---------------------
---- xl-specific ----
---------------------
local early_warnings = {

}
local mid_warnings = {
  "wielding.*of electrocution",
  "You.*re more poisoned"
}
local late_warnings = {
  "(?<!You)(?<!yourself) speeds? up",
  "danger:goes berserk"
}

local function set_warnings(warnings, create)
  for _, v in ipairs(warnings) do
    if create then
      crawl.setopt("force_more_message += "..v)
    else
      crawl.setopt("force_more_message -= "..v)
    end
  end
end

local warn_early_levels = false
local warn_mid_levels = false
local warn_late_levels = false

local function set_xl_options()
  if not warn_early_levels and you.xl() <= 5 then
    warn_early_levels = true
    set_warnings(early_warnings, true)
  elseif warn_early_levels and you.xl() > 5 then
    warn_early_levels = false
    set_warnings(early_warnings, false)
  end

  if not warn_mid_levels and you.xl() <= 10 then
    warn_mid_levels = true
    set_warnings(mid_warnings, true)
  elseif warn_mid_levels and you.xl() > 10 then
    warn_mid_levels = false
    set_warnings(mid_warnings, false)
  end

  if not warn_late_levels and you.xl() <= 15 then
    warn_late_levels = true
    set_warnings(late_warnings, true)
  elseif not warn_late_levels and you.xl() > 15 then
    warn_late_levels = false
    set_warnings(late_warnings, false)
  end
end


------------------------
---- skill-specific ----
------------------------
local ignoring_spellcasting = false
local ignoring_spellbooks = false
local function set_skill_options()
  -- Ignore spellbook reading if you have no spellcasting skill
  -- Ignore all spellcaster items if wearing heavy armour or not much armour skill
  local zero_spellcasting = you.skill("Spellcasting") == 0
  if not ignoring_spellbooks and zero_spellcasting then
    ignoring_spellbooks = true
    crawl.setopt("explore_stop_pickup_ignore += ^book of")
  elseif ignoring_spellbooks and not zero_spellcasting then
    ignoring_spellbooks = false
    crawl.setopt("explore_stop_pickup_ignore -= ^book of")
  end

  local arm = items.equipped_at("armour")
  local heavy_arm = zero_spellcasting and arm ~= nil and arm.encumbrance > 4 + you.skill("Armour")/2
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



------------------------------------------
------------------ Hook ------------------
------------------------------------------
function ready_dynamic_options()
  set_god_options()
  set_xl_options()
  set_skill_options()
end
