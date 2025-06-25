EMOJI = {}

function init_emojis()
  if CONFIG.debug_init then crawl.mpr("Initializing emojis") end

  if CONFIG.emojis then
    EMOJI.RARE_ITEM = "💎"
    EMOJI.ORB = "🔮"
    EMOJI.TALISMAN = "🧬"

    EMOJI.WEAPON = "⚔️"
    EMOJI.RANGED = "🏹"
    EMOJI.POLEARM = "🔱"
    EMOJI.TWO_HANDED = "✋🤚"

    --EMOJI.ARMOUR = "🛡️"
    EMOJI.HAT = "🧢"
    EMOJI.GLOVES = "🧤"
    EMOJI.BOOTS = "🥾"
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
    EMOJI.REMIND_IDENTIFY = with_color(COLORS.cyan, "??")
    EMOJI.EXCLAMATION_2 = with_color(COLORS.lightred, "!!")

    EMOJI.HP_BORDER = with_color(COLORS.white, "|")
    EMOJI.HP_FULL_PIP = with_color(COLORS.green, "+")
    EMOJI.HP_PART_PIP = with_color(COLORS.lightgrey, "+")
    EMOJI.HP_EMPTY_PIP = with_color(COLORS.darkgrey, "-")

    EMOJI.MP_BORDER = with_color(COLORS.white, "|")
    EMOJI.MP_FULL_PIP = with_color(COLORS.lightblue, "+")
    EMOJI.MP_PART_PIP = with_color(COLORS.lightgrey, "+")
    EMOJI.MP_EMPTY_PIP = with_color(COLORS.darkgrey, "-")
  end
end
