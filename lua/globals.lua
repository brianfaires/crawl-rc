if loaded_lua_globals_file then return end
local loaded_lua_globals_file = true
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/util.lua")

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

  GLOBALS.EMOJI.HP_FULL_PIP = "❤️"
  GLOBALS.EMOJI.HP_PART_PIP = "❤️‍🩹"
  GLOBALS.EMOJI.HP_EMPTY_PIP = "🤍"

  GLOBALS.EMOJI.MP_FULL_PIP = "🟦"
  GLOBALS.EMOJI.MP_PART_PIP = "🔹"
  GLOBALS.EMOJI.MP_EMPTY_PIP = "➖"

elseif CONFIG.textmojis then
  GLOBALS.EMOJI.REMIND_IDENTIFY = with_color("cyan", "??")
  GLOBALS.EMOJI.EXCLAMATION = with_color("lightred", "!!")

  GLOBALS.EMOJI.HP_BORDER = with_color(COLORS.white, "|")
  GLOBALS.EMOJI.HP_FULL_PIP = with_color(COLORS.green, "+")
  GLOBALS.EMOJI.HP_PART_PIP = with_color(COLORS.lightgrey, "+")
  GLOBALS.EMOJI.HP_EMPTY_PIP = with_color(COLORS.darkgrey, "-")


  GLOBALS.EMOJI.MP_BORDER = with_color(COLORS.white, "|")
  GLOBALS.EMOJI.MP_FULL_PIP = with_color(COLORS.lightblue, "+")
  GLOBALS.EMOJI.MP_PART_PIP = with_color(COLORS.lightgrey, "+")
  GLOBALS.EMOJI.MP_EMPTY_PIP = with_color(COLORS.darkgrey, "-")
end
