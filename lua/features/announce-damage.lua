----- Announce changes in HP/MP; modified from https://github.com/magus/dcss -----
local prev

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
    return with_color(COLORS.darkgrey, delta)
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
end


------------------- Hooks -------------------
function ready_announce_damage()
  -- Skip message on initializing game
  if prev.hp > 0 then
    local hp_delta = CACHE.hp - prev.hp
    local mhp_delta = CACHE.mhp - prev.mhp
    local damage_taken = mhp_delta -hp_delta
    local mp_delta = CACHE.mp - prev.mp
    local mmp_delta = CACHE.mmp - prev.mmp

    local msg_tokens = {}

    -- MP message
    if math.abs(mp_delta) > CONFIG.announce_mp_threshold then
      msg_tokens[#msg_tokens + 1] = create_meter(
        CACHE.mp / CACHE.mmp * 100, EMOJI.MP_FULL_PIP, EMOJI.MP_PART_PIP, EMOJI.MP_EMPTY_PIP, EMOJI.MP_BORDER
      )
      msg_tokens[#msg_tokens + 1] = with_color(COLORS.lightcyan, string.format(" MP[%s]", format_delta(mp_delta)))
      msg_tokens[#msg_tokens + 1] = format_ratio(CACHE.mp, CACHE.mmp)
      if mmp_delta ~= 0 then
        msg_tokens[#msg_tokens + 1] = with_color(COLORS.cyan, string.format(" (%s max MP)", format_delta(mmp_delta)))
      end
      if CACHE.mp == CACHE.mmp then
        msg_tokens[#msg_tokens + 1] = with_color(COLORS.lightcyan, " (Full MP)")
      end
    end

    -- HP message
    if math.abs(hp_delta) > CONFIG.announce_hp_threshold then
      -- If no MP msg, include empty line (w 1-space offset to align)
      msg_tokens[#msg_tokens + 1] = "\n "

      msg_tokens[#msg_tokens + 1] = create_meter(
        CACHE.hp / CACHE.mhp * 100, EMOJI.HP_FULL_PIP, EMOJI.HP_PART_PIP, EMOJI.HP_EMPTY_PIP, EMOJI.HP_BORDER
      )
      msg_tokens[#msg_tokens + 1] = with_color(COLORS.white, string.format(" HP[%s]", format_delta(hp_delta)))
      msg_tokens[#msg_tokens + 1] = format_ratio(CACHE.hp, CACHE.mhp)
      if mhp_delta ~= 0 then
        msg_tokens[#msg_tokens + 1] = with_color(COLORS.lightgrey, string.format(" (%s max HP)", format_delta(mhp_delta)))
      end
      if CACHE.hp == CACHE.mhp then
        msg_tokens[#msg_tokens + 1] = with_color(COLORS.white, " (Full HP)")
      end
    end

    if #msg_tokens > 0 then enqueue_mpr(table.concat(msg_tokens)) end
    
    -- Damage-related warnings
    if (damage_taken >= CACHE.mhp * CONFIG.dmg_flash_threshold) then
      local summary_tokens = {}
      local is_force_more_msg = damage_taken >= (CACHE.mhp * CONFIG.dmg_fm_threshold)
      if is_force_more_msg then
        summary_tokens[#summary_tokens + 1] = "\n"
        summary_tokens[#summary_tokens + 1] = EMOJI.EXCLAMATION_2
        summary_tokens[#summary_tokens + 1] = with_color(COLORS.lightmagenta, " MASSIVE DAMAGE ")
        summary_tokens[#summary_tokens + 1] = EMOJI.EXCLAMATION_2
      else
        summary_tokens[#summary_tokens + 1] = "\n"
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
