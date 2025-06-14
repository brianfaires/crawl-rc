if loaded_lua_globals_file then return end
local loaded_lua_globals_file = true
loadfile("crawl-rc/lua/config.lua")

GLOBALS = {}
GLOBALS.EMOJI = {}

if CONFIG.emojis then
  GLOBALS.EMOJI.HP_MAX = "❤️"
  GLOBALS.EMOJI.HP_HIGH = "💔"
  GLOBALS.EMOJI.HP_MID = "🧡"
  GLOBALS.EMOJI.HP_LOW = "💛"
  GLOBALS.EMOJI.HP_CRIT = "🤍"

  GLOBALS.EMOJI.RARE_ITEM = "💎"
  GLOBALS.EMOJI.ORB = "🔮"
  GLOBALS.EMOJI.TALISMAN = "🧬"
  GLOBALS.EMOJI.BODY_ARMOUR = "🛡️"
  GLOBALS.EMOJI.ARMOUR = "🛡️"

  GLOBALS.EMOJI.WEAPON = "⚔️"
  GLOBALS.EMOJI.RANGED = "🏹"
  GLOBALS.EMOJI.POLEARM = "🔱"
  GLOBALS.EMOJI.TWO_HANDED = "✋🤚"
  GLOBALS.EMOJI.HAT = "🧢"
  GLOBALS.EMOJI.GLOVES = "🧤"
  GLOBALS.EMOJI.BOOTS = "🥾"
  GLOBALS.EMOJI.STAFF_RESISTANCE = "🏳️‍🌈"

  GLOBALS.EMOJI.ACCURACY = "🎯"
  GLOBALS.EMOJI.STRONGER = "💪"
  GLOBALS.EMOJI.STRONGEST = "💪💪"
  GLOBALS.EMOJI.EGO = "🧪"
  GLOBALS.EMOJI.LIGHTER = "⏬"
  GLOBALS.EMOJI.HEAVIER = "⏫"
  GLOBALS.EMOJI.ARTEFACT = "💠"

  GLOBALS.EMOJI.REMIND_IDENTIFY = "🎁"
  GLOBALS.EMOJI.EXCLAMATION = "‼️"

else
  -- Define non-emoji fallbacks
  GLOBALS.EMOJI.HP_MAX = ":D"
  GLOBALS.EMOJI.HP_HIGH = ":)"
  GLOBALS.EMOJI.HP_MID = ":|"
  GLOBALS.EMOJI.HP_LOW = ":("
  GLOBALS.EMOJI.HP_CRIT = ":O"

  GLOBALS.EMOJI.HP_MAX =  "<red><white>|</white>-----<white>|</white></red>"
  GLOBALS.EMOJI.HP_HIGH = "<red><white>|</white>----<darkgrey>-</darkgrey><white>|</white></red>"
  GLOBALS.EMOJI.HP_MID =  "<red><white>|</white>---<darkgrey>--</darkgrey><white>|</white></red>"
  GLOBALS.EMOJI.HP_LOW =  "<red><white>|</white>--<darkgrey>---</darkgrey><white>|</white></red>"
  GLOBALS.EMOJI.HP_CRIT = "<red><white>|</white>-<darkgrey>----</darkgrey><white>|</white></red>"

  GLOBALS.EMOJI.REMIND_IDENTIFY = "<cyan>??</cyan>"
  GLOBALS.EMOJI.EXCLAMATION = "<lightred>!!</lightred>"
end
