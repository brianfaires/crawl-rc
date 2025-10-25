--[[
Feature: weapon-slots
Description: Automatically keeps weapons in slots a/b/w. Prioritizes slots by weapon type + skill.
Author: buehler
Dependencies: core/util.lua
--]]

f_weapon_slots = {}
f_weapon_slots.BRC_FEATURE_NAME = "weapon-slots"

---- Local variables ----
local do_cleanup_weapon_slots
local slots_changed
local priorities_ab
local priorities_w

---- Local functions ----
local function get_first_empty_slot()
  -- First try to avoid same slot as a consumable, then find first empty equipment slot
  local used_slots = {}
  for _, inv in ipairs(items.inventory()) do
    used_slots[inv.slot] = true
  end

  for slot = 0, 51 do
    if not used_slots[slot] then return slot end
  end

  for slot = 0, 51 do
    if not items.inslot(slot) then return slot end
  end
end

local function get_priority_ab(it)
  if not it.is_weapon then return -1 end
  if it.equipped then return 1 end

  if BRC.it.is_magic_staff(it) then return 3 end
  if it.is_ranged then return (you.skill("Ranged Weapons") >= 4) and 2 or 5 end
  if BRC.it.is_polearm(it) then return (you.skill("Polearms") >= 4) and 2 or 4 end
  return 2
end

local function get_priority_w(it)
  if not it.is_weapon then return -1 end
  if it.is_ranged then return 1 end
  if BRC.it.is_polearm(it) then return 2 end
  if BRC.it.is_magic_staff(it) then return 3 end
  return 4
end

local function generate_priorities()
  priorities_ab = { -1, -1, -1, -1, -1 }
  priorities_w = { -1, -1, -1, -1 }

  for _, inv in ipairs(items.inventory()) do
    local p = get_priority_w(inv)
    if p > 0 then
      if priorities_w[p] == -1 then
        priorities_w[p] = inv.slot
      else
        priorities_w[p + 1] = inv.slot
      end
    end

    p = get_priority_ab(inv)
    if p > 0 then
      if priorities_ab[p] == -1 then
        priorities_ab[p] = inv.slot
      else
        priorities_ab[p + 1] = inv.slot
      end
    end
  end
end

local function cleanup_ab(slot)
  local inv = items.inslot(slot)
  if inv and inv.is_weapon then return end

  for p = 1, #priorities_ab do
    if priorities_ab[p] > slot then -- Not from earlier slot
      items.swap_slots(priorities_ab[p], slot)
      slots_changed = true
      priorities_ab[p] = -1
      return
    end
  end
end

local function cleanup_w()
  local slot_w = items.letter_to_index("w")
  local inv = items.inslot(slot_w)
  if inv and inv.is_weapon then return end

  for p = 1, #priorities_w do
    if priorities_w[p] > 1 then -- Not from slots a or b
      items.swap_slots(priorities_w[p], slot_w)
      slots_changed = true
      return
    end
  end
end

local function cleanup_weapon_slots()
  generate_priorities()
  cleanup_ab(0)
  cleanup_ab(1)
  cleanup_w()
end

---- Hook functions ----
function f_weapon_slots.init()
  do_cleanup_weapon_slots = false
  slots_changed = false
  priorities_ab = nil
  priorities_w = nil
end

function f_weapon_slots.c_assign_invletter(it)
  if not it.is_weapon then return end

  for _, s in ipairs({ "a", "b", "w" }) do
    local slot = items.letter_to_index(s)
    local inv = items.inslot(slot)
    if not (inv and inv.is_weapon) then
      items.swap_slots(slot, get_first_empty_slot())
      slots_changed = true
      return slot
    end
  end
end

function f_weapon_slots.c_message(text, channel)
  do_cleanup_weapon_slots = channel == "plain" and text:contains("ou drop ")
end

function f_weapon_slots.ready()
  if do_cleanup_weapon_slots then
    cleanup_weapon_slots()
    do_cleanup_weapon_slots = false
  end
  if slots_changed then
    BRC.mpr.darkgrey("Weapon slots updated (ab+w).")
    crawl.redraw_screen()
    slots_changed = false
  end
end
