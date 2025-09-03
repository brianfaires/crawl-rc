--[[
Feature: weapon-slots
Description: Automatically manages weapon slot assignments to slots a, b, and w with intelligent priority-based organization
Author: buehler
Dependencies: CONFIG, COLORS, with_color, iter.invent_iterator, is_magic_staff, is_polearm
--]]

f_weapon_slots = {}
f_weapon_slots.BRC_FEATURE_NAME = "weapon-slots"

-- Local state
local do_cleanup_weapon_slots
local priorities_ab
local priorities_w
local slots_changed

-- Local functions
local function cleanup_ab(slot)
  local inv = items.inslot(slot)
  if inv and inv.is_weapon then return end

  for p=1,#priorities_ab do
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

  for p=1,#priorities_w do
    if priorities_w[p] > 1 then -- Not from slots a or b
      items.swap_slots(priorities_w[p], slot_w)
      slots_changed = true
      return
    end
  end
end

local function get_priority_ab(it)
  if not it.is_weapon then return -1 end
  if it.equipped then return 1 end

  if is_magic_staff(it) then return 3 end
  if it.is_ranged then return (you.skill("Ranged Weapons") >= 4) and 2 or 5 end
  if is_polearm(it) then return (you.skill("Polearms") >= 4) and 2 or 4 end
  return 2
end

local function get_priority_w(it)
  if not it.is_weapon then return -1 end
  if it.is_ranged then return 1 end
  if is_polearm(it) then return 2 end
  if is_magic_staff(it) then return 3 end
  return 4
end

local function generate_priorities()
  priorities_ab = { -1, -1, -1, -1, -1 }
  priorities_w = { -1, -1, -1, -1 }

  for inv in iter.invent_iterator:new(items.inventory()) do
    local p = get_priority_w(inv)
    if p > 0 then
      if priorities_w[p] == -1 then priorities_w[p] = inv.slot
      else priorities_w[p+1] = inv.slot
      end
    end

    p = get_priority_ab(inv)
    if p > 0 then
      if priorities_ab[p] == -1 then priorities_ab[p] = inv.slot
      else priorities_ab[p+1] = inv.slot
      end
    end
  end
end

local function cleanup_weapon_slots()
  generate_priorities()
  cleanup_ab(0)
  cleanup_ab(1)
  cleanup_w()
end

local function get_first_empty_slot()
  for slot=1,52 do
    if not items.inslot(slot) then return slot end
  end
end

-- Hook functions
function f_weapon_slots.init()
  do_cleanup_weapon_slots = false
  slots_changed = false
  priorities_ab = nil
  priorities_w = nil
end

function f_weapon_slots.c_assign_invletter(it)
  if not CONFIG.do_auto_weapon_slots_abw then return end
  if not it.is_weapon then return end

  for i=0,2 do
    local slot = i==2 and items.letter_to_index("w") or i

    local inv = items.inslot(slot)
    if not inv then return slot end
    if not inv.is_weapon then
      items.swap_slots(slot, get_first_empty_slot())
      slots_changed = true
      return slot
    end
  end
end

function f_weapon_slots.c_message(text, channel)
  if not CONFIG.do_auto_weapon_slots_abw then return end
  do_cleanup_weapon_slots = channel == "plain" and text:find("ou drop ", 1, true)
end

function f_weapon_slots.ready()
  if do_cleanup_weapon_slots then
    cleanup_weapon_slots()
    do_cleanup_weapon_slots = false
    if slots_changed then
      crawl.mpr(with_color(COLORS.darkgrey, "Weapon slots updated (ab+w)."))
      crawl.redraw_screen()
      slots_changed = false
    end
  end
end
