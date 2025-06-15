if loaded_lua_globals_file then return end
local loaded_lua_globals_file = true
loadfile("crawl-rc/lua/config.lua")

GLOBALS = {}
GLOBALS.EMOJI = {}

if CONFIG.emojis then
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

  GLOBALS.EMOJI.HP_100 = "❤️❤️❤️❤️❤️"
  GLOBALS.EMOJI.HP_90  = "❤️❤️❤️❤️❤️‍🩹"
  GLOBALS.EMOJI.HP_80  = "❤️❤️❤️❤️🤍"
  GLOBALS.EMOJI.HP_70  = "❤️❤️❤️❤️‍🩹🤍"
  GLOBALS.EMOJI.HP_60  = "❤️❤️❤️🤍🤍"
  GLOBALS.EMOJI.HP_50  = "❤️❤️❤️‍🩹🤍🤍"
  GLOBALS.EMOJI.HP_40  = "❤️❤️🤍🤍🤍"
  GLOBALS.EMOJI.HP_30  = "❤️❤️‍🩹🤍🤍🤍"
  GLOBALS.EMOJI.HP_20  = "❤️🤍🤍🤍🤍"
  GLOBALS.EMOJI.HP_10  = "❤️‍🩹🤍🤍🤍🤍"
  GLOBALS.EMOJI.HP_0   = "🤍🤍🤍🤍🤍"

else
  -- Define non-emoji fallbacks
  GLOBALS.EMOJI.HP_100 = "<w>|</w><lightred>-----</lightred><lightgrey></lightgrey><darkgrey></darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_90  = "<w>|</w><lightred>----</lightred><lightgrey>-</lightgrey><darkgrey></darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_80  = "<w>|</w><lightred>----</lightred><lightgrey></lightgrey><darkgrey>-</darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_70  = "<w>|</w><lightred>---</lightred><lightgrey>-</lightgrey><darkgrey>-</darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_60  = "<w>|</w><lightred>---</lightred><lightgrey></lightgrey><darkgrey>--</darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_50  = "<w>|</w><lightred>--</lightred><lightgrey>-</lightgrey><darkgrey>--</darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_40  = "<w>|</w><lightred>--</lightred><lightgrey></lightgrey><darkgrey>---</darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_30  = "<w>|</w><lightred>-</lightred><lightgrey>-</lightgrey><darkgrey>---</darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_20  = "<w>|</w><lightred>-</lightred><lightgrey></lightgrey><darkgrey>----</darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_10  = "<w>|</w><lightred></lightred><lightgrey>-</lightgrey><darkgrey>----</darkgrey><w>|</w>"
  GLOBALS.EMOJI.HP_0   = "<w>|</w><lightred></lightred><lightgrey></lightgrey><darkgrey>-----</darkgrey><w>|</w>"

  GLOBALS.EMOJI.REMIND_IDENTIFY = "<cyan>??</cyan>"
  GLOBALS.EMOJI.EXCLAMATION = "<lightred>!!</lightred>"
end
