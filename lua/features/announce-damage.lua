--[[
Feature: announce-damage
Description: Announces changes in HP/MP with visual meters and damage warnings
Author: magus, buehler
Dependencies: CONFIG
--]]

f_announce_damage = {}
f_announce_damage.BRC_FEATURE_NAME = "announce-damage"

-- Persistent variables
ad_prev = BRC.data.persist("ad_prev", { hp = 0, mhp = 0, mp = 0, mmp = 0 })

-- Local constants
local METER_LENGTH = 7 + 2 * (BRC.Emoji.HP_BORDER and #BRC.Emoji.HP_BORDER or 0)

-- Local functions
local function create_meter(perc, emojis)
  perc = math.max(0, math.min(1, perc))
  local border = emojis.BORDER or ""

  -- Calculate meter segments (5 segments total, each representing 20%)
  local decade = math.floor(perc * 10)
  local full_segments = string.rep(emojis.FULL, math.floor(decade / 2))
  local part_segments = string.rep(emojis.PART, decade % 2)
  local empty_segments = string.rep(emojis.EMPTY, 5 - full_segments - part_segments)

  return table.concat({ border, full_segments, part_segments, empty_segments, border })
end

local function format_delta(delta)
  if delta > 0 then
    return BRC.text.green(string.format("+%s", delta))
  elseif delta < 0 then
    return BRC.text.red(delta)
  else
    return BRC.text.darkgrey("+0")
  end
end

local function format_ratio(cur, max)
  local color
  if cur <= (max * 0.25) then
    color = BRC.COLORS.lightred
  elseif cur <= (max * 0.50) then
    color = BRC.COLORS.red
  elseif cur <= (max * 0.75) then
    color = BRC.COLORS.yellow
  elseif cur < max then
    color = BRC.COLORS.white
  else
    color = BRC.COLORS.green
  end

  return BRC.text.color(color, string.format(" -> %s/%s", cur, max))
end

local function get_hp_message(hp_delta, mhp_delta)
  local hp, mhp = you.hp()
  local msg_tokens = {}
  msg_tokens[#msg_tokens + 1] = create_meter(hp / mhp, BRC.Emoji.HP_METER)
  msg_tokens[#msg_tokens + 1] = BRC.text.white(string.format(" HP[%s]", format_delta(hp_delta)))
  msg_tokens[#msg_tokens + 1] = format_ratio(hp, mhp)

  if mhp_delta ~= 0 then
    local text = string.format(" (%s max HP)", format_delta(mhp_delta))
    msg_tokens[#msg_tokens + 1] = BRC.text.lightgrey(text)
  end

  if not BRC.Config.announce.same_line and hp == mhp then
    msg_tokens[#msg_tokens + 1] = BRC.text.white(" (Full HP)")
  end

  return table.concat(msg_tokens)
end

local function get_mp_message(mp_delta, mmp_delta)
  local mp, mmp = you.mp()
  local msg_tokens = {}
  msg_tokens[#msg_tokens + 1] = create_meter(mp / mmp, BRC.Emoji.MP_METER)
  msg_tokens[#msg_tokens + 1] = BRC.text.lightcyan(string.format(" MP[%s]", format_delta(mp_delta)))
  msg_tokens[#msg_tokens + 1] = format_ratio(mp, mmp)

  if mmp_delta ~= 0 then
    local tok = string.format(" (%s max MP)", format_delta(mmp_delta))
    msg_tokens[#msg_tokens + 1] = BRC.text.cyan(tok)
  end

  if not BRC.Config.announce.same_line and mp == mmp then
    msg_tokens[#msg_tokens + 1] = BRC.text.lightcyan(" (Full MP)")
  end

  return table.concat(msg_tokens)
end

local function last_msg_is_meter()
  local last_msg = crawl.messages(1)
  local check = last_msg and #last_msg > METER_LENGTH + 4 and last_msg:sub(METER_LENGTH + 1, METER_LENGTH + 4)
  return check and (check == " HP[" or check == " MP[")
end

-- Hook functions
function f_announce_damage.init()
  ad_prev.hp = 0
  ad_prev.mhp = 0
  ad_prev.mp = 0
  ad_prev.mmp = 0

  if BRC.Config.dmg_fm_threshold > 0 and BRC.Config.dmg_fm_threshold <= 0.5 then
    crawl.setopt("message_colour ^= mute:Ouch! That really hurt!")
  end
end

function f_announce_damage.ready()
  -- Update prev state first, so we can safely return early below
  local hp, mhp = you.hp()
  local mp, mmp = you.mp()
  local is_startup = ad_prev.hp == 0
  local hp_delta = hp - ad_prev.hp
  local mp_delta = mp - ad_prev.mp
  local mhp_delta = mhp - ad_prev.mhp
  local mmp_delta = mmp - ad_prev.mmp
  local damage_taken = mhp_delta - hp_delta
  ad_prev.hp = hp
  ad_prev.mhp = mhp
  ad_prev.mp = mp
  ad_prev.mmp = mmp

  if is_startup then return end
  if hp_delta == 0 and mp_delta == 0 and last_msg_is_meter() then return end
  local is_very_low_hp = hp <= BRC.Config.announce.very_low_hp * mhp

  -- Determine which messages to show
  local do_hp = true
  local do_mp = true
  if hp_delta <= 0 and hp_delta > -BRC.Config.announce.hp_loss_limit then do_hp = false end
  if hp_delta >= 0 and hp_delta < BRC.Config.announce.hp_gain_limit then do_hp = false end
  if mp_delta <= 0 and mp_delta > -BRC.Config.announce.mp_loss_limit then do_mp = false end
  if mp_delta >= 0 and mp_delta < BRC.Config.announce.mp_gain_limit then do_mp = false end

  if not do_hp and is_very_low_hp and hp_delta ~= 0 then do_hp = true end
  if not do_hp and not do_mp then return end
  if BRC.Config.announce.always_both then
    do_hp = true
    do_mp = true
  end

  -- Put messages together
  local hp_msg = get_hp_message(hp_delta, mhp_delta)
  local mp_msg = get_mp_message(mp_delta, mmp_delta)
  local msg_tokens = {}
  msg_tokens[1] = (BRC.Config.announce.hp_first and do_hp) and hp_msg or mp_msg
  if do_mp and do_hp then
    msg_tokens[2] = BRC.Config.announce.same_line and "       " or "\n"
    msg_tokens[3] = BRC.Config.announce.hp_first and mp_msg or hp_msg
  end
  if #msg_tokens > 0 then BRC.mpr.que(table.concat(msg_tokens)) end

  -- Add Damage-related warnings, when damage >= threshold
  if damage_taken >= mhp * BRC.Config.dmg_flash_threshold then
    if is_very_low_hp then return end -- mute % HP alerts
    local is_force_more_msg = damage_taken >= (mhp * BRC.Config.dmg_fm_threshold)
    local emoji, msg
    if is_force_more_msg then
      emoji = BRC.Emoji.EXCLAMATION_2
      msg = BRC.text.lightmagenta(" MASSIVE DAMAGE ")
    else
      emoji = BRC.Emoji.EXCLAMATION
      msg = BRC.text.magenta(" BIG DAMAGE ")
    end
    BRC.mpr.que_optmore(is_force_more_msg, emoji .. msg .. emoji)
  end
end
