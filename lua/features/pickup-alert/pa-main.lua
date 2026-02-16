---------------------------------------------------------------------------------------------------
-- BRC feature module: pickup-alert
-- @module f_pickup_alert
-- Comprehensive pickup and alert system for weapons, armour, and miscellaneous items.
-- Several submodules: pa-config, pa-data, pa-armour, pa-weapons, pa-misc.
---------------------------------------------------------------------------------------------------

f_pickup_alert = f_pickup_alert or {}
f_pickup_alert.BRC_FEATURE_NAME = "pickup-alert"

---- Local variables ----
local C -- config alias
local A -- alert config alias
local M -- more config alias
local pause_pa_system
local hold_alerts_for_next_turn
local pa_last_ready_turn
local function_queue -- queue of actions for next ready()
local marked_stacks
local last_stack_check_turn

---- Initialization ----
function f_pickup_alert.init()
  C = f_pickup_alert.Config
  A = f_pickup_alert.Config.Alert
  M = f_pickup_alert.Config.Alert.More
  pause_pa_system = false
  hold_alerts_for_next_turn = false
  pa_last_ready_turn = you.turns()
  function_queue = {}
  marked_stacks = {}
  last_stack_check_turn = -1

  BRC.mpr.debug("Initialize pickup-alert submodules...")
  if f_pa_data.init then f_pa_data.init() end
  BRC.mpr.debug("  pa-data loaded")

  if f_pa_armour then
    if f_pa_armour.init then f_pa_armour.init() end
    BRC.mpr.debug("  pa-armour loaded")
  end

  if f_pa_weapons then
    if f_pa_weapons.init then f_pa_weapons.init() end
    BRC.mpr.debug("  pa-weapons loaded")
  end

  if f_pa_misc then
    if f_pa_misc.init then f_pa_misc.init() end
    BRC.mpr.debug("  pa-misc loaded")
  end

  -- Don't alert for starting items
  for _, inv in ipairs(items.inventory()) do
    f_pa_data.remember_alert(inv)
    f_pa_data.remove_OTA(inv)
  end
end

---- Local functions ----
local function has_configured_force_more(it)
  if it.artefact then
    if M.artefact then return true end
    if M.trained_artefacts then
      -- Accept artefacts with any relevant training, or no training required
      local s = BRC.you.skill_with(it)
      if s == nil or s > 0 then return true end
    end
  end

  return M.armour_ego and BRC.it.is_armour(it) and BRC.eq.get_ego(it)
end

local function track_unique_egos(it)
  local ego = BRC.eq.get_ego(it)
  if
    ego
    and not util.contains(pa_egos_alerted, ego)
    and not (it.artefact and BRC.eq.is_risky(it))
  then
    pa_egos_alerted[#pa_egos_alerted+1] = ego
  end
end

local function get_alert_color_for_item(it)
  if it.is_weapon then return C.AlertColor.weapon end
  if BRC.it.is_orb(it) then return C.AlertColor.orb end
  if BRC.it.is_talisman(it) then return C.AlertColor.talisman end
  if BRC.it.is_body_armour(it) then return C.AlertColor.body_arm end
  if BRC.it.is_armour(it) then return C.AlertColor.aux_arm end
  return C.AlertColor.misc
end

local function should_skip_pickup_check(it)
  return BRC.active == false
    or pause_pa_system
    or you.have_orb()
    or (not it.is_identified and (it.branded or it.artefact or BRC.it.is_magic_staff(it)))
end

local function check_and_trigger_alerts(it, unworn_aux_item)
  if f_pa_data.already_alerted(it) then return true end

  -- One-time alerts
  if f_pa_misc and A.one_time and #A.one_time > 0 then
    if f_pa_misc.alert_OTA(it) then return true end
  end

  -- Item-specific alerts
  if BRC.it.is_magic_staff(it) and f_pa_misc and A.staff_resists then
    if f_pa_misc.alert_staff(it) then return true end
  elseif BRC.it.is_orb(it) and f_pa_misc and A.orbs then
    if f_pa_misc.alert_orb(it) then return true end
  elseif BRC.it.is_talisman(it) and f_pa_misc and A.talismans then
    if f_pa_misc.alert_talisman(it) then return true end
  elseif BRC.it.is_armour(it) and f_pa_armour and A.armour_sensitivity > 0 then
    if f_pa_armour.alert_armour(it, unworn_aux_item) then return true end
  elseif it.is_weapon and f_pa_weapons and A.weapon_sensitivity > 0 then
    if f_pa_weapons.alert_weapon(it) then return true end
  end

  return false
end

--- Run autopickup for all items in view, even those hidden in an item stack.
-- Pickup-alert system runs as an autopickup function, which only triggers for stacked items when:
-- 1. The stack is visited, 2. autopickup is on.
-- This hiding behavior is very annoying when not autoexploring, ie always for turncount runs.
-- This function causes alerts to fire without visiting the stack. No impact on autoexplore.
-- Also tracks which stacks these are, so we can trick the UI into highlighting them as autopickup.
local function mark_stacked_items()
  marked_stacks = {}
  local unmarked_item_counts = {}
  local r = you.los()

  for x = -r, r do
    for y = -r, r do
      if you.see_cell(x, y) then
        local items_xy = items.get_items_at(x, y)
        if items_xy then
          local top_item_name = items_xy[1].name()
          unmarked_item_counts[top_item_name] = (unmarked_item_counts[top_item_name] or 0) + 1
          if #items_xy > 1 then
            for i, it in ipairs(items_xy) do
              if i > 1 and f_pickup_alert.autopickup(it) then
                marked_stacks[#marked_stacks + 1] = {x, y, top_item_name, it.name()}
                unmarked_item_counts[top_item_name] = unmarked_item_counts[top_item_name] - 1
                if not f_pa_data.already_alerted(it) then
                  f_pickup_alert.do_alert(
                    it, "Hidden under stack", C.Emoji.AUTOPICKUP_ITEM, M.autopickup_disabled
                  )
                end
              end
            end
          end
        end
      end
    end
  end

  -- In autopickup, there's no way to differentiate between items of the same name.
  -- Can't get its coordinates, can't see what's underneath it, etc.
  -- Choosing to not mark stacks w duplicated item names, rather than mark all items for autopickup
  for i = #marked_stacks, 1, -1 do
    if unmarked_item_counts[marked_stacks[i][3]] > 0 then
      table.remove(marked_stacks, i)
    end
  end
end

--- This is used to trick the UI into highlighting a stack for autopickup.
-- Since this is called from autopickup(), there's no way to differentiate items of the same name.
local function is_top_of_marked_stack(it)
  if last_stack_check_turn < you.turns() then
    last_stack_check_turn = you.turns()
    mark_stacked_items()
  end

  for _, stack in ipairs(marked_stacks) do
    local stack_items = items.get_items_at(stack[1], stack[2])
    if not stack_items or stack_items[1].name() ~= stack[3] then
      -- Stack coordinates are stale
      mark_stacked_items()
      return is_top_of_marked_stack(it)
    end
    if it.name() == stack[3] then
      for i = 2, #stack_items do
        if stack_items[i].name() == stack[4] then return true end
      end
    end
  end
  return false
end

---- Public API ----
function f_pickup_alert.pause_alerts()
  hold_alerts_for_next_turn = true
end

function f_pickup_alert.is_paused()
  return pause_pa_system or hold_alerts_for_next_turn
end

function f_pickup_alert.do_alert(it, alert_type, emoji, force_more)
  local item_name = f_pa_data.get_keyname(it, true)
  local alert_col = get_alert_color_for_item(it)

  -- Handle special formatting for weapons and body armour
  if it.is_weapon then
    f_pa_data.update_high_scores(it)
    local weapon_info = string.format(" (%s)", BRC.eq.wpn_stats(it))
    item_name = item_name .. BRC.txt[C.AlertColor.weapon.stats](weapon_info)
  elseif BRC.it.is_armour(it) then
    track_unique_egos(it)
    if BRC.it.is_body_armour(it) then
      f_pa_data.update_high_scores(it)
      local ac, ev = BRC.eq.arm_stats(it)
      local armour_info = string.format(" {%s, %s}", ac, ev)
      item_name = item_name .. BRC.txt[C.AlertColor.body_arm.stats](armour_info)
    end
  end

  local tokens = {}
  tokens[1] = emoji and emoji or BRC.txt.cyan("----")
  tokens[#tokens + 1] = BRC.txt[alert_col.desc](string.format(" %s:", alert_type))
  tokens[#tokens + 1] = BRC.txt[alert_col.item](string.format(" %s ", item_name))
  tokens[#tokens + 1] = tokens[1]
  BRC.mpr.que_optmore(force_more or has_configured_force_more(it), table.concat(tokens))

  f_pa_data.add_recent_alert(it)
  f_pa_data.remember_alert(it)

  if not hold_alerts_for_next_turn then you.stop_activity() end

  local it_name = it.name()
  function_queue[#function_queue + 1] = function()
    -- Set hotkeys (on next turn, so player position is updated before setting waypoint)
    if util.exists(you.floor_items(), function(fl) return fl.name() == it_name end) then
      if A.hotkey_pickup and BRC.Hotkey then BRC.Hotkey.pickup(it_name, true) end
    else
      if A.hotkey_travel and BRC.Hotkey then
        BRC.Hotkey.move_to_item(it_name, false, A.hotkey_pickup)
      end
    end
  end

  return true
end

---- Crawl hook functions ----
function f_pickup_alert.autopickup(it, _)
  if A.stacked_items and is_top_of_marked_stack(it) then
    -- Fake autopickup to highlight the stack. Don't actually pick it up!
    local fl = you.floor_items()
    if not fl or #fl <= 1 or fl[1].name() ~= it.name() then return true end
  end
  if should_skip_pickup_check(it) then return end

  local unworn_aux_item = nil -- Track carried aux armour for mutation scenarios
  if it.is_useless then
    -- Allow alerts for useless aux armour, iff you're carrying one (implies a temporary mutation)
    if not BRC.it.is_aux_armour(it) then return end
    local st = it.subtype()
    for _, inv in ipairs(items.inventory()) do
      if inv.subtype() == st then
        unworn_aux_item = inv
        break
      end
    end
    if not unworn_aux_item then return end
  else
    if BRC.it.is_armour(it) then
      if C.Pickup.armour and f_pa_armour.pickup_armour(it) then return true end
    elseif BRC.it.is_magic_staff(it) then
      if C.Pickup.staves and f_pa_misc.pickup_staff(it) then return true end
    elseif it.is_weapon then
      if C.Pickup.weapons and f_pa_weapons.pickup_weapon(it) then return true end
    elseif f_pa_misc and f_pa_misc.is_unneeded_ring(it) then
      return false
    end
  end

  -- Item not picked up - check if it should trigger alerts.
  -- Autopickup fires many times per turn, and needs to consistently return true for pickup to work
  -- But, only check for alerts immediately after turncount changes, before ready() is called.
  if you.turns() ~= pa_last_ready_turn then
    check_and_trigger_alerts(it, unworn_aux_item)
  end
end

function f_pickup_alert.c_assign_invletter(it)
  f_pa_misc.alert_OTA(it)
  f_pa_data.remove_recent_alert(it)
  f_pa_data.remember_alert(it)

  -- Re-enable the alert, iff we are able to use another one
  if BRC.you.num_eq_slots(it) > 1 then f_pa_data.forget_alert(it) end

  -- Ensure we always stop for these autopickup types
  if it.is_weapon or BRC.it.is_armour(it) then
    f_pa_data.update_high_scores(it)
    you.stop_activity()
  end
end

function f_pickup_alert.c_message(text, channel)
  -- Avoid firing alerts when changing armour/weapons
  if channel == "multiturn" then
    if not pause_pa_system and text:contains("ou start ") then pause_pa_system = true end
  elseif channel == "plain" then
    if pause_pa_system and (text:contains("ou stop ") or text:contains("ou finish ")) then
      pause_pa_system = false
    elseif text:contains("one exploring") or text:contains("artly explored") then
      local tokens = { "Recent alerts:" }
      for _, v in ipairs(pa_recent_alerts) do
        tokens[#tokens + 1] = string.format("\n  %s", v)
      end
      if #tokens > 1 then BRC.mpr.que(table.concat(tokens), BRC.COL.magenta) end
      pa_recent_alerts = {}
    end
  end
end

function f_pickup_alert.ready()
  hold_alerts_for_next_turn = false
  pa_last_ready_turn = you.turns()
  util.foreach(function_queue, function(f) f() end)
  function_queue = {}

  if pause_pa_system then return end
  f_pa_weapons.ready()
  f_pa_data.update_high_scores(items.equipped_at("armour"))
end
