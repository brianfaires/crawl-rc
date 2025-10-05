--[[
Feature: pickup-alert-weapons
Description: Weapon pickup logic, caching, and alert system for the pickup-alert system
Author: buehler
Dependencies: core/constants.lua, core/data.lua, core/util.lua, pa-data.lua, pa-main.lua
--]]

f_pa_weapons = {}

-- Persistent variables
lowest_num_hands_alerted = BRC.data.persist("lowest_num_hands_alerted", {
  ["Ranged Weapons"] = 3, -- Start with 3 (to fire both 1 and 2-handed alerts)
  ["Polearms"] = 3, -- Start with 3 (to fire both 1 and 2-handed alerts)
}) -- lowest_num_hands_alerted (do not remove this comment)

-- Local config
local Config = f_pickup_alert.Config
local Tuning = f_pickup_alert.Config.Tuning
local Emoji = f_pickup_alert.Config.Emoji

-- Local constants
local FIRST_WEAPON_XL_CUTOFF = 4 -- Stop looking for first weapon after this XL
local RANGED_XL_THRESHOLD = 3 -- At this skill level, don't bother alerting for polearms
local UPGRADE_SKILL_FACTOR = 0.5 -- Don't alert for upgrades if weap skill is this much worse
local RANGED = "range_"
local MELEE = "melee_"

-- Local variables
local top_attack_skill

-- Core logic: How weapon scores are calculated
local function get_score(it, no_brand_bonus)
  if it.dps and it.acc then
    -- Handle cached /  high-score tuples in _weapon_cache
    return it.dps + it.acc * Tuning.weap.pickup.accuracy_weight
  end
  local it_plus = it.plus or 0
  local dmg_type = no_brand_bonus and BRC.DMG_TYPE.unbranded or BRC.DMG_TYPE.scoring
  return BRC.get.weap_dps(it, dmg_type) + (it.accuracy + it_plus) * Tuning.weap.pickup.accuracy_weight
end

-- _weapon_cache: Cache weapons in inventory each turn, so we don't recompute DPS on every autopickup call
_weapon_cache = {}

function _weapon_cache.get_primary_key(it)
  local tokens = {}
  tokens[1] = it.is_ranged and RANGED or MELEE
  tokens[2] = tostring(it.hands)
  if BRC.get.ego(it) then tokens[3] = "b" end
  return table.concat(tokens)
end

-- Get all categories this weapon fits into (both its real category and any more-restrictive categories)
function _weapon_cache.get_keys(is_ranged, hands, is_branded)
  local ranged_types = is_ranged and { RANGED, MELEE } or { MELEE }
  local handed_types = hands == 1 and { "1", "2" } or { "2" }
  local branded_types = is_branded and { "b", "" } or { "" }

  -- Generate all combinations
  local keys = {}
  for _, r in ipairs(ranged_types) do
    for _, h in ipairs(handed_types) do
      for _, b in ipairs(branded_types) do
        keys[#keys + 1] = table.concat({ r, h, b })
      end
    end
  end

  return keys
end

function _weapon_cache.add_weapon(it)
  local weap_data = {}
  weap_data.is_weapon = it.is_weapon
  weap_data.basename = it.name("base")
  weap_data._subtype = it.subtype()
  weap_data.subtype = function() return weap_data._subtype end -- For consistency with crawl.item.subtype()
  weap_data.weap_skill = it.weap_skill
  weap_data.skill_lvl = BRC.get.skill(it.weap_skill)
  weap_data.is_ranged = it.is_ranged
  weap_data.hands = BRC.get.hands(it)
  weap_data.artefact = it.artefact
  weap_data._ego = BRC.get.ego(it)
  weap_data.ego = function() return weap_data._ego end -- For consistency with crawl.item.ego()
  weap_data.plus = it.plus or 0
  weap_data.acc = it.accuracy + weap_data.plus
  weap_data.damage = it.damage
  weap_data.dps = BRC.get.weap_dps(it)
  weap_data.score = get_score(it)
  weap_data.unbranded_score = get_score(it, true)

  -- Check for exclusion tags
  local lower_insc = it.inscription:lower()
  weap_data.allow_upgrade = not (lower_insc:contains("!u") or lower_insc:contains("!brc"))

  -- Track unique egos
  if weap_data._ego and not util.contains(_weapon_cache.egos, weap_data._ego) then
    _weapon_cache.egos[#_weapon_cache.egos + 1] = weap_data._ego
  end

  -- Track max damage for applicable weapon categories
  local keys = _weapon_cache.get_keys(weap_data.is_ranged, weap_data.hands, weap_data._ego ~= nil)

  -- Update the max DPS for each category
  for _, key in ipairs(keys) do
    if weap_data.dps > _weapon_cache.max_dps[key].dps then
      _weapon_cache.max_dps[key].dps = weap_data.dps
      _weapon_cache.max_dps[key].acc = weap_data.acc
    end
  end

  _weapon_cache.weapons[#_weapon_cache.weapons + 1] = weap_data
  return weap_data
end

function _weapon_cache.is_empty()
  return _weapon_cache.max_dps["melee_2"].dps == 0 -- The most restrictive category
end

function _weapon_cache.serialize()
  local tokens = { "\n---INVENTORY WEAPONS---" }
  for _, weap in ipairs(_weapon_cache.weapons) do
    tokens[#tokens + 1] = string.format("\n%s\n", weap.basename)
    for k, v in pairs(weap) do
      if k ~= "basename" then tokens[#tokens + 1] = string.format("  %s: %s\n", k, tostring(v)) end
    end
  end
  return table.concat(tokens)
end

-- Local functions
local function is_valid_upgrade(it, cur)
  return
    cur.is_ranged == it.is_ranged
    and BRC.is.polearm(cur) == BRC.is.polearm(it)
    and (you.race() == "Gnoll" or BRC.get.skill(it.weap_skill) >= UPGRADE_SKILL_FACTOR * BRC.get.skill(cur.weap_skill))
end

-- is_weapon_upgrade() -> boolean: compares floor weapon to one in inventory
-- `cur` comes from _weapon_cache - it has some pre-computed values
local function is_weapon_upgrade(it, cur, strict)
  if not cur.allow_upgrade then return false end
  if strict then
    -- Pure upgrades only
    if cur.artefact or it.subtype() ~= cur.subtype() then return false end
    if it.artefact then return true end
    local it_plus = it.plus or 0
    local cur_ego = BRC.get.ego(cur)
    if BRC.get.ego(it) == cur_ego then return it_plus > cur.plus end
    return not cur_ego and it_plus >= cur.plus
  end

  -- Check if it's a very likely upgrade
  if it.subtype() == cur.subtype() then
    if it.artefact then return true end
    if cur.artefact then return false end

    local it_ego = BRC.get.ego(it)
    local cur_ego = BRC.get.ego(cur)
    if cur_ego and not it_ego then return false end
    if it_ego and not cur_ego then return get_score(it) / cur.score > Tuning.weap.pickup.add_ego end
    return it_ego == cur_ego and (it.plus or 0) > cur.plus
  elseif it.weap_skill == cur.weap_skill or you.race() == "Gnoll" then
    if BRC.get.hands(it) > cur.hands then return false end
    if cur.is_ranged ~= it.is_ranged then return false end
    if BRC.is.polearm(cur) ~= BRC.is.polearm(it) then return false end

    if it.artefact then return true end
    if cur.artefact then return false end

    local min_ratio = it.is_ranged and Tuning.weap.pickup.same_type_ranged or Tuning.weap.pickup.same_type_melee
    return get_score(it) / cur.score > min_ratio
  end

  return false
end

local function make_alert(it, msg, emoji, fm_option)
  return { it = it, msg = msg, emoji = emoji, fm_option = fm_option }
end

local function need_first_weapon()
  return you.xl() < FIRST_WEAPON_XL_CUTOFF
    and _weapon_cache.is_empty()
    and you.skill("Unarmed Combat") == 0
    and BRC.get.mut(BRC.MUTATIONS.claws, true) == 0
end

-- Local functions: Alerting
local function get_first_of_skill_alert(it, silent)
  local skill = it.weap_skill
  if not lowest_num_hands_alerted[skill] then return end

  local hands = BRC.get.hands(it)
  if lowest_num_hands_alerted[skill] > hands then
    -- Some early checks to skip alerts
    if hands == 2 and BRC.you.have_shield() then return end
    if skill == "Polearms" and you.skill("Ranged Weapons") >= RANGED_XL_THRESHOLD then return end

    -- Update lowest # hands alerted, and alert
    lowest_num_hands_alerted[skill] = hands
    if silent then return end
    local msg = string.format("First %s%s", string.sub(skill, 1, -2), hands == 1 and " (1-handed)" or "")
    return make_alert(it, msg, Emoji.WEAPON, Config.fm_alert.early_weap)
  end
end

local function get_early_weapon_alert(it)
  -- Alert really good usable ranged weapons
  if it.is_ranged and you.xl() <= Tuning.weap.alert.early_ranged.xl then
    if it.plus >= Tuning.weap.alert.early_ranged[BRC.get.ego(it) and "branded_min_plus" or "min_plus"] then
      local low_shield_training = you.skill("Shields") <= Tuning.weap.alert.early_ranged.max_shields
      if BRC.get.hands(it) == 1 or not BRC.you.have_shield() or low_shield_training then
        return make_alert(it, "Ranged weapon", Emoji.RANGED, Config.fm_alert.early_weap)
      end
    end
  end

  if you.xl() <= Tuning.weap.alert.early.xl then
    -- Skip items if we're clearly going another route
    local skill_setting = Tuning.weap.alert.early.skill
    local skill_diff = BRC.get.skill(top_attack_skill) - BRC.get.skill(it.weap_skill)
    if skill_diff > you.xl() * skill_setting.factor + skill_setting.offset then return false end

    local it_plus = it.plus or 0
    if BRC.get.ego(it) or it_plus and it_plus >= Tuning.weap.alert.early.branded_min_plus then
      return make_alert(it, "Early weapon", Emoji.WEAPON, Config.fm_alert.early_weap)
    end
  end

  return false
end

local function get_weap_high_score_alert(it)
  if _weapon_cache.is_empty() then return end -- Skip if not using weapons
  local category = f_pa_data.update_high_scores(it)
  if not category then return end
  return make_alert(it, category, Emoji.WEAPON, Config.fm_alert.high_score_weap)
end

local function get_upgrade_alert_same_type(it, cur, best_dps, best_score)
  -- Alert: new egos, highest DPS or highest weap_score
  local it_ego = BRC.get.ego(it, true) -- Don't overvalue speed/heavy egos (only consider their DPS)
  local cur_ego = BRC.get.ego(cur)
  if not cur.artefact and it_ego and it_ego ~= cur_ego then
    return make_alert(it, cur_ego and "Diff ego" or "Gain ego", Emoji.EGO, Config.fm_alert.weap_ego)
  elseif get_score(it) > best_score or BRC.get.weap_dps(it) > best_dps then
    return make_alert(it, "Weapon upgrade", Emoji.WEAPON, Config.fm_alert.upgrade_weap)
  end
end

--[[
get_inventory_upgrade_alert_sub() -> boolean : `cur` comes from _weapon_cache - it has some pre-computed values
Check if weapon is worth alerting for, compared against one weapon currently in inventory
--]]
local function get_upgrade_alert(it, cur, best_dps, best_score)
  -- Ensure the non-strict upgrade is checked, if not already done in pickup_weapon()
  if Config.pickup.weapons_pure_upgrades_only and is_weapon_upgrade(it, cur, false) then
    return make_alert(it, "Weapon upgrade", Emoji.WEAPON, Config.fm_alert.upgrade_weap)
  end

  if it.artefact then return make_alert(it, "Artefact weapon", Emoji.ARTEFACT) end
  if cur.subtype() == it.subtype() then return get_upgrade_alert_same_type(it, cur, best_dps, best_score) end
  if not is_valid_upgrade(it, cur) then return end

  -- Get ratio of weap_score / best_score. Penalize lower-trained skills
  local damp = Tuning.weap.alert.low_skill_penalty_damping
  local penalty = (BRC.get.skill(it.weap_skill) + damp) / (BRC.get.skill(top_attack_skill) + damp)
  local ratio = penalty * get_score(it) / best_score

  if BRC.get.hands(it) <= cur.hands then
    if cur.artefact then return false end
    if BRC.get.ego(it, true) then -- Don't overvalue Speed/Heavy egos (only consider their DPS)
      local it_ego = BRC.get.ego(it)
      if not BRC.get.ego(cur) then
        if ratio > Tuning.weap.alert.gain_ego then
          return make_alert(it, "Gain ego", Emoji.EGO, Config.fm_alert.weap_ego)
        end
      elseif not util.contains(_weapon_cache.egos, it_ego) and ratio > Tuning.weap.alert.new_ego then
        return make_alert(it, "New ego", Emoji.EGO, Config.fm_alert.weap_ego)
      end
    end
    if ratio > Tuning.weap.alert.pure_dps then
      return make_alert(it, "Weapon upgrade", Emoji.WEAPON, Config.fm_alert.upgrade_weap)
    end
  elseif BRC.you.free_offhand() or (you.skill("Shields") < Tuning.weap.alert.add_hand.ignore_sh_lvl) then
    local it_ego = BRC.get.ego(it)
    local unique_ego = it_ego and not util.contains(_weapon_cache.egos, it_ego)
    if unique_ego and ratio > Tuning.weap.alert.new_ego then
      return make_alert(it, "New ego (2-handed)", Emoji.EGO, Config.fm_alert.weap_ego)
    elseif ratio > Tuning.weap.alert.add_hand.not_using then
      return make_alert(it, "2-handed weapon", Emoji.TWO_HAND, Config.fm_alert.upgrade_weap)
    end
  elseif BRC.get.ego(it) and not BRC.get.ego(cur) and ratio > Tuning.weap.alert.add_hand.add_ego_lose_sh then
    local msg = "2-handed weapon (Gain ego)"
    return make_alert(it, msg, Emoji.TWO_HAND, Config.fm_alert.weap_ego)
  end
end

local function get_inventory_upgrade_alert(it)
  -- Once, find the top dps & score for inventory weapons of the same category
  local inv_best = _weapon_cache.max_dps[_weapon_cache.get_primary_key(it)]
  local top_dps = inv_best and inv_best.dps or 0
  local top_score = inv_best and get_score(inv_best) or 0

  -- Compare against all inventory weapons, even from other categories
  for _, inv in ipairs(_weapon_cache.weapons) do
    local best_dps = math.max(inv.dps, top_dps)
    local best_score = math.max(inv.score, top_score)
    local a = get_upgrade_alert(it, inv, best_dps, best_score)
    if a then return a end
  end
end

local function get_weapon_alert(it)
  return
    get_inventory_upgrade_alert(it)
    or get_first_of_skill_alert(it)
    or get_early_weapon_alert(it)
    or get_weap_high_score_alert(it)
end

-- Public API
function f_pa_weapons.pickup_weapon(it)
  -- Check if we need the first weapon of the game
  if need_first_weapon() then
    -- Check if we're carrying a weapon that didn't go into _weapon_cache (like a staff)
    for inv in iter.invent_iterator:new(items.inventory()) do
      if inv.is_weapon then return false end
    end
    return true
  end

  if BRC.is.risky_item(it) then return false end
  for _, inv in ipairs(_weapon_cache.weapons) do
    if is_weapon_upgrade(it, inv, Config.pickup.weapons_pure_upgrades_only) then
      -- Confirm after updating cache, to avoid spurious alerts from XP gain.
      f_pa_weapons.ready()
      if is_weapon_upgrade(it, inv, Config.pickup.weapons_pure_upgrades_only) then return true end
    end
  end
end

function f_pa_weapons.alert_weapon(it)
  if get_weapon_alert(it) then
    -- Confirm after updating cache, to avoid spurious alerts from XP gain.
    f_pa_weapons.ready()
    local a = get_weapon_alert(it)
    if a then return f_pickup_alert.do_alert(a.it, a.msg, a.emoji, a.fm_option) end
  end
  return false
end

-- Hook functions
function f_pa_weapons.init()
  _weapon_cache.weapons = {}
  _weapon_cache.egos = {}

  -- Track max DPS by weapon category
  _weapon_cache.max_dps = {}
  local keys = { "melee_1", "melee_1b", "melee_2", "melee_2b", "range_1", "range_1b", "range_2", "range_2b" }
  for _, key in ipairs(keys) do
    _weapon_cache.max_dps[key] = { dps = 0, acc = 0 }
  end

  -- Set top weapon skill
  top_attack_skill = "Unarmed Combat"
  local max_weap_skill = BRC.get.skill(top_attack_skill)
  for _, v in ipairs(BRC.WEAP_SCHOOLS) do
    if BRC.get.skill(v) > max_weap_skill then
      max_weap_skill = BRC.get.skill(v)
      top_attack_skill = v
    end
  end
end

function f_pa_weapons.ready()
  f_pa_weapons:init()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.is_weapon and not BRC.is.magic_staff(inv) then
      _weapon_cache.add_weapon(inv)
      f_pa_data.update_high_scores(inv)
    end
  end
end
