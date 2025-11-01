---------------------------------------------------------------------------------------------------
-- BRC utility module
-- @module BRC.eq
-- This module contains 2 main types of functions:
--   1. Mirroring crawl calculations, like weapon damage, armour penalty, etc.
--   2. Design choices that aren't as generalizable as other util functions.
--     Ex: Dragon scales are always considered branded, DPS calculation is an approximation, etc.
--     Ex: is_risky(), is_useless_ego(), get_ego(), get_hands(), etc.
---------------------------------------------------------------------------------------------------

BRC.eq = {}

---- Local functions (Mostly mirroring crawl calculations) ----
-- Last verified against: dcss v0.33.1

local function get_unadjusted_armour_pen(encumb)
  local pen = encumb - 2 * BRC.you.mut_lvl("sturdy frame")
  if pen > 0 then return pen end
  return 0
end

local function get_adjusted_armour_pen(encumb, str)
  local base_pen = get_unadjusted_armour_pen(encumb)
  return 2 * base_pen * base_pen * (45 - you.skill("Armour")) / 45 / (5 * (str + 3))
end

local function get_adjusted_dodge_bonus(encumb, str, dex)
  local size_factor = -2 * BRC.you.size_penalty()
  local dodge_bonus = 8 * (10 + you.skill("Dodging") * dex) / (20 - size_factor) / 10
  local armour_dodge_penalty = get_unadjusted_armour_pen(encumb) - 3
  if armour_dodge_penalty <= 0 then return dodge_bonus end

  if armour_dodge_penalty >= str then return dodge_bonus * str / (armour_dodge_penalty * 2) end
  return dodge_bonus - dodge_bonus * armour_dodge_penalty / (str * 2)
end

local function get_shield_penalty(sh)
  return 2 * sh.encumbrance * sh.encumbrance
    * (27 - you.skill("Shields")) / 27
    / (25 + 5 * you.strength())
end

local function get_branded_delay(delay, ego)
  if not ego then return delay end
  if ego == "speed" then
    return delay * 2 / 3
  elseif ego == "heavy" then
    return delay * 1.5
  end
  return delay
end

local function get_weap_min_delay(it)
  -- This is an abbreviated version of the actual calculation.
  -- Doesn't check brand or delay >=3, which are covered in get_weap_delay()
  if it.artefact and it.name("qual"):contains("woodcutter's axe") then return it.delay end

  local min_delay = math.floor(it.delay / 2)
  if it.weap_skill == "Short Blades" then return 5 end
  if it.is_ranged then
    local basename = it.name("base")
    local is_2h_ranged = basename:contains("crossbow") or basename:contains("arbalest")
    if is_2h_ranged then return math.max(min_delay, 10) end
  end

  return math.min(min_delay, 7)
end

local function get_weap_delay(it)
  local delay = it.delay - BRC.you.skill(it.weap_skill) / 2
  delay = math.max(delay, get_weap_min_delay(it))
  delay = get_branded_delay(delay, BRC.eq.get_ego(it))
  delay = math.max(delay, 3)

  local sh = items.equipped_at("offhand")
  if BRC.it.is_shield(sh) then delay = delay + get_shield_penalty(sh) end

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

local function get_slay_bonuses()
  local sum = 0

  -- Slots can go as high as 18 afaict
  for i = 0, 20 do
    local inv = items.equipped_at(i)
    if inv then
      if BRC.it.is_ring(inv) then
        if inv.artefact then
          local name = inv.name()
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
        elseif BRC.eq.get_ego(inv) == "Slay" then
          sum = sum + inv.plus
        end
      elseif inv.artefact and (BRC.it.is_armour(inv, true) or BRC.it.is_amulet(inv)) then
        local slay = inv.artprops["Slay"]
        if slay then sum = sum + slay end
      end
    end
  end

  if you.race() == "Demonspawn" then
    sum = sum + 3 * BRC.you.mut_lvl("augmentation")
    sum = sum + BRC.you.mut_lvl("sharp scales")
  end

  return sum
end

local function get_staff_bonus_dmg(it, dmg_type)
  if dmg_type == BRC.DMG_TYPE.unbranded then return 0 end
  if dmg_type == BRC.DMG_TYPE.plain then
    local basename = it.name("base")
    if basename ~= "staff of earth" and basename ~= "staff of conjuration" then return 0 end
  end

  local spell_skill = BRC.you.skill(BRC.it.get_staff_school(it))
  local evo_skill = you.skill("Evocations")

  local chance = (2 * evo_skill + spell_skill) / 30
  if chance > 1 then chance = 1 end
  -- 0.75 is an acceptable approximation; most commonly 63/80
  -- Varies by staff type in sometimes complex ways
  local avg_dmg = 3 / 4 * (evo_skill / 2 + spell_skill)
  return avg_dmg * chance
end


---- Formatting stats for alerts & inscriptions ----
--- Format damage values for consistent display width (4 characters)
local function format_dmg(dmg)
  if dmg < 10 then return string.format("%.2f", dmg) end
  if dmg > 99.9 then return ">100" end
  return string.format("%.1f", dmg)
end

--- Format stat string for display or inscription
local function format_stat(abbr, val, is_worn)
  local stat_str = string.format("%.1f", val)
  if val < 0 then
    return string.format("%s%s", abbr, stat_str)
  elseif is_worn then
    return string.format("%s:%s", abbr, stat_str)
  else
    return string.format("%s+%s", abbr, stat_str)
  end
end

--- Get the armour stats as strings
-- @return (string, string) AC or SH, and EV.  If not worn, returns deltas from the worn item stats
function BRC.eq.arm_stats(it)
  if not BRC.it.is_armour(it) then return "", "" end

  local equip_type = it.equip_type
  if equip_type == "body armour" then equip_type = "armour" end
  local cur = items.equipped_at(equip_type)
  local is_worn = it.equipped or (it.ininventory and cur and cur.slot == it.slot)
  local cur_ac = 0
  local cur_sh = 0
  local cur_ev = 0

  -- Show as delta if wearing a different item (and only one equip slot)
  if cur and not is_worn and BRC.you.num_eq_slots(it) == 1 then
    if BRC.it.is_shield(cur) then
      cur_sh = BRC.eq.get_sh(cur)
      cur_ev = -get_shield_penalty(cur)
    else
      cur_ac = BRC.eq.get_ac(cur)
      cur_ev = BRC.eq.get_ev(cur)
    end
  end

  if BRC.it.is_shield(it) then
    local sh_str = format_stat("SH", BRC.eq.get_sh(it) - cur_sh, is_worn)
    local ev_str = format_stat("EV", -get_shield_penalty(it) - cur_ev, is_worn)
    return sh_str, ev_str
  else
    local ac_str = format_stat("AC", BRC.eq.get_ac(it) - cur_ac, is_worn)
    if not BRC.it.is_body_armour(it) then return ac_str end
    local ev_str = format_stat("EV", BRC.eq.get_ev(it) - cur_ev, is_worn)
    return ac_str, ev_str
  end
end

--- Get the weapon stats as a string
-- @return (string) DPS, damage, delay, and accuracy
function BRC.eq.wpn_stats(it, dmg_type)
  if not it.is_weapon then return end
  if not dmg_type then
    if f_inscribe_stats and f_inscribe_stats.Config and f_inscribe_stats.Config.dmg_type then
      dmg_type = BRC.DMG_TYPE[f_inscribe_stats.Config.dmg_type]
    else
      dmg_type = BRC.DMG_TYPE.plain
    end
  end

  local dmg = format_dmg(BRC.eq.get_dmg(it, dmg_type))
  local delay = get_weap_delay(it)
  local delay_str = string.format("%.1f", delay)
  if delay < 1 then
    delay_str = string.format("%.2f", delay)
    delay_str = delay_str:sub(2, #delay_str)
  end

  local dps = format_dmg(dmg / delay)
  local acc = it.accuracy + (it.plus or 0)
  if acc >= 0 then acc = "+" .. acc end

  --TODO: This would be nice if it worked in all UIs
  --return string.format("DPS:<w>%s</w> (%s/%s), Acc<w>%s</w>", dps, dmg, delay_str, acc)
  return string.format("DPS: %s (%s/%s), Acc%s", dps, dmg, delay_str, acc)
end


---- Armour stats ----
function BRC.eq.get_ac(it)
  local it_plus = it.plus or 0

  if it.artefact and it.is_identified then
    local art_ac = it.artprops["AC"]
    if art_ac then it_plus = it_plus + art_ac end
  end

  local ac = it.ac * (1 + you.skill("Armour") / 22) + it_plus
  if not BRC.it.is_body_armour(it) then return ac end

  if BRC.you.mut_lvl("deformed body") + BRC.you.mut_lvl("pseudopods") > 0 then ac = ac * 0.6 end

  return ac
end

function BRC.eq.get_ev(it)
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

function BRC.eq.get_sh(it)
  local dex = you.dexterity()
  if it.artefact and it.is_identified then
    local art_dex = it.artprops["Dex"]
    if art_dex then dex = dex + art_dex end
  end

  local cur = items.equipped_at("offhand")
  if BRC.it.is_shield(cur) and cur.artefact and cur.slot ~= it.slot then
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


---- Weapon stats ----
function BRC.eq.get_dps(it, dmg_type)
  if not dmg_type then dmg_type = BRC.DMG_TYPE.scoring end
  return BRC.eq.get_dmg(it, dmg_type) / get_weap_delay(it)
end

function BRC.eq.get_dmg(it, dmg_type)
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
  if it.is_ranged or it.weap_skill:contains("Blades") then stat = dex end

  local stat_mod = 0.75 + 0.025 * stat
  local skill_mod = (1 + BRC.you.skill(it.weap_skill) / 50) * (1 + you.skill("Fighting") / 60)

  it_plus = it_plus + get_slay_bonuses()

  local pre_brand_dmg_no_plus = it.damage * stat_mod * skill_mod
  local pre_brand_dmg = pre_brand_dmg_no_plus + it_plus

  if BRC.it.is_magic_staff(it) then return pre_brand_dmg + get_staff_bonus_dmg(it, dmg_type) end

  local ego = BRC.eq.get_ego(it)
  if ego and (
      dmg_type == BRC.DMG_TYPE.unbranded and ego == "heavy"
      or dmg_type == BRC.DMG_TYPE.plain and util.contains(BRC.NON_ELEMENTAL_DMG_EGOS, ego)
      or dmg_type >= BRC.DMG_TYPE.branded and BRC.Config.BrandBonus[ego]
      or dmg_type == BRC.DMG_TYPE.scoring and BRC.Config.BrandBonus.subtle[ego]
    )
  then
    local bonus = BRC.Config.BrandBonus[ego] or BRC.Config.BrandBonus.subtle[ego]
    return bonus.factor * pre_brand_dmg_no_plus + it_plus + bonus.offset
  end

  return pre_brand_dmg
end


---- Item properties ----
--- Get the ego of an item, with custom logic:
-- Treat unusable egos as no ego. Always lowercase ego in return value.
-- Include armours with innate effects (except steam dragon scales)
-- Artefacts return their normal ego if they have one, else their name
-- @param no_stat_only_egos (optional bool) Exclude egos that only affect speed/damage
function BRC.eq.get_ego(it, no_stat_only_egos)
  local ego = it.ego(true)
  if ego then
    ego = ego:lower()
    if BRC.eq.is_useless_ego(ego) or (no_stat_only_egos and (ego == "speed" or ego == "heavy")) then
      return it.artefact and it.name() or nil
    end
    return ego
  end

  if BRC.it.is_body_armour(it) then
    local name = it.name("qual")
    local good_scales = name:contains("dragon scales") and not name:contains("steam")
    if name:contains("troll leather") or good_scales then return name end
  end

  return it.artefact and it.name() or nil
end

function BRC.eq.get_hands(it)
  if you.race() ~= "Formicid" then return it.hands end
  local st = it.subtype()
  if st == "giant club" or st == "giant spiked club" then return 2 end
  return 1
end

function BRC.eq.is_risky(it)
  if it.artefact then
    for k, v in pairs(it.artprops) do
      if util.contains(BRC.ARTPROPS_BAD, k) or v < 0 then return true end
    end
  end

  local ego_name = BRC.eq.get_ego(it)
  return ego_name and util.contains(BRC.RISKY_EGOS, ego_name)
end

function BRC.eq.is_useless_ego(ego)
  if BRC.MAGIC_SCHOOLS[ego] then
    return BRC.Config.unskilled_egos_usable or you.skill(BRC.MAGIC_SCHOOLS[ego]) > 0
  end

  local race = you.race()
  return ego == "holy" and util.contains(BRC.UNDEAD_RACES, race)
    or ego == "rPois" and util.contains(BRC.POIS_RES_RACES, race)
    or ego == "pain" and you.skill("Necromancy") == 0
end
