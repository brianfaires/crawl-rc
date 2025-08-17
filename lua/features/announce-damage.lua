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
  prev.turn = you.turns()

  if CONFIG.dmg_fm_threshold > 0 and CONFIG.dmg_fm_threshold <= 0.5 then
    crawl.setopt("message_colour ^= mute:Ouch! That really hurt!")
  end
end

local function get_hp_message(hp_delta, mhp_delta)
  local hp, mhp = you.hp()

  local msg_tokens = {}
  msg_tokens[#msg_tokens + 1] = create_meter(
    hp / mhp * 100, EMOJI.HP_FULL_PIP, EMOJI.HP_PART_PIP, EMOJI.HP_EMPTY_PIP, EMOJI.HP_BORDER
  )
  msg_tokens[#msg_tokens + 1] = with_color(COLORS.white, string.format(" HP[%s]", format_delta(hp_delta)))
  msg_tokens[#msg_tokens + 1] = format_ratio(hp, mhp)
  if mhp_delta ~= 0 then
    msg_tokens[#msg_tokens + 1] = with_color(COLORS.lightgrey, string.format(" (%s max HP)", format_delta(mhp_delta)))
  end

  if not CONFIG.announce.same_line and hp == mhp then
    msg_tokens[#msg_tokens + 1] = with_color(COLORS.white, " (Full HP)")
  end
  return table.concat(msg_tokens)
end

local function get_mp_message(mp_delta, mmp_delta)
  local mp, mmp = you.mp()
  local msg_tokens = {}
  msg_tokens[#msg_tokens + 1] = create_meter(
    mp / mmp * 100, EMOJI.MP_FULL_PIP, EMOJI.MP_PART_PIP, EMOJI.MP_EMPTY_PIP, EMOJI.MP_BORDER
  )
  msg_tokens[#msg_tokens + 1] = with_color(COLORS.lightcyan, string.format(" MP[%s]", format_delta(mp_delta)))
  msg_tokens[#msg_tokens + 1] = format_ratio(mp, mmp)
  if mmp_delta ~= 0 then
    msg_tokens[#msg_tokens + 1] = with_color(COLORS.cyan, string.format(" (%s max MP)", format_delta(mmp_delta)))
  end
  if not CONFIG.announce.same_line and mp == mmp then
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
  -- Process `prev` early, so we can use returns over nested ifs
  local hp, mhp = you.hp()
  local mp, mmp = you.mp()
  local is_startup = prev.hp == 0
  local hp_delta = hp - prev.hp
  local mp_delta = mp - prev.mp
  local mhp_delta = mhp - prev.mhp
  local mmp_delta = mmp - prev.mmp
  local damage_taken = mhp_delta - hp_delta
  prev.hp = hp
  prev.mhp = mhp
  prev.mp = mp
  prev.mmp = mmp

  if is_startup then return end
  if hp_delta == 0 and mp_delta == 0 and last_msg_is_meter() then return end
  local is_very_low_hp = hp <= CONFIG.announce.very_low_hp * mhp


  -- Determine which messages to show
  local do_hp = true
  local do_mp = true
  if hp_delta <= 0 and hp_delta > -CONFIG.announce.hp_loss_limit then do_hp = false end
  if hp_delta >= 0 and hp_delta <  CONFIG.announce.hp_gain_limit then do_hp = false end
  if mp_delta <= 0 and mp_delta > -CONFIG.announce.mp_loss_limit then do_mp = false end
  if mp_delta >= 0 and mp_delta <  CONFIG.announce.mp_gain_limit then do_mp = false end

  if not do_hp and is_very_low_hp and hp_delta ~= 0 then do_hp = true end
  if not do_hp and not do_mp then return end
  if CONFIG.announce.always_both then
    do_hp = true
    do_mp = true
  end
  
  -- Put messages together
  local hp_msg = get_hp_message(hp_delta, mhp_delta)
  local mp_msg = get_mp_message(mp_delta, mmp_delta)
  local msg_tokens = {}
  msg_tokens[1] = (CONFIG.announce.hp_first and do_hp) and hp_msg or mp_msg
  if do_mp and do_hp then
    msg_tokens[2] = CONFIG.announce.same_line and "       " or "\n"
    msg_tokens[3] = CONFIG.announce.hp_first and mp_msg or hp_msg
  end
  if #msg_tokens > 0 then enqueue_mpr(table.concat(msg_tokens)) end
  

  -- Add Damage-related warnings, when damage >= threshold
  if (damage_taken >= mhp * CONFIG.dmg_flash_threshold) then
    if is_very_low_hp then return end -- mute % HP alerts
    local summary_tokens = {}
    local is_force_more_msg = damage_taken >= (mhp * CONFIG.dmg_fm_threshold)
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
