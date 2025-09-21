--[[
Feature: pickup-alert-weapons
Description: Weapon pickup logic, caching, and alert system for the pickup-alert system
Author: buehler
Dependencies: core/config.lua, core/data.lua, core/util.lua
--]]

f_pa_weapons = {}
--f_pa_weapons.BRC_FEATURE_NAME = "pickup-alert-weapons"

-- Persistent variables
lowest_num_hands_alerted = BRC.data.persist("lowest_num_hands_alerted", {
  ["Ranged Weapons"] = 3, -- Start with 3 (to fire both 1 and 2-handed alerts)
  ["Polearms"] = 3, -- Start with 3 (to fire both 1 and 2-handed alerts)
}) -- lowest_num_hands_alerted (do not remove this comment)

-- Local constants / configuration
local FIRST_WEAPON_XL_CUTOFF = 4 -- Stop looking for first weapon after this XL
local RANGED_XL_THRESHOLD = 3 -- At this skill level, don't bother alerting for polearms
local RANGED = "range_"
local MELEE = "melee_"

-- Local variables
local top_attack_skill

-- Global variable: Cache weapons in inventory (so we don't recompute DPS, etc on every autopickup call)
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
  weap_data.subtype = function() return weap_data._subtype end -- For consistency in other code
  weap_data.weap_skill = it.weap_skill
  weap_data.skill_lvl = BRC.get.skill(it.weap_skill)
  weap_data.is_ranged = it.is_ranged
  weap_data.hands = BRC.get.hands(it)
  weap_data.artefact = it.artefact
  weap_data._ego = BRC.get.ego(it)
  weap_data.ego = function() return weap_data._ego end -- For consistency in other code
  weap_data.plus = it.plus or 0
  weap_data.acc = it.accuracy + weap_data.plus
  weap_data.damage = it.damage
  weap_data.dps = BRC.get.weap_dps(it)
  weap_data.score = BRC.get.weap_score(it)
  weap_data.unbranded_score = BRC.get.weap_score(it, true)

  -- Check for exclusion tags
  local lower_insc = it.inscription:lower()
  weap_data.allow_upgrade = not (lower_insc:find("!u") or lower_insc:find("!brc"))

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
-- is_weapon_upgrade(it, cur) -> boolean : For pickup; Check if a weapon is an upgrade to one currently in inventory.
-- `cur` comes from _weapon_cache - it has some pre-computed values
local function is_weapon_upgrade(it, cur)
  if it.subtype() == cur.subtype() then
    -- Exact weapon type match
    if it.artefact then return true end
    if cur.artefact then return false end
    local it_ego = BRC.get.ego(it)
    local cur_ego = BRC.get.ego(cur)
    if cur_ego and not it_ego then return false end
    if it_ego and it.is_identified and not cur_ego then
      return BRC.get.weap_score(it) / cur.score > BRC.Tuning.weap.pickup.add_ego
    end
    return it_ego == cur_ego and BRC.get.weap_score(it) > cur.score
  elseif it.weap_skill == cur.weap_skill or you.race() == "Gnoll" then
    -- Return false if no clear upgrade possible
    if BRC.get.hands(it) > cur.hands then return false end
    if cur.is_ranged ~= it.is_ranged then return false end
    if BRC.is.polearm(cur) ~= BRC.is.polearm(it) then return false end

    if it.artefact then return true end
    if cur.artefact then return false end

    local min_ratio = it.is_ranged and BRC.Tuning.weap.pickup.same_type_ranged or BRC.Tuning.weap.pickup.same_type_melee
    return BRC.get.weap_score(it) / cur.score > min_ratio
  end

  return false
end

local function need_first_weapon()
  return you.xl() < FIRST_WEAPON_XL_CUTOFF
    and _weapon_cache.is_empty()
    and you.skill("Unarmed Combat") == 0
    and BRC.get.mut(BRC.MUTATIONS.claws, true) == 0
end

-- Local functions: Alerting
local function alert_first_of_skill(it, silent)
  local skill = it.weap_skill
  if not lowest_num_hands_alerted[skill] then return false end

  local hands = BRC.get.hands(it)
  if lowest_num_hands_alerted[skill] > hands then
    -- Some early checks to skip alerts
    if hands == 2 and BRC.you.have_shield() then return false end
    if skill == "Polearms" and you.skill("Ranged Weapons") >= RANGED_XL_THRESHOLD then return false end

    -- Update lowest # hands alerted, and alert
    lowest_num_hands_alerted[skill] = hands
    if silent then return true end
    local msg = string.format("First %s%s", string.sub(skill, 1, -2), hands == 1 and " (1-handed)" or "")
    return f_pickup_alert.do_alert(it, msg, BRC.Emoji.WEAPON, BRC.Config.fm_alert.early_weap)
  end
  return false
end

local function alert_early_weapons(it)
  -- Alert really good usable ranged weapons
  if you.xl() <= BRC.Tuning.weap.alert.early_ranged.xl then
    if it.is_identified and it.is_ranged then
      if
        it.plus >= BRC.Tuning.weap.alert.early_ranged.min_plus and BRC.get.ego(it)
        or it.plus >= BRC.Tuning.weap.alert.early_ranged.branded_min_plus
      then
        local low_shield_training = you.skill("Shields") <= BRC.Tuning.weap.alert.early_ranged.max_shields
        if BRC.get.hands(it) == 1 or not BRC.you.have_shield() or low_shield_training then
          return f_pickup_alert.do_alert(it, "Ranged weapon", BRC.Emoji.RANGED, BRC.Config.fm_alert.early_weap)
        end
      end
    end
  end

  if you.xl() <= BRC.Tuning.weap.alert.early.xl then
    -- Skip items if we're clearly going another route
    local skill_setting = BRC.Tuning.weap.alert.early.skill
    local skill_diff = BRC.get.skill(top_attack_skill) - BRC.get.skill(it.weap_skill)
    if skill_diff > you.xl() * skill_setting.factor + skill_setting.offset then return false end

    local it_plus = it.plus or 0
    if BRC.get.ego(it) or it_plus and it_plus >= BRC.Tuning.weap.alert.early.branded_min_plus then
      return f_pickup_alert.do_alert(it, "Early weapon", BRC.Emoji.WEAPON, BRC.Config.fm_alert.early_weap)
    end
  end

  return false
end

--[[
alert_interesting_weapon() -> boolean : `cur` comes from _weapon_cache - it has some pre-computed values
Check if weapon is worth alerting for, compared against one weapon currently in inventory
--]]
local function alert_interesting_weapon(it, cur)
  if it.artefact and it.is_identified then return f_pickup_alert.do_alert(it, "Artefact weapon", BRC.Emoji.ARTEFACT) end

  local inv_best = _weapon_cache.max_dps[_weapon_cache.get_primary_key(it)]
  local best_dps = math.max(cur.dps, inv_best and inv_best.dps or 0)
  local best_score = math.max(cur.score, inv_best and BRC.get.weap_score(inv_best) or 0)

  if cur.subtype() == it.subtype() then
    -- Exact weapon type match; alert new egos or higher DPS/weap_score
    local it_ego = BRC.get.ego(it, true) -- Don't overvalue Speed/Heavy egos (only look at their DPS)
    if not cur.artefact and it_ego and it_ego ~= BRC.get.ego(cur) then
      return f_pickup_alert.do_alert(it, "Diff ego", BRC.Emoji.EGO, BRC.Config.fm_alert.weap_ego)
    elseif BRC.get.weap_score(it) > best_score or BRC.get.weap_dps(it) > best_dps then
      return f_pickup_alert.do_alert(it, "Weapon upgrade", BRC.Emoji.WEAPON, BRC.Config.fm_alert.upgrade_weap)
    end
    return false
  end

  if cur.is_ranged ~= it.is_ranged then return false end
  if BRC.is.polearm(cur) ~= BRC.is.polearm(it) then return false end
  if 2 * BRC.get.skill(it.weap_skill) < BRC.get.skill(cur.weap_skill) then return false end

  -- Penalize lower-trained skills
  local damp = BRC.Tuning.weap.alert.low_skill_penalty_damping
  local penalty = (BRC.get.skill(it.weap_skill) + damp) / (BRC.get.skill(top_attack_skill) + damp)
  local ratio = penalty * BRC.get.weap_score(it) / best_score

  if BRC.get.hands(it) > cur.hands then
    if BRC.you.free_offhand() or (you.skill("Shields") < BRC.Tuning.weap.alert.add_hand.ignore_sh_lvl) then
      local it_ego = BRC.get.ego(it)
      local unique_ego = it_ego and not util.contains(_weapon_cache.egos, it_ego)
      if unique_ego and ratio > BRC.Tuning.weap.alert.new_ego then
        return f_pickup_alert.do_alert(it, "New ego (2-handed)", BRC.Emoji.EGO, BRC.Config.fm_alert.weap_ego)
      elseif ratio > BRC.Tuning.weap.alert.add_hand.not_using then
        return f_pickup_alert.do_alert(it, "2-handed weapon", BRC.Emoji.TWO_HAND, BRC.Config.fm_alert.upgrade_weap)
      end
    elseif BRC.get.ego(it) and not BRC.get.ego(cur) and ratio > BRC.Tuning.weap.alert.add_hand.add_ego_lose_sh then
      local msg = "2-handed weapon (Gain ego)"
      return f_pickup_alert.do_alert(it, msg, BRC.Emoji.TWO_HAND, BRC.Config.fm_alert.weap_ego)
    end
  else -- No extra hand required
    if cur.artefact then return false end
    if BRC.get.ego(it, true) then -- Don't overvalue Speed/Heavy egos (only look at their DPS)
      local it_ego = BRC.get.ego(it)
      if not BRC.get.ego(cur) then
        if ratio > BRC.Tuning.weap.alert.gain_ego then
          return f_pickup_alert.do_alert(it, "Gain ego", BRC.Emoji.EGO, BRC.Config.fm_alert.weap_ego)
        end
      elseif not util.contains(_weapon_cache.egos, it_ego) and ratio > BRC.Tuning.weap.alert.new_ego then
        return f_pickup_alert.do_alert(it, "New ego", BRC.Emoji.EGO, BRC.Config.fm_alert.weap_ego)
      end
    end
    if ratio > BRC.Tuning.weap.alert.pure_dps then
      return f_pickup_alert.do_alert(it, "Weapon upgrade", BRC.Emoji.WEAPON, BRC.Config.fm_alert.upgrade_weap)
    end
  end

  return false
end

local function alert_interesting_weapons(it)
  for _, inv in ipairs(_weapon_cache.weapons) do
    if alert_interesting_weapon(it, inv) then return true end
  end
  return false
end

local function alert_weap_high_scores(it)
  local category = f_pa_data.update_high_scores(it)
  if not category then return false end
  return f_pickup_alert.do_alert(it, category, BRC.Emoji.WEAPON, BRC.Config.fm_alert.high_score_weap)
end

-- Public API
function f_pa_weapons.pickup_weapon(it)
  -- Check if we need the first weapon of the game
  if need_first_weapon() then
    -- Staves don't go into _weapon_cache; check if we're carrying just a staff
    for inv in iter.invent_iterator:new(items.inventory()) do
      if inv.is_weapon then return false end -- fastest way to check if it's a staff
    end
    return true
  end

  if BRC.is.risky_item(it) then return false end
  if f_pa_data.find(pa_items_picked, it) then return false end
  for _, inv in ipairs(_weapon_cache.weapons) do
    if inv.allow_upgrade and is_weapon_upgrade(it, inv) then return true end
  end
end

function f_pa_weapons.alert_weapon(it)
  if alert_interesting_weapons(it) then return true end
  if alert_first_of_skill(it) then return true end
  if alert_early_weapons(it) then return true end

  -- Skip high score alerts if not using weapons
  if _weapon_cache.is_empty() then return false end
  return alert_weap_high_scores(it)
end

-- Hook functions
function f_pa_weapons.init()
  _weapon_cache.weapons = {}
  _weapon_cache.egos = {}

  -- Track max DPS by weapon category
  _weapon_cache.max_dps = {}
  local keys = {
    "melee_1",
    "melee_1b",
    "melee_2",
    "melee_2b",
    "range_1",
    "range_1b",
    "range_2",
    "range_2b",
  } -- _weapon_cache.max_dps (do not remove this comment)
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
