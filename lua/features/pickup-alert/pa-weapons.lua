---------------------------------------------------------------------------------------------------
-- BRC feature module: pickup-alert-weapons
-- @submodule f_pa_weapons
-- Weapon pickup and alert functions for the pickup-alert feature.
-- _weapon_cache table stores info about inventory weapons, to avoid repeat calculations.
---------------------------------------------------------------------------------------------------

f_pa_weapons = {}

---- Persistent variables ----
pa_lowest_hands_alerted = BRC.Data.persist("pa_lowest_hands_alerted", {
  ["Ranged Weapons"] = 3, -- Track lowest hand count alerted for this weapon school
  ["Polearms"] = 3, -- Track lowest hand count alerted for this weapon school
})

---- Local config alias ----
local Config = f_pickup_alert.Config
local Heur = f_pickup_alert.Config.Tuning.Weap
local Emoji = f_pickup_alert.Config.Emoji

---- Local constants ----
local FIRST_WEAPON_XL_CUTOFF = 6 -- Stop first-weapon alerts after this experience level
local POLEARM_RANGED_CUTOFF = 3 -- Stop polearm alerts when ranged skill reaches this level
local UPGRADE_SKILL_FACTOR = 0.5 -- No upgrade alerts if weapon skill is this % of top skill
-- Weapon cache constants
local RANGED_PREFIX = "range_"
local MELEE_PREFIX = "melee_"
local WEAP_CACHE_KEYS = {
  "melee_1", "melee_1b", "melee_2", "melee_2b", "range_1", "range_1b", "range_2", "range_2b"
}

---- Local variables ----
local top_attack_skill
local _weapon_cache = {} -- Cache info for inventory weapons to avoid repeat calculations

---- Local functions ----
local function get_score(it, no_brand_bonus)
  if it.dps and it.acc then
    -- Handle cached /  high-score tuples in _weapon_cache
    return it.dps + it.acc * Heur.Pickup.accuracy_weight
  end
  local dmg_type = no_brand_bonus and BRC.DMG_TYPE.unbranded or BRC.DMG_TYPE.scoring
  local acc_bonus = (it.accuracy + (it.plus or 0)) * Heur.Pickup.accuracy_weight
  return BRC.eq.get_dps(it, dmg_type) + acc_bonus
end

local function is_valid_upgrade(it, cur)
  return cur.is_ranged == it.is_ranged
    and BRC.it.is_polearm(cur) == BRC.it.is_polearm(it)
    and (
      you.race() == "Gnoll"
      or BRC.you.skill(it.weap_skill) >= UPGRADE_SKILL_FACTOR * BRC.you.skill(cur.weap_skill)
    )
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
    local cur_ego = BRC.eq.get_ego(cur)
    if BRC.eq.get_ego(it) == cur_ego then return it_plus > cur.plus end
    return not cur_ego and it_plus >= cur.plus
  end

  -- Check if it's a very likely upgrade
  if it.subtype() == cur.subtype() then
    if it.artefact then return true end
    if cur.artefact then return false end

    local it_ego = BRC.eq.get_ego(it)
    local cur_ego = BRC.eq.get_ego(cur)
    if cur_ego and not it_ego then return false end
    if it_ego and not cur_ego then return get_score(it) / cur.score > Heur.Pickup.add_ego end
    return it_ego == cur_ego and (it.plus or 0) > cur.plus
  elseif it.weap_skill == cur.weap_skill or you.race() == "Gnoll" then
    if BRC.eq.get_hands(it) > cur.hands then return false end
    if cur.is_ranged ~= it.is_ranged then return false end
    if BRC.it.is_polearm(cur) ~= BRC.it.is_polearm(it) then return false end

    if it.artefact then return true end
    if cur.artefact then return false end

    local min_ratio = it.is_ranged and Heur.Pickup.same_type_ranged or Heur.Pickup.same_type_melee
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
    and BRC.you.mut_lvl("claws") == 0
end

-- Local functions: Weapon cache
function _weapon_cache.get_primary_key(it)
  local tokens = {}
  tokens[1] = it.is_ranged and RANGED_PREFIX or MELEE_PREFIX
  tokens[2] = tostring(it.hands)
  if BRC.eq.get_ego(it) then tokens[3] = "b" end
  return table.concat(tokens)
end

--- Get all categories this weapon fits into (including more-restrictive categories)
function _weapon_cache.get_keys(is_ranged, hands, is_branded)
  local ranged_types = is_ranged and { RANGED_PREFIX, MELEE_PREFIX } or { MELEE_PREFIX }
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
  weap_data.subtype = function() -- For consistency with crawl item.subtype()
    return weap_data._subtype
  end
  weap_data.weap_skill = it.weap_skill
  weap_data.skill_lvl = BRC.you.skill(it.weap_skill)
  weap_data.is_ranged = it.is_ranged
  weap_data.hands = BRC.eq.get_hands(it)
  weap_data.artefact = it.artefact
  weap_data._ego = BRC.eq.get_ego(it)
  weap_data.ego = function() -- For consistency with crawl item.ego()
    return weap_data._ego
  end
  weap_data.plus = it.plus or 0
  weap_data.acc = it.accuracy + weap_data.plus
  weap_data.damage = it.damage
  weap_data.dps = BRC.eq.get_dps(it)
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

function _weapon_cache.refresh(skip_turn_check)
  local cur_turn = you.turns()
  if _weapon_cache.turn and _weapon_cache.turn == cur_turn and not skip_turn_check then return end
  _weapon_cache.turn = cur_turn
  _weapon_cache.weapons = {}
  _weapon_cache.egos = {}

  -- Can reuse max_dps table
  if _weapon_cache.max_dps then
    for _, key in ipairs(WEAP_CACHE_KEYS) do
      _weapon_cache.max_dps[key].dps = 0
      _weapon_cache.max_dps[key].acc = 0
    end
  else
    _weapon_cache.max_dps = {}
    for _, key in ipairs(WEAP_CACHE_KEYS) do
      _weapon_cache.max_dps[key] = { dps = 0, acc = 0 }
    end
  end

  for _, inv in ipairs(items.inventory()) do
    if inv.is_weapon and not BRC.it.is_magic_staff(inv) then
      _weapon_cache.add_weapon(inv)
      f_pa_data.update_high_scores(inv)
    end
  end
end

-- Local functions: Alerting
local function get_first_of_skill_alert(it)
  local skill = it.weap_skill
  if not pa_lowest_hands_alerted[skill] then return end

  local hands = BRC.eq.get_hands(it)
  if pa_lowest_hands_alerted[skill] > hands then
    -- Some early checks to skip alerts
    if hands == 2 and BRC.you.have_shield() then return end
    if skill == "Polearms" and you.skill("Ranged Weapons") >= POLEARM_RANGED_CUTOFF then return end

    -- Update lowest # hands alerted, and alert
    pa_lowest_hands_alerted[skill] = hands
    local msg = "First " .. string.sub(skill, 1, -2) .. (hands == 1 and " (1-handed)" or "")
    return make_alert(it, msg, Emoji.WEAPON, Config.Alert.More.early_weap)
  end
end

local function get_early_weapon_alert(it)
  -- Alert really good usable ranged weapons
  if it.is_ranged and you.xl() <= Heur.Alert.EarlyRanged.xl then
    local min_plus = Heur.Alert.EarlyRanged[BRC.eq.get_ego(it) and "branded_min_plus" or "min_plus"]
    if (it.plus or 0) >= min_plus / Config.Alert.weapon_sensitivity then
      local low_shield_training = you.skill("Shields") <= Heur.Alert.EarlyRanged.max_shields
      if BRC.eq.get_hands(it) == 1 or not BRC.you.have_shield() or low_shield_training then
        return make_alert(it, "Ranged weapon", Emoji.RANGED, Config.Alert.More.early_weap)
      end
    end
  end

  if you.xl() <= Heur.Alert.Early.xl then
    -- Ignore items if we're clearly going another route
    local skill_setting = Heur.Alert.Early.skill
    local skill_diff = BRC.you.skill(top_attack_skill) - BRC.you.skill(it.weap_skill)
    if skill_diff > you.xl() * skill_setting.factor + skill_setting.offset then return false end

    local it_plus = it.plus or 0
    if
      BRC.eq.get_ego(it)
      or it_plus >= Heur.Alert.Early.branded_min_plus / Config.Alert.weapon_sensitivity
    then
      return make_alert(it, "Early weapon", Emoji.WEAPON, Config.Alert.More.early_weap)
    end
  end

  return false
end

local function get_weap_high_score_alert(it)
  if _weapon_cache.is_empty() then return end -- Skip if not using weapons
  local category = f_pa_data.update_high_scores(it)
  if not category then return end
  return make_alert(it, category, Emoji.WEAPON, Config.Alert.More.high_score_weap)
end

-- get_upgrade_alert() subroutines
local function can_use_2h_without_losing_shield()
  return BRC.you.free_offhand() or (you.skill("Shields") < Heur.Alert.AddHand.ignore_sh_lvl)
end

local function check_upgrade_free_offhand(it, ratio)
  local it_ego = BRC.eq.get_ego(it)
  if it_ego and not util.contains(_weapon_cache.egos, it_ego) and ratio > Heur.Alert.new_ego then
    return make_alert(it, "New ego (2-handed)", Emoji.EGO, Config.Alert.More.weap_ego)
  elseif ratio > Heur.Alert.AddHand.not_using then
    return make_alert(it, "2-handed weapon", Emoji.TWO_HAND, Config.Alert.More.upgrade_weap)
  end
  return false
end

local function check_upgrade_lose_shield(it, cur, ratio)
  if (
      BRC.eq.get_ego(it)
      and not BRC.eq.get_ego(cur)
      and ratio > Heur.Alert.AddHand.add_ego_lose_sh
    )
  then
    return make_alert(it, "2-handed weapon (Gain ego)", Emoji.TWO_HAND, Config.Alert.More.weap_ego)
  end

  return false
end

local function check_upgrade_no_hand_loss(it, cur, ratio)
  if cur.artefact then return false end

  if BRC.eq.get_ego(it, true) then -- Don't overvalue Speed/Heavy egos (only consider their DPS)
    local it_ego = BRC.eq.get_ego(it)
    if not BRC.eq.get_ego(cur) then
      if ratio > Heur.Alert.gain_ego then
        return make_alert(it, "Gain ego", Emoji.EGO, Config.Alert.More.weap_ego)
      end
    elseif not util.contains(_weapon_cache.egos, it_ego) and ratio > Heur.Alert.new_ego then
      return make_alert(it, "New ego", Emoji.EGO, Config.Alert.More.weap_ego)
    end
  end

  if ratio > Heur.Alert.pure_dps then
    return make_alert(it, "DPS increase", Emoji.WEAPON, Config.Alert.More.upgrade_weap)
  end

  return false
end

local function check_upgrade_same_subtype(it, cur, best_dps, best_score)
  -- Alert: new egos, highest DPS or highest weap_score
  local it_ego = BRC.eq.get_ego(it, true) -- Don't overvalue speed/heavy (only consider their DPS)
  local cur_ego = BRC.eq.get_ego(cur)
  if not cur.artefact and it_ego and it_ego ~= cur_ego then
    local change = cur_ego and "Diff ego" or "Gain ego"
    return make_alert(it, change, Emoji.EGO, Config.Alert.More.weap_ego)
  else
    local s = Config.Alert.weapon_sensitivity
    if get_score(it) > best_score / s or BRC.eq.get_dps(it) > best_dps / s then
      return make_alert(it, "Weapon upgrade", Emoji.WEAPON, Config.Alert.More.upgrade_weap)
    end
  end
end

--- Check if weapon is worth alerting for, compared against one weapon currently in inventory
-- @param cur (weapon) comes from _weapon_cache - it has some pre-computed values
local function get_upgrade_alert(it, cur, best_dps, best_score)
  -- Ensure the non-strict upgrade is checked, if not already done in pickup_weapon()
  if Config.Pickup.weapons_pure_upgrades_only and is_weapon_upgrade(it, cur, false) then
    return make_alert(it, "Weapon upgrade", Emoji.WEAPON, Config.Alert.More.upgrade_weap)
  end

  if it.artefact then return make_alert(it, "Artefact weapon", Emoji.ARTEFACT) end
  if cur.subtype() == it.subtype() then
    return check_upgrade_same_subtype(it, cur, best_dps, best_score)
  end
  if not is_valid_upgrade(it, cur) then return end

  -- Get ratio of weap_score / best_score. Penalize lower-trained skills
  local damp = Heur.Alert.low_skill_penalty_damping
  local penalty = (BRC.you.skill(it.weap_skill) + damp) / (BRC.you.skill(top_attack_skill) + damp)
  local ratio = penalty * get_score(it) / best_score * Config.Alert.weapon_sensitivity

  if BRC.eq.get_hands(it) <= cur.hands then
    return check_upgrade_no_hand_loss(it, cur, ratio)
  elseif can_use_2h_without_losing_shield() then
    return check_upgrade_free_offhand(it, ratio)
  else
    return check_upgrade_lose_shield(it, cur, ratio)
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
  return get_inventory_upgrade_alert(it)
    or get_first_of_skill_alert(it)
    or get_early_weapon_alert(it)
    or get_weap_high_score_alert(it)
end

---- Public API ----
function f_pa_weapons.pickup_weapon(it)
  _weapon_cache.refresh()
  if need_first_weapon() then
    -- Check if we're carrying a weapon that didn't go into _weapon_cache (like a staff)
    return not util.exists(items.inventory(), function(i) return i.is_weapon end)
  end

  if BRC.eq.is_risky(it) then return false end
  for _, inv in ipairs(_weapon_cache.weapons) do
    if is_weapon_upgrade(it, inv, Config.Pickup.weapons_pure_upgrades_only) then
      -- Confirm after updating cache, to avoid spurious alerts from XP gain.
      _weapon_cache.refresh(true)
      if is_weapon_upgrade(it, inv, Config.Pickup.weapons_pure_upgrades_only) then return true end
    end
  end
end

function f_pa_weapons.alert_weapon(it)
  _weapon_cache.refresh()
  if get_weapon_alert(it) then
    -- Confirm after updating cache, to avoid spurious alerts from XP gain.
    _weapon_cache.refresh(true)
    local a = get_weapon_alert(it)
    if a then return f_pickup_alert.do_alert(a.it, a.msg, a.emoji, a.fm_option) end
  end
  return false
end

---- Hook functions ----
function f_pa_weapons.init()
  if not Config.Alert.first_ranged then pa_lowest_hands_alerted["Ranged Weapons"] = 0 end
  if not Config.Alert.first_polearm then pa_lowest_hands_alerted["Polearms"] = 0 end
  top_attack_skill = BRC.you.top_wpn_skill() or "Unarmed Combat"
  _weapon_cache.refresh(true)
end

function f_pa_weapons.ready()
  top_attack_skill = BRC.you.top_wpn_skill() or "Unarmed Combat"
end
