---------------------------------------------------------------------------------------------------
-- BRC feature module: announce-hp-mp
-- @module f_announce_hp_mp
-- @author magus, buehler
-- Announce changes in HP/MP, with visual meters and additional warnings for severe damage.
---------------------------------------------------------------------------------------------------

f_announce_hp_mp = {}
f_announce_hp_mp.BRC_FEATURE_NAME = "announce-hp-mp"
f_announce_hp_mp.Config = {
  dmg_flash_threshold = 0.20, -- Flash screen when losing this % of max HP
  dmg_fm_threshold = 0.30, -- Force more for losing this % of max HP
  always_on_bottom = false, -- Rewrite HP/MP meters after each turn with messages
  meter_length = 5, -- Number of pips in each meter

  Announce = {
    hp_loss_limit = 1, -- Announce when HP loss >= this
    hp_gain_limit = 4, -- Announce when HP gain >= this
    mp_loss_limit = 1, -- Announce when MP loss >= this
    mp_gain_limit = 2, -- Announce when MP gain >= this
    hp_first = true, -- Show HP first in the message
    same_line = true, -- Show HP/MP on the same line
    always_both = true, -- If showing one, show both
    very_low_hp = 0.10, -- At this % of max HP, show all HP changes and mute % HP alerts
  },

  HP_METER = BRC.Config.emojis and { FULL = "❤️", PART = "❤️‍🩹", EMPTY = "🤍" } or {
    BORDER = BRC.txt.white("|"),
    FULL = BRC.txt.lightgreen("+"),
    PART = BRC.txt.lightgrey("+"),
    EMPTY = BRC.txt.darkgrey("-"),
  },

  MP_METER = BRC.Config.emojis and { FULL = "🟦", PART = "🔹", EMPTY = "➖" } or {
    BORDER = BRC.txt.white("|"),
    FULL = BRC.txt.lightblue("+"),
    PART = BRC.txt.lightgrey("+"),
    EMPTY = BRC.txt.darkgrey("-"),
  },
} -- f_announce_hp_mp.Config (do not remove this comment)

---- Persistent variables ----
ad_prev = BRC.Data.persist("ad_prev", { hp = 0, mhp = 0, mp = 0, mmp = 0 })

---- Local constants ----
local ALWAYS_BOTTOM_SETTINGS = {
  hp_loss_limit = 0, hp_gain_limit = 0, mp_loss_limit = 0, mp_gain_limit = 0,
  hp_first = true, same_line = true, always_both = true, very_low_hp = 0,
} -- ALWAYS_BOTTOM_SETTINGS (do not remove this comment)

---- Local variables ----
local Config

---- Initialization ----
function f_announce_hp_mp.init()
  Config = f_announce_hp_mp.Config

  ad_prev.hp = 0
  ad_prev.mhp = 0
  ad_prev.mp = 0
  ad_prev.mmp = 0

  if Config.always_on_bottom then Config.Announce = ALWAYS_BOTTOM_SETTINGS end

  if Config.dmg_fm_threshold > 0 and Config.dmg_fm_threshold <= 0.5 then
      BRC.opt.message_mute("Ouch! That really hurt!", true)
  end
end

---- Local functions ----
local function create_meter(perc, emojis)
  perc = math.max(0, math.min(1, perc)) -- Clamp between 0 and 1

  local num_halfpips = math.floor(perc * Config.meter_length * 2)
  local num_full_emojis = math.floor(num_halfpips / 2)
  local num_part_emojis = num_halfpips % 2
  local num_empty_emojis = Config.meter_length - num_full_emojis - num_part_emojis

  return table.concat({
    emojis.BORDER or "",
    string.rep(emojis.FULL, num_full_emojis),
    string.rep(emojis.PART, num_part_emojis),
    string.rep(emojis.EMPTY, num_empty_emojis),
    emojis.BORDER or "",
  })
end

local function format_delta(delta)
  if delta > 0 then
    return BRC.txt.green("+" .. delta)
  elseif delta < 0 then
    return BRC.txt.red(delta)
  else
    return BRC.txt.darkgrey("+0")
  end
end

local function format_ratio(cur, max)
  local color
  if cur <= (max * 0.25) then
    color = BRC.COL.lightred
  elseif cur <= (max * 0.50) then
    color = BRC.COL.red
  elseif cur <= (max * 0.75) then
    color = BRC.COL.yellow
  elseif cur < max then
    color = BRC.COL.white
  else
    color = BRC.COL.green
  end

  return BRC.txt[color](string.format(" -> %s/%s", cur, max))
end

local function get_hp_message(hp_delta, mhp_delta)
  local hp, mhp = you.hp()
  local msg_tokens = {}
  msg_tokens[#msg_tokens + 1] = create_meter(hp / mhp, Config.HP_METER)
  msg_tokens[#msg_tokens + 1] = BRC.txt.white(string.format(" HP[%s]", format_delta(hp_delta)))
  msg_tokens[#msg_tokens + 1] = format_ratio(hp, mhp)

  if mhp_delta ~= 0 then
    local text = string.format(" (%s max HP)", format_delta(mhp_delta))
    msg_tokens[#msg_tokens + 1] = BRC.txt.lightgrey(text)
  end

  if not Config.Announce.same_line and hp == mhp then
    msg_tokens[#msg_tokens + 1] = BRC.txt.white(" (Full HP)")
  end

  return table.concat(msg_tokens)
end

local function get_mp_message(mp_delta, mmp_delta)
  local mp, mmp = you.mp()
  local msg_tokens = {}
  msg_tokens[#msg_tokens + 1] = create_meter(mp / mmp, Config.MP_METER)
  msg_tokens[#msg_tokens + 1] = BRC.txt.lightcyan(string.format(" MP[%s]", format_delta(mp_delta)))
  msg_tokens[#msg_tokens + 1] = format_ratio(mp, mmp)

  if mmp_delta ~= 0 then
    local tok = string.format(" (%s max MP)", format_delta(mmp_delta))
    msg_tokens[#msg_tokens + 1] = BRC.txt.cyan(tok)
  end

  if not Config.Announce.same_line and mp == mmp then
    msg_tokens[#msg_tokens + 1] = BRC.txt.lightcyan(" (Full MP)")
  end

  return table.concat(msg_tokens)
end

local function last_msg_is_meter()
  local meter_chars = Config.meter_length + 2 * #(BRC.txt.clean(Config.HP_METER.BORDER) or "")
  local last_msg = crawl.messages(1)
  if not (last_msg and #last_msg > meter_chars + 4) then return false end

  local s = last_msg:sub(meter_chars + 1, meter_chars + 4)
  return s == " HP[" or s == " MP["
end

---- Crawl hook functions ----
function f_announce_hp_mp.ready()
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
  local is_very_low_hp = hp <= Config.Announce.very_low_hp * mhp

  -- Determine which messages to show
  local do_hp = true
  local do_mp = true
  if hp_delta <= 0 and hp_delta > -Config.Announce.hp_loss_limit then do_hp = false end
  if hp_delta >= 0 and hp_delta < Config.Announce.hp_gain_limit then do_hp = false end
  if mp_delta <= 0 and mp_delta > -Config.Announce.mp_loss_limit then do_mp = false end
  if mp_delta >= 0 and mp_delta < Config.Announce.mp_gain_limit then do_mp = false end

  if not do_hp and is_very_low_hp and hp_delta ~= 0 then do_hp = true end
  if not do_hp and not do_mp then return end
  if Config.Announce.always_both then
    do_hp = true
    do_mp = true
  end

  -- Put messages together
  local hp_msg = get_hp_message(hp_delta, mhp_delta)
  local mp_msg = get_mp_message(mp_delta, mmp_delta)
  local msg_tokens = {}
  msg_tokens[1] = (Config.Announce.hp_first and do_hp) and hp_msg or mp_msg
  if do_mp and do_hp then
    msg_tokens[2] = Config.Announce.same_line and string.rep(" ", 7) or "\n"
    msg_tokens[3] = Config.Announce.hp_first and mp_msg or hp_msg
  end
  if #msg_tokens > 0 then BRC.mpr.que(table.concat(msg_tokens)) end

  -- Add Damage-related warnings, when damage >= threshold
  if damage_taken >= mhp * Config.dmg_flash_threshold then
    if is_very_low_hp then return end -- mute % HP alerts
    if damage_taken >= (mhp * Config.dmg_fm_threshold) then
      local msg = BRC.txt.lightmagenta("MASSIVE DAMAGE")
      BRC.mpr.que_optmore(true, BRC.txt.wrap(msg, BRC.EMOJI.EXCLAMATION_2))
    else
      local msg = BRC.txt.magenta("BIG DAMAGE")
      BRC.mpr.que_optmore(false, BRC.txt.wrap(msg, BRC.EMOJI.EXCLAMATION))
    end
  end
end
