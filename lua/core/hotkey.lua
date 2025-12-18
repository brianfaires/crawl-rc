---------------------------------------------------------------------------------------------------
-- BRC core feature: hotkey
-- @module BRC.Hotkey
-- Manages the BRC hotkey, and provides functions to add actions to it.
-- Adding an action to the hotkey will prompt the user after performing any specified checks.
-- If user accepts, the defined action is performed. (Equip, pick up, read, move to, etc)
---------------------------------------------------------------------------------------------------

BRC.Hotkey = {}
BRC.Hotkey.BRC_FEATURE_NAME = "hotkey"
BRC.Hotkey.Config = {
  key = { keycode = BRC.KEYS.ENTER, name = "[Enter]" },
  skip_keycode = BRC.KEYS.ESC,
  equip_hotkey = true, -- Offer to equip after picking up equipment
  wait_for_safety = true, -- Don't expire the hotkey with monsters in view
  explore_clears_queue = true, -- Clear the hotkey queue on explore
  newline_before_hotkey = true, -- Add a newline before the hotkey message
  move_to_feature = {
    -- Hotkey move to, for these features. Also includes all portal entrances if table is not nil.
    enter_temple = "Temple", enter_lair = "Lair", altar_ecumenical = "faded altar",
    enter_bailey = "flagged portal", enter_bazaar = "bazaar",
    enter_desolation = "crumbling gateway", enter_gauntlet = "gauntlet",
    enter_ice_cave = "frozen archway", enter_necropolis = "phantasmal passage",
    enter_ossuary = "sand-covered staircase", enter_sewer = "glowing drain",
    enter_trove = "trove of treasure", enter_volcano = "dark tunnel",
    enter_wizlab = "magical portal", enter_ziggurat = "ziggurat",
  },
} -- BRC.Hotkey.Config (do not remove this comment)

---- Local constants ----
local WAYPOINT_MUTES = {
  "Assign waypoint to what number",
  "Existing waypoints",
  "Delete which waypoint",
  "\\(\\d\\) ",
  "All waypoints deleted",
  "You're already here!",
  "Okay\\, then\\.",
  "Unknown command",
  "Waypoint \\d (re-)?assigned",
  "Waypoints will disappear",
} -- WAYPOINT_MUTES (do not remove this comment)

---- Local variables ----
local action_queue
local cur_action
local delay_expire

---- Initialization ----
function BRC.Hotkey.init()
  action_queue = {}
  cur_action = nil
  delay_expire = false

  BRC.opt.macro(BRC.Hotkey.Config.key.keycode, "macro_brc_hotkey")
  BRC.opt.macro(BRC.Hotkey.Config.skip_keycode, "macro_brc_skip_hotkey")
end

---- Local functions ----
local function display_cur_message()
  if BRC.Hotkey.Config.wait_for_safety and not you.feel_safe() then return end
  local msg = string.format("\n[BRC] Press %s to %s.", BRC.Hotkey.Config.key.name, cur_action.msg)
  BRC.mpr.que(msg, BRC.COL.darkgrey)
end

local function load_next_action()
  if #action_queue == 0 then return end
  cur_action = table.remove(action_queue, 1)
  if cur_action.condition() then
    cur_action.turn = you.turns() + 1
    display_cur_message()
    delay_expire = false
  else
    cur_action = nil
    load_next_action()
  end
end

local function expire_cur_action()
  if cur_action then cur_action.cleanup() end
  cur_action = nil
  load_next_action()
end

--- Get the highest available waypoint slot
local function get_avail_waypoint()
  for i = 9, 0, -1 do
    if not travel.waypoint_delta(i) then return i end
  end

  BRC.mpr.debug("No available waypoint slots. Clearing them all.")
  util.foreach(WAYPOINT_MUTES, function(m) BRC.opt.single_turn_mute(m) end)
  crawl.sendkeys({ BRC.util.cntl("w"), "d", "*" })
  crawl.flush_input()
end

---- Macro function: On BRC hotkey press ----
function macro_brc_hotkey()
  if cur_action then
    cur_action.action()
  else
    BRC.mpr.info("Unknown command (no action assigned to hotkey).")
  end
end

function macro_brc_skip_hotkey()
  if cur_action and (you.feel_safe() or not BRC.Hotkey.Config.wait_for_safety) then
    expire_cur_action()
    if not cur_action then BRC.mpr.info("Hotkey cleared.") end
  else
    crawl.sendkeys({ BRC.Hotkey.Config.skip_keycode })
    crawl.flush_input()
  end
end

---- Public API ----
--- Assign an action to the BRC hotkey
-- @param prefix string - The action (equip/pickup/read/etc)
-- @param suffix string - Printed after the action. Usually an item name
-- @param push_front boolean - Push the action to the front of the queue
-- @param f_action function - The function to call when the hotkey is pressed
-- @param f_condition (optional function) return bool - If the action is still valid
-- @param f_cleanup (optional function) - Function to call after hotkey pressed or skipped
-- @return nil
function BRC.Hotkey.set(prefix, suffix, push_front, f_action, f_condition, f_cleanup)
  local act = {
    msg = BRC.txt.lightgreen(prefix) .. (suffix and (" " .. BRC.txt.white(suffix)) or ""),
    action = f_action,
    condition = f_condition or function() return true end,
    cleanup = f_cleanup or function() end,
  } -- act (do not remove this comment)

  if push_front then
    table.insert(action_queue, 1, act)
  else
    table.insert(action_queue, act)
  end
end

function BRC.Hotkey.equip(it, push_front)
  if not (it.is_weapon or BRC.it.is_armour(it, true) or BRC.it.is_jewellery(it)) then return end
  local name = it.name():gsub(" {.*}", "")

  local condition = function()
    local inv_items = util.filter(function(i)
      return i.name():gsub(" {.*}", "") == name
    end, items.inventory())
    return util.exists(inv_items, function(i) return not i.equipped end)
  end

  local do_equip = function()
    local inv_items = util.filter(function(i)
      return i.name():gsub(" {.*}", "") == name
    end, items.inventory())

    local already_eq = false
    for i = 1, #inv_items do
      if inv_items[i].equipped then
        already_eq = true
      else
        inv_items[i]:equip()
        return
      end
    end

    if already_eq then
      BRC.mpr.info("Already equipped.")
    else
      BRC.mpr.error("Could not find unequipped item '" .. name .. "' in inventory.")
    end
  end

  BRC.Hotkey.set("equip", it.name(), push_front, do_equip, condition)
end

--- Pick up an item by name (Must use name, since item goes stale when called from equip hotkey)
function BRC.Hotkey.pickup(name, push_front)
  local condition = function()
    return util.exists(you.floor_items(), function(fl) return fl.name():contains(name) end)
  end

  local do_pickup = function()
    for _, fl in ipairs(you.floor_items()) do
      -- Check with contains() in case ID'ing it appends to the name
      if fl.name():contains(name) then
        items.pickup(fl)
        return
      end
    end
    BRC.mpr.info(name .. " isn't here!")
  end

  BRC.Hotkey.set("pickup", name, push_front, do_pickup, condition)
end

--- Set hotkey as 'move to <name>', if it's in LOS
-- If feature_name provided, moves to that feature, otherwise searches for the item by name
function BRC.Hotkey.waypoint(name, push_front, feature_name)
  if util.contains(BRC.PORTAL_FEATURE_NAMES, you.branch()) then
    return -- Can't auto-travel
  end

  local x, y
  if feature_name ~= nil then
    local r = you.los()
    for dx = -r, r do
      for dy = -r, r do
        if view.feature_at(dx, dy):contains(feature_name) then
          x, y = dx, dy
          break
        end
      end
    end
  else
    x, y = BRC.it.get_xy(name)
  end
  if x == nil then return BRC.mpr.debug(name .. " not found in LOS") end

  local waynum = get_avail_waypoint()
  if not waynum then return end
  util.foreach(WAYPOINT_MUTES, function(m) BRC.opt.single_turn_mute(m) end)
  travel.set_waypoint(waynum, x, y)

  local is_valid = function()
    local dx, dy = travel.waypoint_delta(waynum)
    return dx and not(dx == 0 and dy == 0)
  end

  local move_to_waypoint = function()
    f_pickup_alert.pause_alerts() -- Don't interrupt hotkey travel with new alerts
    crawl.sendkeys({ BRC.util.get_cmd_key("CMD_INTERLEVEL_TRAVEL"), tostring(waynum) })
    crawl.flush_input()
  end

  local clear_waypoint = function()
    local keys = { BRC.util.cntl("w"), "d", tostring(waynum) }
    -- If other waypoints exist, need to send ESC to exit the prompt
    for i = 0, 9 do
      if i ~= waynum and travel.waypoint_delta(i) then
        keys[#keys + 1] = BRC.KEYS.ESC
      end
    end

    util.foreach(WAYPOINT_MUTES, function(m) BRC.opt.single_turn_mute(m) end)
    crawl.sendkeys(keys)

    if not feature_name then
      BRC.Hotkey.pickup(name, true)
    end
  end

  BRC.Hotkey.set("move to", name, push_front, move_to_waypoint, is_valid, clear_waypoint)
end

---- Crawl hook functions ----
function BRC.Hotkey.c_assign_invletter(it)
  if BRC.Hotkey.Config.equip_hotkey then BRC.Hotkey.equip(it, true) end
end

function BRC.Hotkey.ch_start_running(kind)
  if BRC.Hotkey.Config.explore_clears_queue and kind:contains("explore") then
    action_queue = {}
    cur_action = nil
  end
end

function BRC.Hotkey.c_message(text, channel)
  if channel ~= "plain" then return end
  if BRC.Hotkey.Config.move_to_feature == nil then return end
  if not text:contains("Found") then return end

  for k, v in pairs(BRC.Hotkey.Config.move_to_feature) do
    if text:contains(v) then
      BRC.Hotkey.waypoint(v, true, k)
    end
  end
  for k, v in pairs(BRC.PORTAL_FEATURE_NAMES) do
    if text:contains(v) then
      BRC.Hotkey.waypoint(v, true, k)
    end
  end
end

function BRC.Hotkey.ready()
  if cur_action == nil then
    load_next_action()
  elseif cur_action.turn > you.turns() then
    return
  elseif BRC.Hotkey.Config.wait_for_safety and not you.feel_safe() and cur_action.condition() then
    delay_expire = true
  elseif delay_expire and you.feel_safe() then
    delay_expire = false
    display_cur_message()
  else
    expire_cur_action()
  end
end
