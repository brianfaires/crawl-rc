----- Initially from https://github.com/magus/dcss -----
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/constants.lua")
loadfile("crawl-rc/lua/globals.lua")
loadfile("crawl-rc/lua/util.lua")

function delta_color(delta)
  local color = delta < 0 and COLORS.red or COLORS.green
  local signDelta = delta < 0 and delta or "+" .. delta
  return string.format("<%s>%s</%s>", color, signDelta, color)
end

function colorize_text(color, text)
  return string.format("<%s>%s</%s>", color, text, color)
end

local AD_Messages = {
  ["HPSimple"] = function(delta)
    return colorize_text(COLORS.white,
      string.format("HP[%s]", delta_color(0 - delta))
    )
  end,
  ["HPMax"] = function (_, _, hpm, delta)
    crawl.mpr(
      colorize_text(COLORS.lightgreen,
        string.format("Max HP: %s (%s).", hpm, delta_color(delta))
      )
    )
  end,
  ["HPLoss"] = function (color, hp, hpm, loss)
    crawl.mpr(
      colorize_text(COLORS.red, string.format("Took %s damage ", loss)) ..
      colorize_text(color, string.format("-> %s/%s HP", hp, hpm))
    )
  end,
  ["HPGain"] = function (color, hp, hpm, gain)
    crawl.mpr(
      colorize_text(COLORS.lightgreen, string.format("Gained %s HP ", gain)) ..
      colorize_text(color, string.format("-> %s/%s HP", hp, hpm))
    )
  end,
  ["HPFull"] = function (_, hp)
    crawl.mpr(
      colorize_text(COLORS.lightgreen,
        string.format("Full HP (%s).", hp)
      )
    )
  end,
  ["HPMassive"] = function ()
    crawl.mpr(
      colorize_text(COLORS.lightred, "MASSIVE DAMAGE!!")
    )
  end,
  ["MPSimple"] = function(delta)
    return colorize_text(COLORS.white,
      string.format("MP[%s]", delta_color(0 - delta))
    )
  end,
  ["MPLoss"] = function (color, mp, mpm, loss)
    crawl.mpr(
      colorize_text(COLORS.cyan, string.format("Lost %s MP ", loss)) ..
      colorize_text(color, string.format("-> %s/%s MP", mp, mpm))
    )
  end,
  ["MPGain"] = function (color, mp, mpm, gain)
    crawl.mpr(
      colorize_text(COLORS.cyan, string.format("Gained %s MP ", gain)) ..
      colorize_text(color, string.format("-> %s/%s MP", mp, mpm))
    )
  end,
  ["MPFull"] = function (_, mp)
    crawl.mpr(
      colorize_text(COLORS.cyan, string.format("Full MP (%s).", mp))
    )
  end,
  [""]="",
} --AD_Messages (do not remove this comment)

local prev_hp = 0
local prev_hp_max = 0
local prev_mp = 0
local prev_mp_max = 0

-- Simplified condensed HP and MP output
-- Print a single condensed line showing HP & MP change
-- e.g.😨 HP[-2] MP[-1]
local function simple_announce_damage(hp_lost, mp_lost)
  local emoji
  local message
  
  if hp_lost > CONFIG.ANNOUNCE_HP_THRESHOLD then
    if mp_lost > CONFIG.ANNOUNCE_MP_THRESHOLD then
      -- HP[-2] MP[-1]
      message = string.format("%s %s", AD_Messages.HPSimple(hp_lost), AD_Messages.MPSimple(mp_lost))
    else
      -- HP[-2]
      message = AD_Messages.HPSimple(hp_lost)
    end
  elseif mp_lost > CONFIG.ANNOUNCE_MP_THRESHOLD then
    -- MP[-1]
    message = AD_Messages.MPSimple(mp_lost)
  end

  if message ~= nil then
    if CACHE.hp <= (CACHE.mhp * 0.25) then
      emoji = GLOBALS.EMOJI.HP_CRIT
    elseif CACHE.hp <= (CACHE.mhp * 0.50) then
      emoji = GLOBALS.EMOJI.HP_LOW
    elseif CACHE.hp <= (CACHE.mhp *  0.75) then
      emoji = GLOBALS.EMOJI.HP_MID
    elseif CACHE.hp < CACHE.mhp then
      emoji = GLOBALS.EMOJI.HP_HIGH
    else
      emoji = GLOBALS.EMOJI.HP_MAX
    end
    crawl.mpr(string.format("\n%s %s %s", emoji, message, emoji))
  end
end

-- Try to sync with colors defined in Interface.rc
local function color_by_max(message_func, cur, max, diff)
  if cur <= (max * 0.25) then
    message_func(COLORS.red, cur, max, diff)
  elseif cur <= (max * 0.50) then
    message_func(COLORS.lightred, cur, max, diff)
  elseif cur <= (max *  0.75) then
    message_func(COLORS.yellow, cur, max, diff)
  else
    message_func(COLORS.lightgrey, cur, max, diff)
  end
end

function ready_announce_damage()
  --Skips message on initializing game
  if prev_hp > 0 then
    local hp_lost = prev_hp - CACHE.hp
    local mhp_lost = CACHE.mhp - prev_hp_max
    local hp_lost_relative = hp_lost - mhp_lost
    local mp_lost = prev_mp - CACHE.mp
    local mmp_lost = CACHE.mmp - prev_mp_max
    local mp_lost_relative = mp_lost - mmp_lost

    -- Simplified condensed HP and MP output
    simple_announce_damage(hp_lost, mp_lost)

    -- HP Max
    if mhp_lost > 0 then
      AD_Messages.HPMax(COLORS.green, CACHE.hp, CACHE.mhp, mhp_lost)
    elseif mhp_lost < 0 then
      AD_Messages.HPMax(COLORS.yellow, CACHE.hp, CACHE.mhp, mhp_lost)
    end

    -- HP Loss/Gain
    if (hp_lost_relative > CONFIG.ANNOUNCE_HP_THRESHOLD) then
      color_by_max(AD_Messages.HPLoss, CACHE.hp, CACHE.mhp, hp_lost)
      if hp_lost > (CACHE.mhp * CONFIG.ANNOUNCE_HP_MASSIVE_THRESHOLD) then
        AD_Messages.HPMassive()
      end
    elseif (hp_lost_relative < -CONFIG.ANNOUNCE_HP_THRESHOLD) then
      if (CACHE.hp == CACHE.mhp) then
        AD_Messages.HPFull(nil, CACHE.hp)
      elseif (hp_lost < 0) then
        color_by_max(AD_Messages.HPGain, CACHE.hp, CACHE.mhp, -hp_lost)
      end
    end

    -- MP Loss/Gain
    if (mp_lost_relative > CONFIG.ANNOUNCE_MP_THRESHOLD) then
      color_by_max(AD_Messages.MPLoss, CACHE.mp, CACHE.mmp, mp_lost)
    elseif (mp_lost_relative < -CONFIG.ANNOUNCE_MP_THRESHOLD) then
      if (CACHE.mp == CACHE.mmp) then
        AD_Messages.MPFull(nil, CACHE.mp)
      elseif (mp_lost < 0) then
        color_by_max(AD_Messages.MPGain, CACHE.mp, CACHE.mmp, -mp_lost)
      end
    end
  end

  --Set previous hp/mp and form at end of turn
  prev_hp = CACHE.hp
  prev_hp_max = CACHE.mhp
  prev_mp = CACHE.mp
  prev_mp_max = CACHE.mmp
end
