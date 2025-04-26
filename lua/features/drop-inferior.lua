function inscribe_drop(it)
  local new_inscr = it.inscription:gsub("~~DROP_ME", "").."~~DROP_ME"
  it.inscribe(new_inscr, false)
end

------------------------------------------
------------------ Hook ------------------
------------------------------------------
function c_assign_invletter_drop_inferior(it)
  -- Skip brands that are potentially harmful
  local it_ego = it.ego()
  if it_ego == "distortion" or it_ego == "chaos" or it_ego == "infusion" then return end
  
  if not is_weapon(it) and not is_armour(it) then return end
  
  local risky_artefact = false
  if it.artefact then
    local qualname = it.name("qual")
    if qualname:find("%-") or qualname:find("Harm") or qualname:find("Infuse") then
      risky_artefact = true
    end
  end

  if risky_artefact then return end

  local st = it.subtype()

  for inv in iter.invent_iterator:new(items.inventory()) do
    local item_match = false
    if inv.subtype() == st then
      if is_body_armour(it) then
        if inv.encumbrance >= it.encumbrance then item_match = true end
      else
        if inv.subtype() == st then item_match = true end
      end
    end

    if not inv.artefact and item_match and (not has_ego(inv) or get_ego(inv) == get_ego(it)) then
      if is_weapon(it) then
        if inv.plus <= it.plus then inscribe_drop(inv) end
      else
        if get_armour_ac(inv) <= get_armour_ac(it) then inscribe_drop(inv) end
      end
    end
  end
end


function c_assign_invletter_exclude_dropped(it)
 -- Remove "~~DROP_ME" inscription on pickup
  it.inscribe(it.inscription:gsub("~~DROP_ME", ""), false)
end
