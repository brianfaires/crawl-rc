----- Initially from https://github.com/magus/dcss -----
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/constants.lua")
loadfile("crawl-rc/lua/emojis.lua")
loadfile("crawl-rc/lua/util.lua")

local BIG_DAMAGE_MSG = "BIG DAMAGE!"
local MASSIVE_DAMAGE_MSG = "MASSIVE DAMAGE!!"
crawl.setopt("flash_screen_message += " .. BIG_DAMAGE_MSG)
crawl.setopt("force_more_message += " .. MASSIVE_DAMAGE_MSG)

local function delta_color(delta)
  local color = delta < 0 and COLORS.red or COLORS.green
  local signDelta = delta < 0 and delta or "+" .. delta
  return string.format("<%s>%s</%s>", color, signDelta, color)
end

local function create_meter(perc, full, part, empty, border)
  local decade = math.floor(perc / 10)
  local full_count = math.floor(decade / 2)
  local part_count = decade % 2
  local empty_count = 5 - full_count - part_count

  local tokens = {}
  if border then tokens[1] = border end
  for i = 1, full_count do tokens[#tokens + 1] = full end
  for i = 1, part_count do tokens[#tokens + 1] = part end
  for i = 1, empty_count do tokens[#tokens + 1] = empty end
  if border then tokens[#tokens + 1] = border end
  return table.concat(tokens)
end

local function hp_meter()
  return create_meter(
      CACHE.hp / CACHE.mhp * 100,
      EMOJI.HP_FULL_PIP, EMOJI.HP_PART_PIP, EMOJI.HP_EMPTY_PIP, EMOJI.HP_BORDER
    )
end

local function mp_meter()
  return create_meter(
      CACHE.mp / CACHE.mmp * 100,
      EMOJI.MP_FULL_PIP, EMOJI.MP_PART_PIP, EMOJI.MP_EMPTY_PIP, EMOJI.MP_BORDER
    )
end

local AD_Messages = {
  ["HPSimple"] = function(delta)
    return with_color(COLORS.white,
      string.format("HP[%s]", delta_color(0 - delta))
    )
  end,
  ["HPMax"] = function (_, _, hpm, delta)
    crawl.mpr(
      with_color(COLORS.lightgreen,
        string.format("Max HP: %s (%s).", hpm, delta_color(delta))
      )
    )
  end,
  ["HPLoss"] = function (color, hp, hpm, loss)
    crawl.mpr(
      with_color(COLORS.red, string.format("Took %s damage ", loss)) ..
      with_color(color, string.format("-> %s/%s HP", hp, hpm))
    )
  end,
  ["HPGain"] = function (color, hp, hpm, gain)
    crawl.mpr(
      with_color(COLORS.lightgreen, string.format("Gained %s HP ", gain)) ..
      with_color(color, string.format("-> %s/%s HP", hp, hpm))
    )
  end,
  ["HPFull"] = function (_, hp)
    crawl.mpr(
      with_color(COLORS.lightgreen,
        string.format("Full HP (%s).", hp)
      )
    )
  end,
  ["HPBig"] = function ()
    crawl.mpr(
      with_color(COLORS.magenta, BIG_DAMAGE_MSG)
    )
  end,["HPMassive"] = function ()
    crawl.mpr(
      with_color(COLORS.lightred, MASSIVE_DAMAGE_MSG)
    )
  end,
  ["MPSimple"] = function(delta)
    return with_color(COLORS.white,
      string.format("MP[%s]", delta_color(0 - delta))
    )
  end,
  ["MPLoss"] = function (color, mp, mpm, loss)
    crawl.mpr(
      with_color(COLORS.cyan, string.format("Lost %s MP ", loss)) ..
      with_color(color, string.format("-> %s/%s MP", mp, mpm))
    )
  end,
  ["MPGain"] = function (color, mp, mpm, gain)
    crawl.mpr(
      with_color(COLORS.cyan, string.format("Gained %s MP ", gain)) ..
      with_color(color, string.format("-> %s/%s MP", mp, mpm))
    )
  end,
  ["MPFull"] = function (_, mp)
    crawl.mpr(
      with_color(COLORS.cyan, string.format("Full MP (%s).", mp))
    )
  end,
  [""]="",
} --AD_Messages (do not remove this comment)

local prev_hp = 0
local prev_hp_max = 0
local prev_mp = 0
local prev_mp_max = 0

-- Simplified condensed HP and MP output
-- Print a single condensed line showing HP & MP changes
-- Includes HP/MP meters
local function simple_announce_damage(hp_lost, mp_lost)
  local emoji
  local message
  
  if hp_lost > CONFIG.ANNOUNCE_HP_THRESHOLD then
    if mp_lost > CONFIG.ANNOUNCE_MP_THRESHOLD then
      -- HP[-2] MP[-1]
      message = string.format("%s %s %s %s", hp_meter(), AD_Messages.HPSimple(hp_lost), AD_Messages.MPSimple(mp_lost), mp_meter())
    else
      -- HP[-2]
      message = string.format("%s %s", hp_meter(), AD_Messages.HPSimple(hp_lost))
    end
  elseif mp_lost > CONFIG.ANNOUNCE_MP_THRESHOLD then
    -- MP[-1]
    message = string.format("%s %s", mp_meter(), AD_Messages.MPSimple(mp_lost))
  end

  if message ~= nil then
    crawl.mpr(string.format("\n%s", message))
  end
end


local function color_by_max(message_func, cur, max, diff)
  if cur <= (max * 0.25) then
    message_func(COLORS.lightred, cur, max, diff)
  elseif cur <= (max * 0.50) then
    message_func(COLORS.red, cur, max, diff)
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

    -- Simplified condensed HP and MP output, with HP meter
    simple_announce_damage(hp_lost, mp_lost)

    -- HP Max Loss/Gain
    if mhp_lost < 0 then
      AD_Messages.HPMax(COLORS.yellow, CACHE.hp, CACHE.mhp, mhp_lost)
    elseif mhp_lost > 0 then
      AD_Messages.HPMax(COLORS.green, CACHE.hp, CACHE.mhp, mhp_lost)
    end

    -- HP Loss/Gain/Full
    if (hp_lost_relative > CONFIG.ANNOUNCE_HP_THRESHOLD) then
      color_by_max(AD_Messages.HPLoss, CACHE.hp, CACHE.mhp, hp_lost)
      if hp_lost > (CACHE.mhp * CONFIG.DAMAGE_FORCE_MORE_THRESHOLD) then
        AD_Messages.HPMassive()
      elseif (hp_lost_relative > CACHE.mhp * CONFIG.DAMAGE_FLASH_THRESHOLD) then
        AD_Messages.HPBig()
      end
    elseif (hp_lost_relative < -CONFIG.ANNOUNCE_HP_THRESHOLD) then
      if (hp_lost < 0) then
        color_by_max(AD_Messages.HPGain, CACHE.hp, CACHE.mhp, -hp_lost)
      end
    elseif hp_lost_relative ~= 0 and CACHE.hp == CACHE.mhp then
      AD_Messages.HPFull(nil, CACHE.hp)
    end

    -- MP Loss/Gain/Full
    if (mp_lost_relative > CONFIG.ANNOUNCE_MP_THRESHOLD) then
      color_by_max(AD_Messages.MPLoss, CACHE.mp, CACHE.mmp, mp_lost)
    elseif (mp_lost_relative < -CONFIG.ANNOUNCE_MP_THRESHOLD) then
      if (mp_lost < 0) then
        color_by_max(AD_Messages.MPGain, CACHE.mp, CACHE.mmp, -mp_lost)
      end
    elseif mp_lost_relative ~= 0 and CACHE.mp == CACHE.mmp then
      AD_Messages.MPFull(nil, CACHE.mp)
    end
  end

  prev_hp = CACHE.hp
  prev_hp_max = CACHE.mhp
  prev_mp = CACHE.mp
  prev_mp_max = CACHE.mmp
end
