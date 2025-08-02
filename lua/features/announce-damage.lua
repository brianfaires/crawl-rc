----- Announce changes in HP/MP; modified from https://github.com/magus/dcss -----
local prev -- contains all previous hp/mp values

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

local function format_delta(delta)
  if delta > 0 then
    return with_color(COLORS.green, "+"..delta)
  elseif delta < 0 then
    return with_color(COLORS.red, delta)
  else
    return with_color(COLORS.darkgrey, "+0")
  end
end

local function format_ratio(cur, max)
  local color
  if cur <= (max * 0.25) then
    color = COLORS.lightred
  elseif cur <= (max * 0.50) then
    color = COLORS.red
  elseif cur <= (max *  0.75) then
    color = COLORS.yellow
  elseif cur < max then
    color = COLORS.white
  else
    color = COLORS.green
  end
  return with_color(color, string.format(" -> %s/%s", cur, max))
end



function init_announce_damage()
  if CONFIG.debug_init then crawl.mpr("Initializing announce-damage") end
  prev = {}
  prev.hp = 0
  prev.mhp = 0
  prev.mp = 0
  prev.mmp = 0
  prev.turn = CACHE.turn

  if CONFIG.dmg_fm_threshold > 0 and CONFIG.dmg_fm_threshold <= 0.5 then
    crawl.setopt("message_colour ^= mute:Ouch! That really hurt!")
  end
end

local function get_hp_message(hp_delta, mhp_delta)
  if hp_delta <= 0 and hp_delta > -CONFIG.announce.hp_loss_limit then return end
  if hp_delta >= 0 and hp_delta < CONFIG.announce.hp_gain_limit then return end
  local msg_tokens = {}
  msg_tokens[#msg_tokens + 1] = create_meter(
    CACHE.hp / CACHE.mhp * 100, EMOJI.HP_FULL_PIP, EMOJI.HP_PART_PIP, EMOJI.HP_EMPTY_PIP, EMOJI.HP_BORDER
  )
  msg_tokens[#msg_tokens + 1] = with_color(COLORS.white, string.format(" HP[%s]", format_delta(hp_delta)))
  msg_tokens[#msg_tokens + 1] = format_ratio(CACHE.hp, CACHE.mhp)
  if mhp_delta ~= 0 then
    msg_tokens[#msg_tokens + 1] = with_color(COLORS.lightgrey, string.format(" (%s max HP)", format_delta(mhp_delta)))
  end

  if not CONFIG.announce.same_line and CACHE.hp == CACHE.mhp then
    msg_tokens[#msg_tokens + 1] = with_color(COLORS.white, " (Full HP)")
  end
  return table.concat(msg_tokens)
end

local function get_mp_message(mp_delta, mmp_delta)
  if mp_delta <= 0 and mp_delta > -CONFIG.announce.mp_loss_limit then return end
  if mp_delta >= 0 and mp_delta < CONFIG.announce.mp_gain_limit then return end
  local msg_tokens = {}
  msg_tokens[#msg_tokens + 1] = create_meter(
    CACHE.mp / CACHE.mmp * 100, EMOJI.MP_FULL_PIP, EMOJI.MP_PART_PIP, EMOJI.MP_EMPTY_PIP, EMOJI.MP_BORDER
  )
  msg_tokens[#msg_tokens + 1] = with_color(COLORS.lightcyan, string.format(" MP[%s]", format_delta(mp_delta)))
  msg_tokens[#msg_tokens + 1] = format_ratio(CACHE.mp, CACHE.mmp)
  if mmp_delta ~= 0 then
    msg_tokens[#msg_tokens + 1] = with_color(COLORS.cyan, string.format(" (%s max MP)", format_delta(mmp_delta)))
  end
  if not CONFIG.announce.same_line and CACHE.mp == CACHE.mmp then
    msg_tokens[#msg_tokens + 1] = with_color(COLORS.lightcyan, " (Full MP)")
  end
  return table.concat(msg_tokens)
end

local METER_LENGTH = 7 + 2 * (EMOJI.HP_BORDER and #EMOJI.HP_BORDER or 0)
local function last_msg_is_meter()
  local last_msg = crawl.messages(1)
  local check = last_msg and #last_msg > METER_LENGTH+4 and last_msg:sub(METER_LENGTH+1,METER_LENGTH+4)
  return check and (check == " HP[" or check == " MP[")
end

------------------- Hooks -------------------
function ready_announce_damage()
  if prev.hp > 0 then
    local hp_delta = CACHE.hp - prev.hp
    local mp_delta = CACHE.mp - prev.mp
    local mhp_delta = CACHE.mhp - prev.mhp
    local mmp_delta = CACHE.mmp - prev.mmp
    local damage_taken = mhp_delta - hp_delta

    if hp_delta == 0 and mp_delta == 0 and last_msg_is_meter() then return end

    local hp_msg = get_hp_message(hp_delta, mhp_delta)
    local mp_msg = get_mp_message(mp_delta, mmp_delta)
    local msg_tokens = {}
    if CONFIG.announce.hp_first then
      msg_tokens[1] = hp_msg
      if mp_msg then
        if #msg_tokens > 0 then msg_tokens[#msg_tokens + 1] = CONFIG.announce.same_line and "       " or "\n" end
        msg_tokens[#msg_tokens + 1] = mp_msg
      end
    else
      msg_tokens[1] = mp_msg
      if hp_msg then
        if #msg_tokens > 0 then msg_tokens[2] = CONFIG.announce.same_line and "       " or "\n" end
        msg_tokens[#msg_tokens + 1] = hp_msg
      end
    end
    if #msg_tokens > 0 then enqueue_mpr(table.concat(msg_tokens)) end
    
    -- Damage-related warnings
    if (damage_taken >= CACHE.mhp * CONFIG.dmg_flash_threshold) then
      local summary_tokens = {}
      local is_force_more_msg = damage_taken >= (CACHE.mhp * CONFIG.dmg_fm_threshold)
      if is_force_more_msg then
        summary_tokens[#summary_tokens + 1] = EMOJI.EXCLAMATION_2
        summary_tokens[#summary_tokens + 1] = with_color(COLORS.lightmagenta, " MASSIVE DAMAGE ")
        summary_tokens[#summary_tokens + 1] = EMOJI.EXCLAMATION_2
      else
        summary_tokens[#summary_tokens + 1] = EMOJI.EXCLAMATION
        summary_tokens[#summary_tokens + 1] = with_color(COLORS.magenta, " BIG DAMAGE ")
        summary_tokens[#summary_tokens + 1] = EMOJI.EXCLAMATION
      end
      enqueue_mpr_opt_more(is_force_more_msg, table.concat(summary_tokens))
    end
  end

  prev.hp = CACHE.hp
  prev.mhp = CACHE.mhp
  prev.mp = CACHE.mp
  prev.mmp = CACHE.mmp
end
