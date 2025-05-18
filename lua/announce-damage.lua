----- Initially from https://github.com/magus/dcss -----
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/constants.lua")
loadfile("crawl-rc/lua/util.lua")

local AD_Messages = {
  ["HPSimple"] = function(delta)
    return colorize_itext(COLORS.white,
      string.format("HP[%s]", delta_color(0 - delta))
    )
  end,
  ["HPMax"] = function (_, _, hpm, delta)
    crawl.mpr(
      colorize_itext(COLORS.lightgreen,
        string.format("You now have %s max hp (%s).", hpm, delta_color(delta))
      )
    )
  end,
  ["HPLoss"] = function (color, hp, hpm, loss)
    crawl.mpr(
      string.format("%s%s",
        colorize_itext(COLORS.red, string.format("You take %s damage,", loss)),
        colorize_itext(color, string.format(" and now have %s/%s hp.", hp, hpm))
      )
    )
  end,
  ["HPGain"] = function (color, hp, hpm, gain)
    crawl.mpr(
      string.format("%s%s",
        colorize_itext(COLORS.lightgreen, string.format("You regained %s hp,", gain)),
        colorize_itext(color, string.format(" and now have %s/%s hp.", hp, hpm))
      )
    )
  end,
  ["HPFull"] = function (_, hp)
    crawl.mpr(
      colorize_itext(COLORS.lightgreen,
        string.format("Your hp is fully restored (%s).", hp)
      )
    )
  end,
  ["HPMassivePause"] = function ()
    crawl.mpr(
      colorize_itext(COLORS.lightred,
        string.format("MASSIVE DAMAGE!! (%s)", PAUSE_MORE)
      )
    )
  end,
  ["MPSimple"] = function(delta)
    return colorize_itext(COLORS.white,
      string.format("MP[%s]", delta_color(0 - delta))
    )
  end,
  ["MPLoss"] = function (color, mp, mpm, loss)
    crawl.mpr(
      string.format("%s%s",
        colorize_itext(COLORS.cyan, string.format("You lost %s mp,", loss)),
        colorize_itext(color, string.format(" and now have %s/%s mp.", mp, mpm))
      )
    )
  end,
  ["MPGain"] = function (color, mp, mpm, gain)
    crawl.mpr(
      string.format("%s%s",
        colorize_itext(COLORS.cyan, string.format("You regained %s mp,", gain)),
        colorize_itext(color, string.format(" and now have %s/%s mp.", mp, mpm))
      )
    )
  end,
  ["MPFull"] = function (_, mp)
    crawl.mpr(
      colorize_itext(COLORS.cyan, string.format("Your mp is fully restored (%s).", mp))
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

  -- MP[-1]
  if hp_diff == 0 and mp_diff ~= 0 then
    message = AD_Messages.MPSimple(mp_diff)
  -- HP[-2]
  elseif hp_diff ~= 0 and mp_diff == 0 then
    message = AD_Messages.HPSimple(hp_diff)
  -- HP[-2] MP[-1]
  elseif hp_diff ~= 0 and mp_diff ~= 0 then
    message = string.format("%s %s", AD_Messages.HPSimple(hp_diff), AD_Messages.MPSimple(mp_diff))
  -- else -- No changes
  end

  if message ~= nil then
    if l_cache.hp <= (l_cache.mhp * 0.25) then
      emoji = "😱"
    elseif l_cache.hp <= (l_cache.mhp * 0.50) then
      emoji = "😨"
    elseif l_cache.hp <= (l_cache.mhp *  0.75) then
      emoji = "😮"
    elseif l_cache.hp < l_cache.mhp then
      emoji = "😕"
    else
      emoji = "😎"
    end

    if CONFIG.emojis then
      crawl.mpr(string.format("\n%s %s", emoji, message))
    else
      crawl.mpr(string.format("\n%s", message))
    end

  end
end

-- Try to sync with colors defined in Interface.rc
local function color_by_max(message_func, curr, max, diff)
  if curr <= (max * 0.25) then
    message_func(COLORS.red, curr, max, diff)
  elseif curr <= (max * 0.50) then
    message_func(COLORS.lightred, curr, max, diff)
  elseif curr <= (max *  0.75) then
    message_func(COLORS.yellow, curr, max, diff)
  else
    message_func(COLORS.lightgrey, curr, max, diff)
  end
end

function announce_damage()
  --Skips message on initializing game
  if prev_hp > 0 then
    local hp_diff = prev_hp - l_cache.hp
    local l_cache.mhp_diff = l_cache.mhp - prev_hp_max
    local mp_diff = prev_mp - l_cache.mp
    local l_cache.mmp_diff = l_cache.mmp - prev_mp_max

    -- Simplified condensed HP and MP output
    simple_announce_damage(hp_diff, mp_diff)

    -- HP Max
    if l_cache.mhp_diff > 0 then
      AD_Messages.HPMax(COLORS.green, l_cache.hp, l_cache.mhp, l_cache.mhp_diff)
    elseif l_cache.mhp_diff < 0 then
      AD_Messages.HPMax(COLORS.yellow, l_cache.hp, l_cache.mhp, l_cache.mhp_diff)
    end

    -- HP Loss relative to max HP change
    if (hp_diff - l_cache.mhp_diff > CONFIG.ANNOUNCE_HP_THRESHOLD) then
      color_by_max(AD_Messages.HPLoss, l_cache.hp, l_cache.mhp, hp_diff)

      if hp_diff > (l_cache.mhp * 0.20) then
        AD_Messages.HPMassivePause()
      end
    end

    -- HP Gain
    if (hp_diff - l_cache.mhp_diff < -CONFIG.ANNOUNCE_HP_THRESHOLD) then
      -- Remove the negative sign by taking absolute value
      local hp_gain = math.abs(hp_diff)

      if (hp_gain > 1) and (l_cache.hp ~= l_cache.mhp) then
        color_by_max(AD_Messages.HPGain, l_cache.hp, l_cache.mhp, hp_gain)
      end

      if (l_cache.hp == l_cache.mhp) then
        AD_Messages.HPFull(nil, l_cache.hp)
      end
    end

    -- MP Gain
    -- More than 1 MP gained
    if (mp_diff - l_cache.mmp_diff < -CONFIG.ANNOUNCE_MP_THRESHOLD) then
      -- Remove the negative sign by taking absolute value
      local mp_gain = math.abs(mp_diff)

      if (mp_gain > 1) and (l_cache.mp ~= l_cache.mmp) then
        color_by_max(AD_Messages.MPGain, l_cache.mp, l_cache.mmp, mp_gain)
      end

      if (l_cache.mp == l_cache.mmp) then
        AD_Messages.MPFull(nil, l_cache.mp)
      end
    end

    -- MP Loss
    -- Ensure we lost MORE than the change in max mp
    -- i.e. a change in max mp should not be considered loss
    if (mp_diff - l_cache.mmp_diff > CONFIG.ANNOUNCE_MP_THRESHOLD) then
      color_by_max(AD_Messages.MPLoss, l_cache.mp, l_cache.mmp, mp_diff)
    end

  end

  --Set previous hp/mp and form at end of turn
  prev_hp = l_cache.hp
  prev_hp_max = l_cache.mhp
  prev_mp = l_cache.mp
  prev_mp_max = l_cache.mmp
end
