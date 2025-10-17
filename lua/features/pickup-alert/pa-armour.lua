--[[
Feature: pickup-alert-armour
Description: Armour pickup logic and alert system for the pickup-alert system
Author: Original Equipment autopickup by Medar, gammafunk, and various others. Extended by buehler.
Dependencies: core/config.lua, core/constants.lua, core/util.lua, pa-main.lua
--]]

f_pa_armour = {}

---- Local config aliases ----
local Heur = f_pickup_alert.Config.Tuning.Armour
local Emoji = f_pickup_alert.Config.Emoji
local Alert = f_pickup_alert.Config.Alert
local More = f_pickup_alert.Config.Alert.More

---- Local constants / configuration ----
local ENCUMB_ARMOUR_DIVISOR = 2 -- Encumbrance penalty is offset by (Armour / ENCUMB_ARMOUR_DIVISOR)
local SAME = "same_ego"
local LOST = "lost_ego"
local GAIN = "gain_ego"
local DIFF = "diff_ego"
local HEAVIER = "Heavier"
local LIGHTER = "Lighter"

local ARMOUR_ALERT = {
  artefact = { msg = "Artefact armour", emoji = Emoji.ARTEFACT },
  [GAIN] = { msg = "Gain ego", emoji = Emoji.EGO },
  [DIFF] = { msg = "Diff ego", emoji = Emoji.EGO },
  [LIGHTER] = {
    [GAIN] = { msg = "Gain ego (Lighter armour)", emoji = Emoji.EGO },
    [DIFF] = { msg = "Diff ego (Lighter armour)", emoji = Emoji.EGO },
    [SAME] = { msg = "Lighter armour", emoji = Emoji.LIGHTER },
    [LOST] = { msg = "Lighter armour (Lost ego)", emoji = Emoji.LIGHTER },
  },
  [HEAVIER] = {
    [GAIN] = { msg = "Gain ego (Heavier armour)", emoji = Emoji.EGO },
    [DIFF] = { msg = "Diff ego (Heavier armour)", emoji = Emoji.EGO },
    [SAME] = { msg = "Heavier Armour", emoji = Emoji.HEAVIER },
    [LOST] = { msg = "Heavier Armour (Lost ego)", emoji = Emoji.HEAVIER },
  },
} -- ARMOUR_ALERT (do not remove this comment)

---- Local functions ----
local function aux_slot_is_impaired(it)
  local st = it.subtype()
  -- Skip boots/gloves/helmet if wearing Lear's hauberk
  local worn = items.equipped_at("armour")
  if worn and worn.name("qual") == "Lear's hauberk" and st ~= "cloak" then return true end

  -- Mutation interference
  if st == "gloves" then
    return BRC.get.mut("demonic touch") >= 3 and not BRC.you.free_offhand()
        or BRC.get.mut("claws") > 0 and not items.equipped_at("weapon")
  elseif st == "boots" then
    return BRC.get.mut("hooves") > 0
        or BRC.get.mut("talons") > 0
  elseif it.name("base"):contains("helmet") then
    return BRC.get.mut("horns") > 0
        or BRC.get.mut("beak") > 0
        or BRC.get.mut("antennae") > 0
  end

  return false
end

local function get_adjusted_ev_delta(encumb_delta, ev_delta)
  local encumb_skills = you.skill("Spellcasting")
    + you.skill("Ranged Weapons")
    - you.skill("Armour") / ENCUMB_ARMOUR_DIVISOR
  local encumb_impact = encumb_skills / you.xl()
  encumb_impact = math.max(0, math.min(1, encumb_impact)) -- Clamp to 0-1

  -- Subtract weighted encumbrance penalty, to align with ev_delta (heavier is negative)
  return ev_delta - encumb_delta * encumb_impact * Heur.encumb_penalty_weight
end

local function get_ego_change_type(cur_ego, it_ego)
  if it_ego == cur_ego then
    return SAME
  elseif not it_ego then
    return LOST
  elseif not cur_ego then
    return GAIN
  else
    return DIFF
  end
end

local function is_new_ego(ego_change)
  return ego_change == GAIN or ego_change == DIFF
end

local function send_armour_alert(it, t_alert)
  return f_pickup_alert.do_alert(it, t_alert.msg, t_alert.emoji, More.body_armour)
end

-- Local functions: Pickup
local function pickup_body_armour(it)
  local cur = items.equipped_at("armour")
  if not cur then return false end -- surely am naked for a reason

  -- No pickup if wearing an artefact
  if cur.artefact then return false end

  -- No pickup if adding encumbrance or losing AC
  local encumb_delta = it.encumbrance - cur.encumbrance
  if encumb_delta > 0 then return false end
  local ac_delta = BRC.get.armour_ac(it) - BRC.get.armour_ac(cur)
  if ac_delta < 0 then return false end

  -- Pickup: Pure upgrades
  local it_ego = BRC.get.ego(it)
  local cur_ego = BRC.get.ego(cur)
  if it_ego == cur_ego then return (ac_delta > 0 or encumb_delta < 0) end
  return not cur_ego and (ac_delta >= 0 or encumb_delta <= 0)
end

local function pickup_shield(it)
  -- Don't replace these
  local cur = items.equipped_at("offhand")
  if not BRC.is.shield(cur) then return false end
  if cur.encumbrance ~= it.encumbrance then return false end
  if cur.artefact then return false end

  -- Pickup: artefact
  if it.artefact then return true end

  -- Pickup: Pure upgrades
  local it_plus = it.plus or 0
  local it_ego = BRC.get.ego(it)
  local cur_ego = BRC.get.ego(cur)
  if it_ego == cur_ego then return it_plus > cur.plus end
  return not cur_ego and it_plus >= cur.plus
end

local function pickup_aux_armour(it)
  -- Pickup: Anything if the slot is empty, unless downside from mutation
  if aux_slot_is_impaired(it) then return false end
  local all_equipped, num_slots = BRC.get.equipped_at(it)
  if #all_equipped < num_slots then
    -- If we're carrying one (implying a blocking mutation), don't pickup another
    if num_slots == 1 then
      local ST = it.subtype()
      return not util.exists(items.inventory(), function(inv) return inv.subtype() == ST end)
    end
    return true
  end

  -- Pickup: artefact, unless slot(s) already full of artefact(s)
  for i, cur in ipairs(all_equipped) do
    if not cur.artefact then break end
    if i == num_slots then return false end
  end
  if it.artefact then return true end

  -- Pickup: Pure upgrades
  local it_ac = BRC.get.armour_ac(it)
  local it_ego = BRC.get.ego(it)
  for _, cur in ipairs(all_equipped) do
    local cur_ac = BRC.get.armour_ac(cur)
    local cur_ego = BRC.get.ego(cur)
    if it_ego == cur_ego then
      if it_ac > cur_ac then return true end
    elseif not cur_ego then
      if it_ac >= cur_ac then return true end
    end
  end
  return false
end

-- Local functions: Alerting
local function should_alert_body_armour(weight, gain, loss, ego_change)
  -- Check if armour stat trade-off meets configured ratio thresholds
  local meets_ratio = loss <= 0
    or (gain / loss > Heur[weight][ego_change] / Alert.armour_sensitivity)
  if not meets_ratio then return false end

  -- Additional ego-specific restrictions
  if is_new_ego(ego_change) then
    return loss <= Heur[weight].max_loss * Alert.armour_sensitivity
  elseif ego_change == LOST then
    return gain >= Heur[weight].min_gain / Alert.armour_sensitivity
  end

  return true
end

-- Alert when finding higher AC than previously seen, unless training spells/ranged and NOT armour
local function alert_highest_ac(it)
  if you.xl() > 12 then return false end
  local total_skill = you.skill("Spellcasting") + you.skill("Ranged Weapons")
  if total_skill > 0 and you.skill("Armour") == 0 then return false end

  if pa_high_score.ac == 0 then
    local worn = items.equipped_at("armour")
    if not worn then return false end
    pa_high_score.ac = BRC.get.armour_ac(worn)
  else
    local itAC = BRC.get.armour_ac(it)
    if itAC > pa_high_score.ac then
      pa_high_score.ac = itAC
      return f_pickup_alert.do_alert(it, "Highest AC", Emoji.STRONGEST, More.high_score_armour)
    end
  end

  return false
end

local function alert_body_armour(it)
  local cur = items.equipped_at("armour")
  if not cur then return false end

  -- Always alert artefacts once identified
  if it.artefact then return send_armour_alert(it, ARMOUR_ALERT.artefact) end

  -- Get changes to ego, AC, EV, encumbrance
  local it_ego = BRC.get.ego(it)
  local cur_ego = BRC.get.ego(cur)
  local ego_change = get_ego_change_type(cur_ego, it_ego)
  local ac_delta = BRC.get.armour_ac(it) - BRC.get.armour_ac(cur)
  local ev_delta = BRC.get.armour_ev(it) - BRC.get.armour_ev(cur)
  local encumb_delta = it.encumbrance - cur.encumbrance

  -- Alert new egos if same encumbrance, or small change to total (AC+EV)
  if is_new_ego(ego_change) then
    if encumb_delta == 0 then return send_armour_alert(it, ARMOUR_ALERT[ego_change]) end

    local weight = encumb_delta < 0 and LIGHTER or HEAVIER
    if math.abs(ac_delta + ev_delta) <= Heur[weight].ignore_small * Alert.armour_sensitivity then
      return send_armour_alert(it, ARMOUR_ALERT[weight][ego_change])
    end
  end

  -- Check if lighter/heavier armour meets stat trade-off thresholds
  if encumb_delta < 0 then
    if should_alert_body_armour(LIGHTER, ev_delta, -ac_delta, ego_change) then
      return send_armour_alert(it, ARMOUR_ALERT[LIGHTER][ego_change])
    end
  elseif encumb_delta > 0 then
    local adj_ev_delta = get_adjusted_ev_delta(encumb_delta, ev_delta)
    if should_alert_body_armour(HEAVIER, ac_delta, -adj_ev_delta, ego_change) then
      return send_armour_alert(it, ARMOUR_ALERT[HEAVIER][ego_change])
    end
  end

  -- Check for record AC values or early-game ego armour
  if alert_highest_ac(it) then return true end
  if it_ego and you.xl() <= Heur.early_xl then
    return f_pickup_alert.do_alert(it, "Early armour", Emoji.EGO)
  end
end

local function alert_shield(it)
  if it.artefact then
    return f_pickup_alert.do_alert(it, "Artefact shield", Emoji.ARTEFACT, More.shields)
  end

  -- Don't alert shields if not wearing one (one_time_alerts fire for the first of each type)
  local cur = items.equipped_at("offhand")
  if not BRC.is.shield(cur) then return false end

  -- Alert: New ego, Gain SH
  local ego_change = get_ego_change_type(BRC.get.ego(cur), BRC.get.ego(it))
  if is_new_ego(ego_change) then
    local alert_msg = ego_change == DIFF and "Diff ego" or "Gain ego"
    return f_pickup_alert.do_alert(it, alert_msg, Emoji.EGO, More.shields)
  elseif BRC.get.shield_sh(it) > BRC.get.shield_sh(cur) then
    return f_pickup_alert.do_alert(it, "Higher SH", Emoji.STRONGER, More.shields)
  end
end

local function alert_aux_armour(it, unworn_inv_item)
  if it.artefact then
    return f_pickup_alert.do_alert(it, "Artefact aux armour", Emoji.ARTEFACT, More.aux_armour)
  end

  local all_equipped, num_slots = BRC.get.equipped_at(it)
  if #all_equipped < num_slots then
    if unworn_inv_item then
      all_equipped[#all_equipped + 1] = unworn_inv_item
    else
      -- Catch dangerous brands or items blocked by non-innate mutations
      return f_pickup_alert.do_alert(it, "Aux armour", BRC.EMOJI.EXCLAMATION, More.aux_armour)
    end
  end

  local it_ego = BRC.get.ego(it)
  for _, cur in ipairs(all_equipped) do
    local ego_change = get_ego_change_type(BRC.get.ego(cur), it_ego)
    if is_new_ego(ego_change) then
      local alert_msg = ego_change == DIFF and "Diff ego" or "Gain ego"
      return f_pickup_alert.do_alert(it, alert_msg, Emoji.EGO, More.aux_armour)
    elseif BRC.get.armour_ac(it) > BRC.get.armour_ac(cur) then
      return f_pickup_alert.do_alert(it, "Higher AC", Emoji.STRONGER, More.aux_armour)
    end
  end
end

---- Public API ----
function f_pa_armour.pickup_armour(it)
  if BRC.is.risky_item(it) then return false end

  if BRC.is.body_armour(it) then
    return pickup_body_armour(it)
  elseif BRC.is.shield(it) then
    return pickup_shield(it)
  else
    return pickup_aux_armour(it)
  end
end

--- Alerts armour items that didn't auto-pickup but are worth considering.
--- This comes after pickup, so there will be no pure upgrades.
-- @param unworn_inv_item (optional) to compare against an unworn aux armour item in inventory.
function f_pa_armour.alert_armour(it, unworn_inv_item)
  if BRC.is.body_armour(it) then
    return alert_body_armour(it)
  elseif BRC.is.shield(it) then
    return alert_shield(it)
  else
    return alert_aux_armour(it, unworn_inv_item)
  end
end
