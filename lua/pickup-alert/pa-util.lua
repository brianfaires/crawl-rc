---- Utility functions specific to pickup-alert system ----
-- Functions often duplicate dcss calculations and need to be updated when those change
-- Many functions are specific to buehler.rc, and not necessarily applicable to all RCs

--------- Stat string formatting ---------
local function format_stat(abbr, val, is_worn)
  local stat_str = string.format("%.1f", val)
  if val < 0 then
    return abbr .. stat_str
  elseif is_worn then
    return abbr .. ":" .. stat_str
  else
    return abbr .. "+" .. stat_str
  end
end

function get_armour_info_strings(it)
  if not BRC.is.armour(it) then return "", "" end

  -- Compare against last slot if poltergeist
  local slot_num = you.race() == "Poltergeist" and 6 or 1
  local cur = items.equipped_at(it.equip_type, slot_num)
  local cur_ac = 0
  local cur_sh = 0
  local cur_ev = 0
  local is_worn = it.equipped or (it.ininventory and cur and cur.slot == it.slot)
  if cur and not is_worn then
    -- Only show deltas if not same item
    if BRC.is.shield(cur) then
      cur_sh = get_shield_sh(cur)
      cur_ev = -get_shield_penalty(cur)
    else
      cur_ac = get_armour_ac(cur)
      cur_ev = get_armour_ev(cur)
    end
  end

  if BRC.is.shield(it) then
    local sh_str = format_stat("SH", get_shield_sh(it) - cur_sh, is_worn)
    local ev_str = format_stat("EV", -get_shield_penalty(it) - cur_ev, is_worn)
    return sh_str, ev_str
  else
    local ac_str = format_stat("AC", get_armour_ac(it) - cur_ac, is_worn)
    if not BRC.is.body_armour(it) then return ac_str end
    local ev_str = format_stat("EV", get_armour_ev(it) - cur_ev, is_worn)
    return ac_str, ev_str
  end
end

function get_weapon_info_string(it, dmg_type)
  if not it.is_weapon then return end
  local dmg = get_weap_damage(it, dmg_type or BRC.Config.inscribe_dps_type or BRC.DMG_TYPE.plain)
  local dmg_str = string.format("%.1f", dmg)
  if dmg < 10 then dmg_str = string.format("%.2f", dmg) end
  if dmg > 99.9 then dmg_str = ">100" end

  local delay = get_weap_delay(it)
  local delay_str = string.format("%.1f", delay)
  if delay < 1 then
    delay_str = string.format("%.2f", delay)
    delay_str = delay_str:sub(2, #delay_str)
  end

  local dps = dmg / delay
  local dps_str = string.format("%.1f", dps)
  if dps < 10 then dps_str = string.format("%.2f", dps) end
  if dps > 99.9 then dps_str = ">100" end

  local it_plus = it.plus or 0
  local acc = it.accuracy + it_plus
  if acc >= 0 then acc = "+" .. acc end

  --This would be nice if it worked in all UIs
  --dps_str = "DPS:<w>" .. dps_str .. "</w> "
  --return dps_str .. "(<red>" .. dmg_str .. "</red>/<blue>" .. delay_str .. "</blue>), Acc<w>" .. acc .. "</w>"
  return table.concat({
    "DPS:",
    dps_str,
    " (",
    dmg_str,
    "/",
    delay_str,
    "), Acc",
    acc,
  })
end

--------- Functions for armour and weapons ---------
function get_ego(it)
  if BRC.is.good_ego(it) then
    return type(it.ego) == "string" and it.ego or it.ego(true)
  elseif BRC.is.body_armour(it) then
    local qualname = it.name("qual")
    if qualname:find("dragon scales") or qualname:find("troll leather", 1, true) then return qualname end
  end
end

-- Custom def of ego/branded
function has_ego(it, exclude_stat_only_egos)
  if not it then return false end
  if it.is_weapon then
    if exclude_stat_only_egos then
      local ego = get_ego(it)
      if ego and (ego == "speed" or ego == "heavy") then return false end
    end
    return it.artefact or BRC.is.good_ego(it) or BRC.is.magic_staff(it)
  end

  if it.artefact or BRC.is.good_ego(it) then return true end
  local basename = it.name("base")
  if basename:find("troll leather", 1, true) then return true end
  if basename:find("dragon scales", 1, true) and not basename:find("steam", 1, true) then return true end
  return false
end

--------- Armour (Shadowing crawl calcs) ---------
function get_unadjusted_armour_pen(encumb)
  -- dcss v0.33.1
  local pen = encumb - 2 * BRC.get.mut(BRC.MUTATIONS.sturdy_frame, true)
  if pen > 0 then return pen end
  return 0
end

function get_adjusted_armour_pen(encumb, str)
  -- dcss v0.33.1
  local base_pen = get_unadjusted_armour_pen(encumb)
  return 2 * base_pen * base_pen * (45 - you.skill("Armour")) / 45 / (5 * (str + 3))
end

function get_adjusted_dodge_bonus(encumb, str, dex)
  -- dcss v0.33.1
  local size_factor = -2 * get_size_penalty()
  local dodge_bonus = 8 * (10 + you.skill("Dodging") * dex) / (20 - size_factor) / 10
  local armour_dodge_penalty = get_unadjusted_armour_pen(encumb) - 3
  if armour_dodge_penalty <= 0 then return dodge_bonus end

  if armour_dodge_penalty >= str then return dodge_bonus * str / (armour_dodge_penalty * 2) end
  return dodge_bonus - dodge_bonus * armour_dodge_penalty / (str * 2)
end

function get_armour_ac(it)
  -- dcss v0.33.1
  local it_plus = it.plus or 0

  if it.artefact and it.is_identified then
    local art_ac = it.artprops["AC"]
    if art_ac then it_plus = it_plus + art_ac end
  end

  local ac = it.ac * (1 + you.skill("Armour") / 22) + it_plus
  if not BRC.is.body_armour(it) then return ac end

  local deformed = BRC.get.mut(BRC.MUTATIONS.deformed, true) > 0
  local pseudopods = BRC.get.mut(BRC.MUTATIONS.pseudopods, true) > 0
  if pseudopods or deformed then return ac * 6 / 10 end

  return ac
end

function get_armour_ev(it)
  -- dcss v0.33.1
  -- This function computes the armour-based component to standard EV (not paralysed, etc)
  -- Factors in stat changes from this armour and removing current one
  local str = you.strength()
  local dex = you.dexterity()
  local no_art_str = str
  local no_art_dex = dex
  local art_ev = 0

  -- Adjust str/dex/EV for artefact stat changes
  local worn = items.equipped_at("armour")
  if worn and worn.artefact then
    if worn.artprops["Str"] then str = str - worn.artprops["Str"] end
    if worn.artprops["Dex"] then dex = dex - worn.artprops["Dex"] end
    if worn.artprops["EV"] then art_ev = art_ev - worn.artprops["EV"] end
  end

  if it.artefact then
    if it.artprops["Str"] then str = str + it.artprops["Str"] end
    if it.artprops["Dex"] then dex = dex + it.artprops["Dex"] end
    if it.artprops["EV"] then art_ev = art_ev + it.artprops["EV"] end
  end

  if str <= 0 then str = 1 end

  local dodge_bonus = get_adjusted_dodge_bonus(it.encumbrance, str, dex)
  local naked_dodge_bonus = get_adjusted_dodge_bonus(0, no_art_str, no_art_dex)
  return (dodge_bonus - naked_dodge_bonus) + art_ev - get_adjusted_armour_pen(it.encumbrance, str)
end

function get_shield_penalty(sh)
  -- dcss v0.33.1
  return 2 * sh.encumbrance * sh.encumbrance * (27 - you.skill("Shields")) / 27 / (25 + 5 * you.strength())
end

function get_shield_sh(it)
  -- dcss v0.33.1
  local dex = you.dexterity()
  if it.artefact and it.is_identified then
    local art_dex = it.artprops["Dex"]
    if art_dex then dex = dex + art_dex end
  end

  local cur = items.equipped_at("offhand")
  if BRC.is.shield(cur) and cur.artefact and cur.slot ~= it.slot then
    local art_dex = cur.artprops["Dex"]
    if art_dex then dex = dex - art_dex end
  end

  local it_plus = it.plus or 0

  local base_sh = it.ac * 2
  local shield = base_sh * (50 + you.skill("Shields") * 5 / 2)
  shield = shield + 200 * it_plus
  shield = shield + 38 * (you.skill("Shields") + 3 + dex * (base_sh + 13) / 26)
  return shield / 200
end

function get_size_penalty()
  if util.contains(BRC.ALL_LITTLE_RACES, you.race()) then
    return BRC.SIZE_PENALTY.LITTLE
  elseif util.contains(BRC.ALL_SMALL_RACES, you.race()) then
    return BRC.SIZE_PENALTY.SMALL
  elseif util.contains(BRC.ALL_LARGE_RACES, you.race()) then
    return BRC.SIZE_PENALTY.LARGE
  end
  return BRC.SIZE_PENALTY.NORMAL
end

--------- Weapon stats (Shadowing crawl calcs) ---------
function adjust_delay_for_ego(delay, ego)
  if not ego then return delay end
  if ego == "speed" then
    return delay * 2 / 3
  elseif ego == "heavy" then
    return delay * 1.5
  end
  return delay
end

function get_weap_delay(it)
  -- dcss v0.33.1
  local delay = it.delay - get_skill(it.weap_skill) / 2
  delay = math.max(delay, get_weap_min_delay(it))
  delay = adjust_delay_for_ego(delay, get_ego(it))
  delay = math.max(delay, 3)

  local sh = items.equipped_at("offhand")
  if BRC.is.shield(sh) then delay = delay + get_shield_penalty(sh) end

  if it.is_ranged then
    local worn = items.equipped_at("armour")
    if worn then
      local str = you.strength()

      local cur = items.equipped_at("weapon")
      if cur and cur ~= it and cur.artefact then
        if it.artefact and it.artprops["Str"] then str = str + it.artprops["Str"] end
        if cur.artefact and cur.artprops["Str"] then str = str - cur.artprops["Str"] end
      end

      delay = delay + get_adjusted_armour_pen(worn.encumbrance, str)
    end
  end

  return delay / 10
end

function get_weap_min_delay(it)
  -- dcss v0.33.1
  -- This is an abbreviated version of the actual calculation.
  -- Skips brand and >=3 checks, which are covered in get_weap_delay()
  if it.artefact and it.name("qual"):find("woodcutter's axe", 1, true) then return it.delay end

  local min_delay = math.floor(it.delay / 2)
  if it.weap_skill == "Short Blades" then return 5 end
  if it.is_ranged then
    local basename = it.name("base")
    local is_2h_ranged = basename:find("crossbow", 1, true) or basename:find("arbalest", 1, true)
    if is_2h_ranged then return math.max(min_delay, 10) end
  end

  return math.min(min_delay, 7)
end

function get_weap_dps(it, dmg_type)
  if not dmg_type then dmg_type = BRC.DMG_TYPE.scoring end
  return get_weap_damage(it, dmg_type) / get_weap_delay(it)
end

function get_weap_damage(it, dmg_type)
  -- Returns an adjusted weapon damage = damage * speed
  -- Includes stat/slay changes between weapon and the one currently wielded
  -- Aux attacks not included
  if not dmg_type then dmg_type = BRC.DMG_TYPE.scoring end
  local it_plus = it.plus or 0
  -- Adjust str/dex/slay from artefacts
  local str = you.strength()
  local dex = you.dexterity()

  -- Adjust str/dex/EV for artefact stat changes
  if not it.equipped then
    local wielded = items.equipped_at("weapon")
    if wielded and wielded.artefact then
      if wielded.artprops["Str"] then str = str - wielded.artprops["Str"] end
      if wielded.artprops["Dex"] then dex = dex - wielded.artprops["Dex"] end
      if wielded.artprops["Slay"] then it_plus = it_plus - wielded.artprops["Slay"] end
    end

    if it.artefact and it.is_identified then
      if it.artprops["Str"] then str = str + it.artprops["Str"] end
      if it.artprops["Dex"] then dex = dex + it.artprops["Dex"] end
      if it.artprops["Slay"] then it_plus = it_plus + it.artprops["Slay"] end
    end
  end

  local stat = str
  if it.is_ranged or it.weap_skill:find("Blades", 1, true) then stat = dex end

  local stat_mod = 0.75 + 0.025 * stat
  local skill_mod = (1 + get_skill(it.weap_skill) / 25 / 2) * (1 + you.skill("Fighting") / 30 / 2)

  it_plus = it_plus + get_slay_bonuses()

  local pre_brand_dmg_no_plus = it.damage * stat_mod * skill_mod
  local pre_brand_dmg = pre_brand_dmg_no_plus + it_plus

  if BRC.is.magic_staff(it) then return (pre_brand_dmg + get_staff_bonus_dmg(it, dmg_type)) end

  if dmg_type == BRC.DMG_TYPE.plain then
    local ego = get_ego(it)
    if ego and util.contains(BRC.PLAIN_DMG_EGOS, ego) then
      local bonus = BRC.BrandBonus[ego] or BRC.BrandBonus.subtle[ego]
      return bonus.factor * pre_brand_dmg_no_plus + it_plus + bonus.offset
    end
  elseif dmg_type >= BRC.DMG_TYPE.branded then
    local ego = get_ego(it)
    if ego then
      local bonus = BRC.BrandBonus[ego]
      if not bonus and dmg_type == BRC.DMG_TYPE.scoring then bonus = BRC.BrandBonus.subtle[ego] end
      if bonus then return bonus.factor * pre_brand_dmg_no_plus + it_plus + bonus.offset end
    end
  end

  return pre_brand_dmg
end

function get_weap_score(it, no_brand_bonus)
  if it.dps and it.acc then
    -- Handle cached /  high-score tuples in WEAP_CACHE
    return it.dps + it.acc * BRC.Tuning.weap.pickup.accuracy_weight
  end
  local it_plus = it.plus or 0
  local dmg_type = no_brand_bonus and BRC.DMG_TYPE.unbranded or BRC.DMG_TYPE.scoring
  return get_weap_dps(it, dmg_type) + (it.accuracy + it_plus) * BRC.Tuning.weap.pickup.accuracy_weight
end

--------- Weap stat helpers ---------
function get_hands(it)
  if you.race() ~= "Formicid" then return it.hands end
  local st = it.subtype()
  if st == "giant club" or st == "giant spiked club" then return 2 end
  return 1
end

-- Get skill level, or average for artefacts w/ multiple skills
function get_skill(skill)
  if not skill:find(",", 1, true) then return you.skill(skill) end

  local skills = crawl.split(skill, ",")
  local sum = 0
  local count = 0
  for _, s in ipairs(skills) do
    sum = sum + you.skill(s)
    count = count + 1
  end
  return sum / count
end

-- Count all slay bonuses from weapons/armour/jewellery
function get_slay_bonuses()
  local sum = 0

  -- Slots can go as high as 18 afaict
  for i = 0, 20 do
    local it = items.equipped_at(i)
    if it then
      if BRC.is.ring(it) then
        if it.artefact then
          local name = it.name()
          local idx = name:find("Slay", 1, true)
          if idx then
            local slay = tonumber(name:sub(idx + 5, idx + 5))
            if slay == 1 then
              local next_digit = tonumber(name:sub(idx + 6, idx + 6))
              if next_digit then slay = 10 + next_digit end
            end

            if name:sub(idx + 4, idx + 4) == "+" then
              sum = sum + slay
            else
              sum = sum - slay
            end
          end
        elseif get_ego(it) == "Slay" then
          sum = sum + it.plus
        end
      elseif it.artefact and (BRC.is.armour(it, true) or BRC.is.amulet(it)) then
        local slay = it.artprops["Slay"]
        if slay then sum = sum + slay end
      end
    end
  end

  if you.race() == "Demonspawn" then
    sum = sum + 3 * BRC.get.mut(BRC.MUTATIONS.augmentation, true)
    sum = sum + BRC.get.mut(BRC.MUTATIONS.sharp_scales, true)
  end

  return sum
end

function get_staff_bonus_dmg(it, dmg_type)
  -- dcss v0.33.1
  if dmg_type == BRC.DMG_TYPE.unbranded then return 0 end
  if dmg_type == BRC.DMG_TYPE.plain then
    local basename = it.name("base")
    if basename ~= "staff of earth" and basename ~= "staff of conjuration" then return 0 end
  end

  local spell_skill = get_skill(BRC.get.staff_school(it))
  local evo_skill = you.skill("Evocations")

  local chance = (2 * evo_skill + spell_skill) / 30
  if chance > 1 then chance = 1 end
  -- 0.75 is an acceptable approximation; most commonly 63/80
  -- Varies by staff type in sometimes complex ways
  local avg_dmg = 3 / 4 * (evo_skill / 2 + spell_skill)
  return avg_dmg * chance
end
