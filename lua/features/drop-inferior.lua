------- Auto-tag inferior items and add to drop list -----
local DROP_KEY = "~~DROP_ME"

local function inscribe_drop(it)
  local new_inscr = it.inscription:gsub(DROP_KEY, "") .. DROP_KEY
  it.inscribe(new_inscr, false)
end


function init_drop_inferior()
  if CONFIG.debug_init then crawl.mpr("Initializing drop-inferior") end

  crawl.setopt("drop_filter += " .. DROP_KEY)
end


------------------ Hooks ------------------
function c_assign_invletter_drop_inferior(it)
  -- Remove any previous DROP_KEY inscriptions
  it.inscribe(it.inscription:gsub(DROP_KEY, ""), false)

  if not (is_weapon(it) or is_armour(it)) then return end
  if has_risky_ego(it) then return end

  for inv in iter.invent_iterator:new(items.inventory()) do
    if not inv.artefact and inv.subtype() == it.subtype() and
      (not has_ego(inv) or get_ego(inv) == get_ego(it)) then
        if is_weapon(it) then
          if inv.plus <= it.plus then inscribe_drop(inv) end
        else
          if get_armour_ac(inv) <= get_armour_ac(it) then inscribe_drop(inv) end
        end
    end
  end
end
