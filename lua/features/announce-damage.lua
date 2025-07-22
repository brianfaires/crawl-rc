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
  if math.abs(hp_delta) <= CONFIG.announce.hp_threshold then return end
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
  if math.abs(mp_delta) <= CONFIG.announce.mp_threshold then return end
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

------------------- Hooks -------------------
local METER_LENGTH = 7 + 2 * (HP_BORDER and #EMOJI.HP_BORDER or 0)
function ready_announce_damage()
  if CONFIG.announce.hp_threshold < 0 or CONFIG.announce.mp_threshold < 0 then
    local last_msg = crawl.messages(1)
    local check = last_msg and #last_msg > METER_LENGTH+4 and last_msg:sub(METER_LENGTH+1,METER_LENGTH+4)
    if check and (check == " HP[" or check == " MP[") then
      return
    end
  end

  -- Skip message on initializing game
  if prev.hp > 0 then
    local hp_delta = CACHE.hp - prev.hp
    local mhp_delta = CACHE.mhp - prev.mhp
    local damage_taken = mhp_delta - hp_delta

    local msg_tokens = {}
    if CONFIG.announce.hp_first then
      msg_tokens[#msg_tokens + 1] = get_hp_message(hp_delta, mhp_delta)
    else
      msg_tokens[#msg_tokens + 1] = get_mp_message(CACHE.mp - prev.mp, CACHE.mmp - prev.mmp)
    end
    
    if msg_tokens[1] then msg_tokens[2] = CONFIG.announce.same_line and "       " or "\n" end
    
    if CONFIG.announce.hp_first then
      msg_tokens[#msg_tokens + 1] = get_mp_message(CACHE.mp - prev.mp, CACHE.mmp - prev.mmp)
    else
      msg_tokens[#msg_tokens + 1] = get_hp_message(hp_delta, mhp_delta)
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
