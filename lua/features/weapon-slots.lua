---- Cleanup weapon slots ----
--Whenever you drop an item:
  -- Assign weapons to slots a and b
      -- Priority: 1:wielded, 2:weapon, not polearm/ranged unless skill
      -- 3:magical staff, 4:polearm, 5:ranged
  -- Assign weap to w: ranged/polearm/any

local do_cleanup_weapon_slots
local priorities_ab
local priorities_w

local function cleanup_ab(ab)
  local inv
  inv = items.inslot(ab)
  if inv and inv.class(true) == "weapon" then return end

  for p=1,5 do
    if priorities_ab[p] > ab then
      items.swap_slots(priorities_ab[p], ab)
      priorities_ab[p] = -1
      return
    end
  end
end

local function cleanup_w()
  local slot_w = items.letter_to_index("w")
  local inv = items.inslot(slot_w)
  if inv and inv.class(true) == "weapon" then return end

  for p=1,3 do
    if priorities_w[p] > 1 then
      items.swap_slots(priorities_w[p], slot_w)
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

local function generate_priorities()
  priorities_ab = { -1, -1, -1, -1, -1 }
  priorities_w = { -1, -1, -1 }

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

local function get_first_empty_slot()
  for slot=1,52 do
    if not items.inslot(slot) then return slot end
  end
end

local function get_priority_ab(it)
  if not it or not it.weap_skill then return -1 end
  if it.equipped then return 1 end

  if is_staff(it) then return 3 end
  if is_weapon(it) then
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
  if not it or not it.weap_skill then return -1 end
  if it.is_ranged then return 1 end
  if is_polearm(it) then return 2 end
  return 3
end


function init_weapon_slots()
  if CONFIG.debug_init then crawl.mpr("Initializing weapon-slots") end

  do_cleanup_weapon_slots = false
  priorities_ab = nil
  priorities_w = nil
end


------------------- Hooks -------------------
function c_assign_invletter_weapon_slots(it)
  if not is_weapon(it) and not is_staff(it) then return end

  for i=0,2 do
    local slot = i==2 and items.letter_to_index("w") or i

    local inv = items.inslot(slot)
    if not inv then return slot end
    if not is_weapon(inv) and not is_staff(inv) then
      items.swap_slots(slot, get_first_empty_slot())
      return slot
    end
  end
end

function c_message_weapon_slots(text, channel)
  do_cleanup_weapon_slots = channel == "plain" and text:find("You drop ")
end

function ready_weapon_slots()
  if do_cleanup_weapon_slots then
    cleanup_weapon_slots()
    do_cleanup_weapon_slots = false
  end
end
