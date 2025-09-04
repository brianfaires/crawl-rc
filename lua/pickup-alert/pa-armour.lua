--[[
Feature: pickup-alert-armour
Description: Armour pickup logic and alert system for the pickup-alert system
Author: buehler
Dependencies: CONFIG, COLORS, EMOJI, iter, util, pa-util
--]]

f_pickup_alert_armour = {}
--f_pickup_alert_armour.BRC_FEATURE_NAME = "pickup-alert-armour"

-- Local constants / configuration
local ENCUMB_ARMOUR_DIVISOR = 2 -- Encumbrance penalty is offset by (Armour / ENCUMB_ARMOUR_DIVISOR)
local SAME = "same_ego"
local LOST = "lost_ego"
local GAIN = "gain_ego"
local DIFF = "diff_ego"
local HEAVIER = "heavier"
local LIGHTER = "lighter"

local ARMOUR_ALERT = {
  artefact = { msg = "Artefact armour", emoji = EMOJI.ARTEFACT },
  [GAIN] = { msg = "Gain ego", emoji = EMOJI.EGO },
  [DIFF] = { msg = "Diff ego", emoji = EMOJI.EGO },
  [LIGHTER] = {
    [GAIN] = { msg = "Gain ego (Lighter armour)", emoji = EMOJI.EGO },
    [DIFF] = { msg = "Diff ego (Lighter armour)", emoji = EMOJI.EGO },
    [SAME] = { msg = "Lighter armour", emoji = EMOJI.LIGHTER },
    [LOST] = { msg = "Lighter armour (Lost ego)", emoji = EMOJI.LIGHTER },
  },
  [HEAVIER] = {
    [GAIN] = { msg = "Gain ego (Heavier armour)", emoji = EMOJI.EGO },
    [DIFF] = { msg = "Diff ego (Heavier armour)", emoji = EMOJI.EGO },
    [SAME] = { msg = "Heavier Armour", emoji = EMOJI.HEAVIER },
    [LOST] = { msg = "Heavier Armour (Lost ego)", emoji = EMOJI.HEAVIER },
  }, -- ARMOUR_ALERT.heavier (do not remove this comment)
} -- ARMOUR_ALERT (do not remove this comment)

-- Local functions
local function aux_slot_is_impaired(it)
  local st = it.subtype()
  -- Skip boots/gloves/helmet if wearing Lear's hauberk
  local worn = items.equipped_at("armour")
  if worn and worn.name("qual") == "Lear's hauberk" and st ~= "cloak" then return true end

  -- Mutation interference
  if st == "gloves" then
    return BRC.get.mut(MUTS.demonic_touch, true) >= 3 and not BRC.you.free_offhand()
      or BRC.get.mut(MUTS.claws, true) > 0 and not items.equipped_at("weapon")
  elseif st == "boots" then
    return BRC.get.mut(MUTS.hooves, true) > 0 or BRC.get.mut(MUTS.talons, true) > 0
  elseif it.name("base"):find("helmet", 1, true) then
    return BRC.get.mut(MUTS.horns, true) > 0 or BRC.get.mut(MUTS.beak, true) > 0 or BRC.get.mut(MUTS.antennae, true) > 0
  end

  return false
end

local function get_adjusted_ev_delta(encumb_delta, ev_delta)
  local encumb_skills = you.skill("Spellcasting")
    + you.skill("Ranged Weapons")
    - you.skill("Armour") / ENCUMB_ARMOUR_DIVISOR
  local encumb_impact = encumb_skills / you.xl()
  encumb_impact = math.max(0, math.min(1, encumb_impact)) -- Clamp to 0-1

  -- Subtract weighted encumbrance penalty, to align with ev_delta (negative == heavier)
  return ev_delta - encumb_delta * encumb_impact * TUNING.armour.encumb_penalty_weight
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

local function send_armour_alert(it, alert_type)
  return f_pickup_alert.do_alert(it, alert_type.msg, alert_type.emoji, BRC.Config.fm_alert.body_armour)
end

-- Local functions: Pickup
local function pickup_body_armour(it)
  local cur = items.equipped_at("armour")
  if not cur then return false end -- surely am naked for a reason

  -- No pickup if either item is an artefact
  if cur.artefact or it.artefact then return false end

  -- No pickup if adding encumbrance or losing AC
  local encumb_delta = it.encumbrance - cur.encumbrance
  if encumb_delta > 0 then return false end

  local ac_delta = get_armour_ac(it) - get_armour_ac(cur)
  if ac_delta < 0 then return false end

  -- Pickup: Diff ego, Gain AC (w/o losing ego), Lower encumbrance (w/o losing ego)
  local it_ego = get_ego(it)
  local cur_ego = get_ego(cur)
  if cur_ego then
    if not it_ego then return false end
    return it_ego ~= cur_ego or ac_delta > 0 or encumb_delta < 0
  else
    return it_ego or ac_delta > 0 or encumb_delta < 0
  end
end

local function pickup_shield(it)
  local cur = items.equipped_at("offhand")

  -- Don't replace these
  if not BRC.is.shield(cur) then return false end
  if cur.encumbrance ~= it.encumbrance then return false end
  if cur.artefact then return false end

  -- Pickup: artefact
  if it.artefact then return true end

  -- Pickup: diff ego (w/o losing SH), gain ego, gain SH (w/o losing ego)
  local cur_ego = get_ego(cur)
  local it_ego = get_ego(it)
  if cur_ego then
    if it_ego == cur_ego then return it.plus > cur.plus end
    return it_ego and it.plus >= cur.plus
  end
  return it_ego or it.plus > cur.plus
end

local function pickup_aux_armour(it)
  -- Pickup: Anything if the slot is empty
  if aux_slot_is_impaired(it) then return false end
  -- Use a list to support Poltergeists; for most races it's a 1-item list
  local st = it.subtype()
  local all_equipped, num_slots = BRC.get.equipped_aux(st)
  if #all_equipped < num_slots then
    -- If we're carrying one (implying a blocking mutation), don't pickup another
    if #all_equipped == 0 and num_slots == 1 then
      for inv in iter.invent_iterator:new(items.inventory()) do
        if inv.subtype() == st then return false end
      end
    end

    return true
  end

  -- Pickup: artefact, unless slot(s) already full of artefact(s)
  for i, cur in ipairs(all_equipped) do
    if not cur.artefact then break end
    if i == num_slots then return false end
  end
  if it.is_identified and it.artefact then return true end

  -- Pickup: gain ego, gain AC (w/o losing ego), diff ego (w/o losing AC)
  local it_ac = get_armour_ac(it)
  local it_ego = get_ego(it)
  for _, cur in ipairs(all_equipped) do
    local cur_ac = get_armour_ac(cur)
    local cur_ego = get_ego(cur)
    if cur_ego then
      if it_ego then
        if it_ac > cur_ac then return true end
        if it_ac == cur_ac and it_ego ~= cur_ego then return true end
      end
    else
      if it_ego or it_ac > cur_ac then return true end
    end
  end
end

-- Local functions: Alerting
local function should_alert_body_armour(weight, gain, loss, ego_change)
  local meets_ratio = loss <= 0 or (gain / loss > TUNING.armour[weight][ego_change])
  if not meets_ratio then return false end

  -- Additional ego-specific restrictions
  if is_new_ego(ego_change) then
    return loss <= TUNING.armour[weight].max_loss
  elseif ego_change == LOST then
    return gain >= TUNING.armour[weight].min_gain
  end

  return true
  -- local function should_alert_lighter_armour(ac_delta, ev_delta, ego_change)
  --     local meets_ratio = ac_delta >= 0 or (ev_delta / -ac_delta > TUNING.armour.lighter[ego_change])
  --     if not meets_ratio then return false end

  --     -- Apply ego-specific restrictions
  --     if ego_change == LOST and ev_delta < TUNING.armour.lighter.min_gain then return false end
  --     if ego_change ~= SAME and -ac_delta > TUNING.armour.lighter.max_loss then return false end

  --     return true
  -- end

  -- local function should_alert_heavier_armour(ac_delta, ev_delta, ego_change)
  --     local meets_ratio = ev_delta >= 0 or (ac_delta / -ev_delta > TUNING.armour.heavier[ego_change])
  --     if not meets_ratio then return false end

  --     -- Apply ego-specific restrictions
  --     if ego_change == LOST and ac_delta < TUNING.armour.heavier.min_gain then return false end
  --     if ego_change ~= SAME and -ev_delta > TUNING.armour.heavier.max_loss then return false end

  --     return true
  -- end
end

-- If training armour in early/mid game, alert user to any armour that is the strongest found so far
local function alert_ac_high_score(it)
  if not BRC.is.body_armour(it) then return false end
  if you.skill("Armour") == 0 then return false end
  if you.xl() > 12 then return false end

  if ac_high_score == 0 then
    local worn = items.equipped_at("armour")
    if not worn then return false end
    ac_high_score = get_armour_ac(worn)
  else
    local itAC = get_armour_ac(it)
    if itAC > ac_high_score then
      ac_high_score = itAC
      return f_pickup_alert.do_alert(it, "Highest AC", EMOJI.STRONGEST, BRC.Config.fm_alert.high_score_armour)
    end
  end

  return false
end

local function alert_body_armour(it)
  local cur = items.equipped_at("armour")
  if not cur then return false end

  -- Always alert artefacts once identified
  if it.artefact then
    if not it.is_identified then return false end
    return send_armour_alert(it, ARMOUR_ALERT.artefact)
  end

  -- Get changes to ego, AC, EV, encumbrance
  local it_ego = get_ego(it)
  local cur_ego = get_ego(cur)
  local ego_change = get_ego_change_type(cur_ego, it_ego)
  local ac_delta = get_armour_ac(it) - get_armour_ac(cur)
  local ev_delta = get_armour_ev(it) - get_armour_ev(cur)
  local encumb_delta = it.encumbrance - cur.encumbrance

  -- Alert new egos if same encumbrance, or small change to total (AC+EV)
  if is_new_ego(ego_change) then
    if encumb_delta == 0 then return send_armour_alert(it, ARMOUR_ALERT[ego_change]) end

    local weight = encumb_delta < 0 and LIGHTER or HEAVIER
    if math.abs(ac_delta + ev_delta) <= TUNING.armour[weight].ignore_small then
      return send_armour_alert(it, ARMOUR_ALERT[weight][ego_change])
    end
  end

  -- Alert for lighter/heavier armour, based on configured AC/EV ratio
  if encumb_delta < 0 then
    if should_alert_body_armour(LIGHTER, ev_delta, -ac_delta, ego_change) then
      return send_armour_alert(it, ARMOUR_ALERT.lighter[ego_change])
    end
  elseif encumb_delta > 0 then
    local adj_ev_delta = get_adjusted_ev_delta(encumb_delta, ev_delta)
    if should_alert_body_armour(HEAVIER, ac_delta, -adj_ev_delta, ego_change) then
      return send_armour_alert(it, ARMOUR_ALERT.heavier[ego_change])
    end
  end

  -- Alert for highest AC found so far, or early armour with any ego
  if alert_ac_high_score(it) then return true end
  if it_ego and you.xl() <= TUNING.armour.early_xl then
    return f_pickup_alert.do_alert(it, "Early armour", EMOJI.EGO)
  end
end

local function alert_shield(it)
  if it.artefact then
    if not it.is_identified then return false end
    return f_pickup_alert.do_alert(it, "Artefact shield", EMOJI.ARTEFACT, BRC.Config.fm_alert.shields)
  end

  -- Don't alert shields if not wearing one (one_time_alerts fire for the first of each type)
  local cur = items.equipped_at("offhand")
  if not BRC.is.shield(cur) then return false end

  -- Alert: New ego, Gain SH
  local ego_change = get_ego_change_type(get_ego(cur), get_ego(it))
  if is_new_ego(ego_change) then
    local alert_msg = ego_change == DIFF and "Diff ego" or "Gain ego"
    return f_pickup_alert.do_alert(it, alert_msg, EMOJI.EGO, BRC.Config.fm_alert.shields)
  elseif get_shield_sh(it) > get_shield_sh(cur) then
    return f_pickup_alert.do_alert(it, "Higher SH", EMOJI.STRONGER, BRC.Config.fm_alert.shields)
  end
end

local function alert_aux_armour(it, unworn_inv_item)
  if it.artefact then
    if not it.is_identified then return false end
    return f_pickup_alert.do_alert(it, "Artefact aux armour", EMOJI.ARTEFACT, BRC.Config.fm_alert.aux_armour)
  end

  -- Use a list to support Poltergeists; for other races it's a 1-item list
  local all_equipped, num_slots = BRC.get.equipped_aux(it.subtype())
  if #all_equipped < num_slots then
    if unworn_inv_item then
      all_equipped[#all_equipped + 1] = unworn_inv_item
    else
      -- Catch dangerous brands or items blocked by non-innate mutations
      return f_pickup_alert.do_alert(it, "Aux armour", EMOJI.EXCLAMATION, BRC.Config.fm_alert.aux_armour)
    end

    local it_ego = get_ego(it)
    for _, cur in ipairs(all_equipped) do
      local ego_change = get_ego_change_type(get_ego(cur), it_ego)
      if is_new_ego(ego_change) then
        local alert_msg = ego_change == DIFF and "Diff ego" or "Gain ego"
        return f_pickup_alert.do_alert(it, alert_msg, EMOJI.EGO, BRC.Config.fm_alert.aux_armour)
      elseif get_armour_ac(it) > get_armour_ac(cur) then
        return f_pickup_alert.do_alert(it, "Higher AC", EMOJI.STRONGER, BRC.Config.fm_alert.aux_armour)
      end
    end
  end
end


-- Hook functions
-- Equipment autopickup (by Medar, gammafunk, buehler, and various others)
function pa_pickup_armour(it)
  if BRC.is.risky_ego(it) then return false end

  if BRC.is.body_armour(it) then
    return pickup_body_armour(it)
  elseif BRC.is.shield(it) then
    return pickup_shield(it)
  else
    return pickup_aux_armour(it)
  end
end

--[[
    Alerts armour items that didn't auto-pickup but are worth consideration.
    This comes after pickup, so there will be no pure upgrades.
    Optional `unworn_inv_item` param, to compare against an unworn aux armour item in inventory.
--]]
function pa_alert_armour(it, unworn_inv_item)
  if BRC.is.body_armour(it) then
    return alert_body_armour(it)
  elseif BRC.is.shield(it) then
    return alert_shield(it)
  else
    return alert_aux_armour(it, unworn_inv_item)
  end
end
