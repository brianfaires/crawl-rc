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
-- Last verified against: current crawl master branch (0.34-a0-786-ge5b59a6c5f)

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


--- Gets the updated stats after equipping an item
-- @param stats (table) Keys are artefact properties, values are the current values
-- If multiple equip slots available, assumes no item is removed.
-- @return (table) New stats table with updated values (original table is not modified)
local function get_stats_with_item(it, stats)
  local new_stats = util.copy_table(stats)
  local cur = items.equipped_at(it.equip_type)
  if not cur or it.equipped then return new_stats end

  if cur.artefact and BRC.you.num_eq_slots(it) == 1 then
    for k, _ in pairs(new_stats) do
      new_stats[k] = new_stats[k] - (cur.artprops[k] or 0)
    end
  end

  if it.artefact then
    for k, _ in pairs(new_stats) do
      new_stats[k] = new_stats[k] + (it.artprops[k] or 0)
    end
  end

  return new_stats
end

--- Get change in SH and EV when switching to shield
local function get_delta_sh_ev(it)
  local it_sh = BRC.eq.get_sh(it)
  local it_ev = -get_shield_penalty(it)
  local cur = items.equipped_at(it.equip_type)
  if not cur or it.equipped then
    return it_sh, it_ev
  else
    return it_sh - BRC.eq.get_sh(cur), it_ev + get_shield_penalty(cur)
  end
end

--- Get change in AC and EV when switching to armour
local function get_delta_ac_ev(it)
  local it_ac = BRC.eq.get_ac(it)
  local it_ev = BRC.eq.get_armour_ev(it)
  local cur = items.equipped_at(it.equip_type)
  if not cur or it.equipped or BRC.you.num_eq_slots(it) > 1 then
    return it_ac, it_ev
  else
    return it_ac - BRC.eq.get_ac(cur), it_ev - BRC.eq.get_armour_ev(cur)
  end
end

--- Calculate weapon damage using the brand bonuses in BRC.Config.BrandBonus
-- @param dmg_type int Matches a damage type defined in BRC.DMG_TYPE:
--   (1) unbranded: Only "heavy" is included
--   (2) plain: Include non-elemental damaging brands
--   (3) branded: Include all damaging brands
--   (4) scoring: Include heuristics from 'subtle' brands
local function get_dmg_with_brand_bonus(ego, base_dmg, it_plus, dmg_type)
  if not ego then return base_dmg + it_plus end

  -- Check if brand should apply based on damage type
  local should_apply = (
    dmg_type == BRC.DMG_TYPE.unbranded and ego == "heavy"
    or dmg_type == BRC.DMG_TYPE.plain and util.contains(BRC.NON_ELEMENTAL_DMG_EGOS, ego)
    or dmg_type >= BRC.DMG_TYPE.branded and BRC.Config.BrandBonus[ego]
    or dmg_type == BRC.DMG_TYPE.scoring and BRC.Config.BrandBonus.subtle[ego]
  )

  if should_apply then
    local bonus = BRC.Config.BrandBonus[ego] or BRC.Config.BrandBonus.subtle[ego]
    return bonus.factor * base_dmg + it_plus + bonus.offset
  else
    return base_dmg + it_plus
  end
end

---- Stat formatting functions ----
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

--- Get armour stats as strings
-- @return (string, string) AC or SH, and EV.  If not worn, returns deltas from the worn item stats
function BRC.eq.arm_stats(it)
  if not BRC.it.is_armour(it) then return "", "" end

  if BRC.it.is_shield(it) then
    local sh_delta, ev_delta = get_delta_sh_ev(it)
    local sh_str = format_stat("SH", sh_delta, it.equipped)
    local ev_str = format_stat("EV", ev_delta, it.equipped)
    return sh_str, ev_str
  else
    local ac_delta, ev_delta = get_delta_ac_ev(it)
    local ac_str = format_stat("AC", ac_delta, it.equipped)
    if not BRC.it.is_body_armour(it) then return ac_str end
    local ev_str = format_stat("EV", ev_delta, it.equipped)
    return ac_str, ev_str
  end
end

--- Get weapon stats as a string
-- @return (string) DPS, damage, delay, and accuracy
function BRC.eq.wpn_stats(it, dmg_type)
  if not it.is_weapon then return end
  if not dmg_type then
    -- Default to pulling from inscribe-stats config, if it exists. Else use plain.
    if f_inscribe_stats and f_inscribe_stats.Config then
      if type(f_inscribe_stats.Config.dmg_type) == "string" then
        dmg_type = BRC.DMG_TYPE[f_inscribe_stats.Config.dmg_type]
      else
        dmg_type = f_inscribe_stats.Config.dmg_type
      end
    else
      dmg_type = BRC.DMG_TYPE.plain
    end
  end

  local dmg = format_dmg(BRC.eq.get_avg_dmg(it, dmg_type))
  local delay = BRC.eq.get_weap_delay(it)
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

  if it.artefact then
    local art_ac = it.artprops["AC"]
    if art_ac then it_plus = it_plus + art_ac end
  end

  local ac = it.ac * (1 + you.skill("Armour") / 22) + it_plus
  if not BRC.it.is_body_armour(it) then return ac end

  if BRC.you.mut_lvl("deformed body") + BRC.you.mut_lvl("pseudopods") > 0 then ac = ac * 0.6 end

  return ac
end

--- Compute an armour's impact on EV, including stat changes from wearing/removing artefacts
function BRC.eq.get_armour_ev(it)
  local cur = { Str = you.strength(), Dex = you.dexterity(), EV = 0 }
  local worn = get_stats_with_item(it, cur)

  if worn.Str <= 0 then worn.Str = 1 end
  local bonus = get_adjusted_dodge_bonus(it.encumbrance, worn.Str, worn.Dex)

  if cur.Str <= 0 then cur.Str = 1 end
  local naked_bonus = get_adjusted_dodge_bonus(0, cur.Str, cur.Dex)

  return bonus - naked_bonus + worn.EV - get_adjusted_armour_pen(it.encumbrance, worn.Str)
end

function BRC.eq.get_sh(it)
  local stats = get_stats_with_item(it, { Dex = you.dexterity() })
  local it_plus = it.plus or 0
  local sh_skill = you.skill("Shields")

  local base_sh = it.ac * 2
  local shield = base_sh * (50 + sh_skill * 5 / 2)
  shield = shield + 200 * it_plus
  shield = shield + 38 * (sh_skill + 3 + stats.Dex * (base_sh + 13) / 26)
  return shield / 200
end


---- Weapon stats ----
function BRC.eq.get_weap_delay(it)
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
--- Get weapon damage (average), including stat/slay changes when swapping from current weapon.
-- Aux attacks not included
function BRC.eq.get_avg_dmg(it, dmg_type)
  dmg_type = dmg_type or BRC.DMG_TYPE.scoring

  local it_plus = (it.plus or 0) + get_slay_bonuses()
  local stats = { Str = you.strength(), Dex = you.dexterity(), Slay = it_plus }
  stats = get_stats_with_item(it, stats)

  local stat = (it.is_ranged or it.weap_skill:contains("Blades")) and stats.Dex or stats.Str
  local stat_mod = 0.75 + 0.025 * stat
  local skill_mod = (1 + BRC.you.skill(it.weap_skill) / 50) * (1 + you.skill("Fighting") / 60)
  local base_dmg = it.damage * stat_mod * skill_mod

  if BRC.it.is_magic_staff(it) then
    return base_dmg + stats.Slay + get_staff_bonus_dmg(it, dmg_type)
  else
    return get_dmg_with_brand_bonus(BRC.eq.get_ego(it), base_dmg, stats.Slay, dmg_type)
  end
end

function BRC.eq.get_dps(it, dmg_type)
  if not dmg_type then dmg_type = BRC.DMG_TYPE.scoring end
  return BRC.eq.get_avg_dmg(it, dmg_type) / BRC.eq.get_weap_delay(it)
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
