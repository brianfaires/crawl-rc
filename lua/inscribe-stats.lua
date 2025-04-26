dofile("crawl-rc/lua/util.lua")

local function inscribe_armour_stats(it)
  local new_inscr = get_armour_info(it)
  local idx
  if is_shield(it) then idx = it.inscription:find("SH+")
  elseif is_body_armour(it) then idx = it.inscription:find("AC+")
  else return
  end

  if idx then
    if idx + #new_inscr <= #it.inscription then
      new_inscr = new_inscr..it.inscription:sub(idx + #new_inscr, #it.inscription)
    end
    if idx > 1 then new_inscr = it.inscription:sub(1, idx-1)..new_inscr end
  end

  it.inscribe(new_inscr, false)
  return new_inscr
end

local function inscribe_weapon_stats(it)
  local new_inscr = get_weapon_info(it)

  local idx = it.inscription:find("DPS:")
  if idx then
    if idx + #new_inscr <= #it.inscription then
      new_inscr = new_inscr..it.inscription:sub(idx + #new_inscr, #it.inscription)
    end
    if idx > 1 then new_inscr = it.inscription:sub(1, idx-1)..new_inscr end
  end

  it.inscribe(new_inscr, false)
  return new_inscr
end


local skipped_first_redraw = false
------------------------------------------
------------------ Hook ------------------
------------------------------------------
function ready_inscribe_stats()
  for it in iter.invent_iterator:new(items.inventory()) do
    if is_weapon(it) or is_staff(it) then
      inscribe_weapon_stats(it)
    elseif is_armour(it) then
      inscribe_armour_stats(it)
    end
  end

  -- This redraw can causes crashes if called during an autopickup.
  -- Be sure not to hook any of this to c_message, or anything that can trigger during an autopickup
  if skipped_first_redraw then crawl.redraw_screen()
  else skipped_first_redraw = true
  end
end
