--[[
Feature: hotkey
Description: Configures a BRC hotkey that features can assign actions to
Author: buehler
Dependencies: core/data.lua, core/util.lua
--]]

f_hotkey = {}
f_hotkey.BRC_FEATURE_NAME = "hotkey"
f_hotkey.Config = {
  key = { keycode = "13", name = "[Enter]" },
  skip_keycode = BRC.KEYS.ESC,
  equip_hotkey = true,
} -- f_hotkey.Config (do not remove this comment)

---- Config alias ----
local Config = f_hotkey.Config

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
  --"Waypoint \\d re-assigned",
} -- WAYPOINT_MUTES (do not remove this comment)

---- Local variables ----
local action_queue
local cur_action

---- Local functions ----
local function load_next_action()
  if #action_queue == 0 then return end
  cur_action = action_queue[1]
  cur_action.t = you.turns() + cur_action.t
  table.remove(action_queue, 1)
  local msg = string.format("[BRC] Press %s to %s.", Config.key.name, cur_action.m)
  BRC.mpr.que(msg, BRC.COL.darkgrey)
end

local function expire_cur_action()
  if cur_action and cur_action.c then cur_action.c() end
  cur_action = nil
  load_next_action()
end

local function get_avail_waypoint()
  for i = 9, 0, -1 do
    if not travel.waypoint_delta(i) then return i end
  end

  BRC.mpr.debug("No available waypoint slots. Clearing them.")
  util.foreach(WAYPOINT_MUTES, function(m) BRC.opt.single_turn_mute(m) end)
  crawl.sendkeys({ BRC.util.cntl("w"), "d", "*" })
  crawl.flush_input()
  return 9
end

---- Macro function: On BRC hotkey press ----
function macro_brc_hotkey()
  if cur_action then
    cur_action.f()
    cur_action = nil
  else
    BRC.mpr.darkgrey("Unknown command (no actions assigned to BRC hotkey).")
  end
end

function macro_brc_skip_hotkey()
  if cur_action then
    expire_cur_action()
    if not cur_action then BRC.mpr.darkgrey("[BRC] Hotkey cleared.") end
  else
    crawl.sendkeys({ Config.skip_keycode })
  end
end

---- Public API ----
--- Assign an action to the BRC hotkey
-- @param msg_action string - The action (equip/pickup/read/etc)
-- @param msg_suffix string - Printed after the action. Usually an item name
-- @param func function - The function to call when the hotkey is pressed
-- @param turns number - The number of turns to wait before skipping this action
-- @param push_front boolean - Push the action to the front of the queue
-- @param cleanup optional function - Function to call when the hotkey is not pressed
-- @return nil
function BRC.set_hotkey(msg_action, msg_suffix, func, turns, push_front, cleanup)
  local act = { m = BRC.txt.lightgreen(msg_action), f = func, t = turns or 1 }
  if msg_suffix then act.m = act.m .. " " .. BRC.txt.white(msg_suffix) end
  if cleanup then act.c = cleanup end

  if push_front then
    table.insert(action_queue, 1, act)
  else
    table.insert(action_queue, act)
  end

  -- If possible, load the action on same turn as the alert that triggered it
  if #action_queue == 1 and cur_action == nil then
    act.t = act.t + 1
    load_next_action()
  end
end

function BRC.set_pickup_hotkey(name, push_front)
  local do_pickup = function()
    for _, fl in ipairs(you.floor_items()) do
      if fl.name() == name then
        items.pickup(fl)
        return
      end
    end
    BRC.mpr.darkgrey(name .. " isn't here!")
  end

  BRC.set_hotkey("pickup", name, do_pickup, 1, push_front)
end

function BRC.set_equip_hotkey(it, push_front)
  if not (it.is_weapon or BRC.it.is_armour(it) or BRC.it.is_jewellery(it)) then return end
  local NAME = it.name():gsub(" {.*}", "")

  local do_equip = function()
    local inv_items = util.filter(function(i)
      return i.name():gsub(" {.*}", "") == NAME
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
      BRC.mpr.darkgrey("Already equipped.")
    else
      BRC.mpr.error("Could not find unequipped item '" .. NAME .. "' in inventory.")
    end
  end

  BRC.set_hotkey("equip", NAME, do_equip, 1, push_front)
end

function BRC.set_waypoint_hotkey(name, push_front)
  local x, y = BRC.it.get_xy(name)
  if x == nil then return BRC.mpr.debug(name .. " not found in LOS") end

  local waynum = get_avail_waypoint()
  BRC.opt.single_turn_mute("Waypoint \\d assigned")
  travel.set_waypoint(waynum, x, y)

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
    crawl.flush_input()
  end

  local move_to_waypoint = function()
    f_pickup_alert.pause_alerts() -- Don't interrupt hotkey travel with new alerts
    crawl.sendkeys({ BRC.util.get_cmd_key("CMD_INTERLEVEL_TRAVEL"), tostring(waynum) })

    -- Delete waypoint after travel, silence the prompts, push a pickup hotkey
    crawl.sendkeys({ BRC.util.cntl("w"), "d", tostring(waynum), BRC.KEYS.ESC })
    util.foreach(WAYPOINT_MUTES, function(m) BRC.opt.single_turn_mute(m) end)

    BRC.set_pickup_hotkey(name, true)
  end

  BRC.set_hotkey("move to", name, move_to_waypoint, 1, push_front, clear_waypoint)
end

---- Hook functions ----
function f_hotkey.init()
  action_queue = {}
  cur_action = nil

  BRC.opt.macro("\\{" .. Config.key.keycode .. "}", "macro_brc_hotkey")
  BRC.opt.macro("\\{" .. Config.skip_keycode .. "}", "macro_brc_skip_hotkey")
end

function f_hotkey.c_assign_invletter(it)
  if Config.equip_hotkey then BRC.set_equip_hotkey(it, true) end
end

function f_hotkey.ready()
  if cur_action == nil or cur_action.t <= you.turns() then
    expire_cur_action()
  end
end
