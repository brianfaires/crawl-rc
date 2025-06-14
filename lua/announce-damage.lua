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
      string.format("%s%s",
        colorize_text(COLORS.red, string.format("You take %s damage,", loss)),
        colorize_text(color, string.format(" to %s/%s hp.", hp, hpm))
      )
    )
  end,
  ["HPGain"] = function (color, hp, hpm, gain)
    crawl.mpr(
      string.format("%s%s",
        colorize_text(COLORS.lightgreen, string.format("Gained %s HP,", gain)),
        colorize_text(color, string.format(" to %s/%s hp.", hp, hpm))
      )
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
      string.format("%s%s",
        colorize_text(COLORS.cyan, string.format("Lost %s mp,", loss)),
        colorize_text(color, string.format(" to %s/%s mp.", mp, mpm))
      )
    )
  end,
  ["MPGain"] = function (color, mp, mpm, gain)
    crawl.mpr(
      string.format("%s%s",
        colorize_text(COLORS.cyan, string.format("Gained %s mp,", gain)),
        colorize_text(color, string.format(" to %s/%s mp.", mp, mpm))
      )
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
local function simple_announce_damage(hp_diff, mp_diff)
  local emoji
  local message
  
  if hp_diff > CONFIG.ANNOUNCE_HP_THRESHOLD then
    if mp_diff > CONFIG.ANNOUNCE_MP_THRESHOLD then
      -- HP[-2] MP[-1]
      message = string.format("%s %s", AD_Messages.HPSimple(hp_diff), AD_Messages.MPSimple(mp_diff))
    else
      -- HP[-2]
      message = AD_Messages.HPSimple(hp_diff)
    end
  elseif mp_diff > CONFIG.ANNOUNCE_MP_THRESHOLD then
    -- MP[-1]
    message = AD_Messages.MPSimple(mp_diff)
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
    local hp_diff = prev_hp - CACHE.hp
    local mhp_diff = CACHE.mhp - prev_hp_max
    local mp_diff = prev_mp - CACHE.mp
    local mmp_diff = CACHE.mmp - prev_mp_max

    -- Simplified condensed HP and MP output
    simple_announce_damage(hp_diff, mp_diff)

    -- HP Max
    if mhp_diff > 0 then
      AD_Messages.HPMax(COLORS.green, CACHE.hp, CACHE.mhp, mhp_diff)
    elseif mhp_diff < 0 then
      AD_Messages.HPMax(COLORS.yellow, CACHE.hp, CACHE.mhp, mhp_diff)
    end

    -- HP Loss relative to max HP change
    if (hp_diff - mhp_diff > CONFIG.ANNOUNCE_HP_THRESHOLD) then
      color_by_max(AD_Messages.HPLoss, CACHE.hp, CACHE.mhp, hp_diff)

      if hp_diff > (CACHE.mhp * CONFIG.ANNOUNCE_HP_MASSIVE_THRESHOLD) then
        AD_Messages.HPMassive()
      end
    end

    -- HP Gain
    if (hp_diff - mhp_diff < -CONFIG.ANNOUNCE_HP_THRESHOLD) then
      -- Remove the negative sign by taking absolute value
      local hp_gain = math.abs(hp_diff)

      if (hp_gain > 1) and (CACHE.hp ~= CACHE.mhp) then
        color_by_max(AD_Messages.HPGain, CACHE.hp, CACHE.mhp, hp_gain)
      end

      if (CACHE.hp == CACHE.mhp) then
        AD_Messages.HPFull(nil, CACHE.hp)
      end
    end

    -- MP Gain
    -- More than 1 MP gained
    if (mp_diff - mmp_diff < -CONFIG.ANNOUNCE_MP_THRESHOLD) then
      -- Remove the negative sign by taking absolute value
      local mp_gain = math.abs(mp_diff)

      if (mp_gain > 1) and (CACHE.mp ~= CACHE.mmp) then
        color_by_max(AD_Messages.MPGain, CACHE.mp, CACHE.mmp, mp_gain)
      end

      if (CACHE.mp == CACHE.mmp) then
        AD_Messages.MPFull(nil, CACHE.mp)
      end
    end

    -- MP Loss
    -- Ensure we lost MORE than the change in max mp
    -- i.e. a change in max mp should not be considered loss
    if (mp_diff - mmp_diff > CONFIG.ANNOUNCE_MP_THRESHOLD) then
      color_by_max(AD_Messages.MPLoss, CACHE.mp, CACHE.mmp, mp_diff)
    end

  end

  --Set previous hp/mp and form at end of turn
  prev_hp = CACHE.hp
  prev_hp_max = CACHE.mhp
  prev_mp = CACHE.mp
  prev_mp_max = CACHE.mmp
end
