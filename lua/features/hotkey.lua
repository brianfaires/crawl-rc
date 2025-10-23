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
  autoequip = true,
} -- f_hotkey.Config (do not remove this comment)

---- Config alias ----
local Config = f_hotkey.Config

---- Local variables ----
local _action_queue = {}
local _cur_action = nil

---- Local functions ----
local function load_next_action()
  if #_action_queue == 0 then return end
  _cur_action = _action_queue[1]
  _cur_action.t = you.turns() + cur_action.t
  table.remove(_action_queue, 1)
  local msg = string.format("[BRC] Press %s to %s.", Config.key.name, _cur_action.m)
  BRC.mpr.que(msg, BRC.COL.cyan)
end

local function set_autoequip_hotkey(it)
  if not (it.is_weapon or BRC.is.armour(it) or BRC.is.jewellery(it)) then return end
  local NAME = it.name():gsub(" {.*}", "")

  BRC.set_hotkey("equip", NAME, function()
    local inv_items = util.filter(function(i)
      return i.name():gsub(" {.*}", "") == NAME
    end, items.inventory())

    local already_eq = false
    for i = 1, #inv_items do
      if not inv_items[i].equipped then
        inv_items[i]:equip()
        return
      else
        already_eq = true
      end
    end

    if already_eq then
      BRC.mpr.darkgrey("Already equipped.")
    else
      BRC.log.error("Could not find unequipped item '" .. NAME .. "' in inventory.")
    end
  end, 1, true)
end

---- Macro function: On BRC hotkey press ----
function macro_brc_hotkey()
  if _cur_action then
    _cur_action.f()
    _cur_action = nil
  else
    BRC.mpr.darkgrey("Unknown command (no actions assigned to BRC hotkey).")
  end
end

---- Public API ----
--- Assign an action to the BRC hotkey
--- @param msg_action string - The action (equip/pickup/read/etc)
--- @param msg_suffix string - Printed after the action. Usually an item name
--- @param func function - The function to call when the hotkey is pressed
--- @param turns number - The number of turns to wait before skipping this action
--- @param push_front boolean - Push the action to the front of the queue
--- @return nil
function BRC.set_hotkey(msg_action, msg_suffix, func, turns, push_front)
  crawl.mpr("adding to queue of size " .. #_action_queue)
  local act = { m = BRC.text.lightgreen(msg_action), f = func, t = turns or 1 }
  if msg_suffix then act.m = act.m .. " " .. BRC.text.white(msg_suffix) end
  if push_front then
    crawl.mpr("pushed front")
    table.insert(_action_queue, 1, act)
  else 
    crawl.mpr("pushed back")
    table.insert(_action_queue, act)
  end

  for i, aaa in ipairs(_action_queue) do
    crawl.mpr("\naction " .. i .. ": " .. aaa.m)
  end
  
   -- Display this message now, and give it an extra turn to accept
  if #_action_queue == 1 and _cur_action == nil then
    act.t = act.t + 1
    load_next_action()
  end
end

function BRC.set_pickup_hotkey(name, push_front)
  crawl.mpr("setting pickup hotkey for: " .. name)
  BRC.set_hotkey("pickup", name, function()
    for _, fl in ipairs(you.floor_items()) do
      crawl.mpr("checking item: " .. fl.name())
      if fl.name() == name then
        items.pickup(fl)
        return
      end
    end
    BRC.mpr.darkgrey(name .. " isn't here!")
  end, 1, push_front)
  crawl.mpr("done setting pickup hotkey for: " .. name)
end

function BRC.set_waypoint_hotkey(name, push_front)
  local x, y = BRC.get.item_xy(name)
  if x == nil then
    BRC.log.debug(name .. " not found in LOS")
    return
  end

  local waynum = nil
  for i = 9, 0, -1 do
    if not travel.waypoint_delta(i) then
      BRC.set.single_turn_mute("Waypoint \\d assigned")
      travel.set_waypoint(i, x, y)
      waynum = i
      break
    end
  end
  if not waynum then
    BRC.log.debug("No available waypoint slots")
    return
  end

  crawl.mpr("setting waypoint hotkey for: " .. name .. " with push_front: " .. tostring(push_front))
  BRC.set_hotkey("move to", name, function()
    f_pickup_alert.pause_alerts() -- Don't interrupt hotkey travel with new alerts
    crawl.sendkeys({ BRC.get.command_key("CMD_INTERLEVEL_TRAVEL"), tostring(waynum) })

    -- Delete waypoint after travel, silencing the associated messages
    crawl.sendkeys({ BRC.util.cntl("w"), "d", tostring(waynum), BRC.KEYS.ESC })
    BRC.set.single_turn_mute("Assign waypoint to what number")
    BRC.set.single_turn_mute("Existing waypoints")
    BRC.set.single_turn_mute("Delete which waypoint")
    BRC.set.single_turn_mute("\\(\\d\\) ")
    BRC.set.single_turn_mute("All waypoints deleted")
    BRC.set.single_turn_mute("You're already here!")
    BRC.set.single_turn_mute("Okay\\, then\\.")
    BRC.set.single_turn_mute("Unknown command")

    BRC.set_pickup_hotkey(name, true)
    crawl.mpr("setting pickup hotkey for: " .. name)
  end, 1, push_front)
end

---- Hook functions ----
function f_hotkey.init()
  BRC.set.macro("\\{" .. Config.key.keycode .. "}", "macro_brc_hotkey")
end

function f_hotkey.c_assign_invletter(it)
  if Config.autoequip then set_autoequip_hotkey(it) end
end

function f_hotkey.ready()
  if _cur_action == nil or _cur_action.t <= you.turns() then
    _cur_action = nil
    load_next_action()
  end
end
