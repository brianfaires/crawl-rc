---- Cleanup weapon slots ----
-- Picked up weapons always go to a,b,w
-- Whenever you drop an item:
  -- Assign weapons to slots a and b
      -- Priority: 1:wielded, 2:weapon, not polearm/ranged unless training it
      -- 3:magical staff, 4:polearm, 5:ranged
  -- Assign weapon to w: ranged/polearm/magical staff/any

local do_cleanup_weapon_slots
local priorities_ab
local priorities_w
local slots_changed

local function cleanup_ab(slot)
  local inv = items.inslot(slot)
  if not inv or inv.is_weapon then return end

  for p=1,#priorities_ab do
    if priorities_ab[p] > slot then
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
  if not inv or inv.is_weapon then return end

  for p=1,#priorities_w do
    if priorities_w[p] > 1 then
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
  if it.is_weapon then
    if it.is_ranged then
      if CACHE.s_ranged >= 4 then return 2 end
      return 5
    end

    if is_polearm(it) then
      if CACHE.s_polearms >= 4 then return 2 end
      return 4
    end

    return 2
  end

  return -1
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


function init_weapon_slots()
  if CONFIG.debug_init then crawl.mpr("Initializing weapon-slots") end

  do_cleanup_weapon_slots = false
  slots_changed = false
  priorities_ab = nil
  priorities_w = nil
end


------------------- Hooks -------------------
function c_assign_invletter_weapon_slots(it)
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

function c_message_weapon_slots(text, channel)
  if not CONFIG.do_auto_weapon_slots_abw then return end
  do_cleanup_weapon_slots = channel == "plain" and text:find("ou drop ", 1, true)
end

function ready_weapon_slots()
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
