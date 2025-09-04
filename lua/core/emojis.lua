EMOJI = {}

if BRC.Config.emojis then
  EMOJI.RARE_ITEM = "💎"
  EMOJI.ORB = "🔮"
  EMOJI.TALISMAN = "🧬"

  EMOJI.WEAPON = "⚔️"
  EMOJI.RANGED = "🏹"
  EMOJI.POLEARM = "🔱"
  EMOJI.TWO_HANDED = "✋🤚"
  EMOJI.CAUTION = "⚠️"

  EMOJI.STAFF_RESISTANCE = "🔥"

  EMOJI.ACCURACY = "🎯"
  EMOJI.STRONGER = "💪"
  EMOJI.STRONGEST = "💪💪"
  EMOJI.EGO = "✨"
  EMOJI.LIGHTER = "⏬"
  EMOJI.HEAVIER = "⏫"
  EMOJI.ARTEFACT = "💠"

  EMOJI.REMIND_IDENTIFY = "🎁"
  EMOJI.EXCLAMATION = "❗"
  EMOJI.EXCLAMATION_2 = "‼️"

  EMOJI.HP_FULL_PIP = "❤️"
  EMOJI.HP_PART_PIP = "❤️‍🩹"
  EMOJI.HP_EMPTY_PIP = "🤍"

  EMOJI.MP_FULL_PIP = "🟦"
  EMOJI.MP_PART_PIP = "🔹"
  EMOJI.MP_EMPTY_PIP = "➖"

  EMOJI.SUCCESS = "✅"
else
  EMOJI.REMIND_IDENTIFY = BRC.util.color(COLORS.magenta, "?")
  EMOJI.EXCLAMATION = BRC.util.color(COLORS.magenta, "!")
  EMOJI.EXCLAMATION_2 = BRC.util.color(COLORS.lightmagenta, "!!")

  EMOJI.HP_BORDER = BRC.util.color(COLORS.white, "|")
  EMOJI.HP_FULL_PIP = BRC.util.color(COLORS.green, "+")
  EMOJI.HP_PART_PIP = BRC.util.color(COLORS.lightgrey, "+")
  EMOJI.HP_EMPTY_PIP = BRC.util.color(COLORS.darkgrey, "-")

  EMOJI.MP_BORDER = BRC.util.color(COLORS.white, "|")
  EMOJI.MP_FULL_PIP = BRC.util.color(COLORS.lightblue, "+")
  EMOJI.MP_PART_PIP = BRC.util.color(COLORS.lightgrey, "+")
  EMOJI.MP_EMPTY_PIP = BRC.util.color(COLORS.darkgrey, "-")
end
