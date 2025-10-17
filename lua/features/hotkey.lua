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
local _actions = {}

---- Local functions ----
local function display_next_message()
  if #_actions == 0 then return end
  local msg = string.format("[BRC] Press %s to %s.", Config.key.name, _actions[1].m)
  BRC.mpr.que(msg, BRC.COL.cyan)
  _actions[1].m = nil
end

local function c_assign_invletter_autoequip(it)
  if not (it.is_weapon or BRC.is.armour(it) or BRC.is.jewellery(it)) then return end
  local TURNS = 1
  local name = it.name():gsub(" {.*}", "")

  BRC.set_hotkey("equip " .. BRC.text.white(name), function()
    local inv_items = util.filter(function(i)
      return i.name():gsub(" {.*}", "") == name
    end, items.inventory())

    for i = 1, #inv_items do
      if not inv_items[i].equipped then
        inv_items[i]:equip()
        return
      end
    end

    BRC.log.error("Could not find unequipped item '" .. name .. "' in inventory")
  end, TURNS)
end

---- Public API ----
function BRC.set_hotkey(msg, func, turns)
  local act = { m = msg, f = func, t = turns or 1 }
  table.insert(_actions, act)
  if #_actions == 1 then
    display_next_message()
    act.t = act.t + 1 -- Extra turn cause we're displaying msg a turn early
  end
end

function macro_brc_hotkey()
  if #_actions > 0 then
    _actions[1].f()
    table.remove(_actions, 1)
  else
    BRC.mpr.darkgrey("Unknown command (no actions assigned to BRC hotkey).")
  end
end

---- Hook functions ----
function f_hotkey.init()
  BRC.set.macro("\\{" .. Config.key.keycode .. "}", "macro_brc_hotkey")
end

function f_hotkey.c_assign_invletter(it)
  if Config.autoequip then c_assign_invletter_autoequip(it) end
end

function f_hotkey.ready()
  if #_actions == 0 then return end
  if _actions[1].m then
    display_next_message()
  else
    _actions[1].t = _actions[1].t - 1
    if _actions[1].t <= 0 then
      table.remove(_actions, 1)
      f_hotkey.ready()
    end
  end
end
