---- Protective consumable inscriptions on everything w/o a built-in prompt --
-- Updates every turn to:
  -- Inscribe starting items
  -- Update inscriptions after ID

local NO_INSCRIPTION_NEEDED = {
  "acquirement", "amnesia", "blinking", "brand weapon", "enchant armour", "enchant weapon",
  "identify", "immolation", "noise", "vulnerability", "attraction", "lignification", "mutation"}

------------------- Hook -------------------
function ready_safe_consumables()
  -- Remove the default "!r" and "!q" inscriptions after identify
  for inv in iter.invent_iterator:new(items.inventory()) do
    local inv_class = inv.class(true)
    if inv_class == "scroll" then
      local st = inv.subtype()
      if (st == "poison" and you.res_poison() > 0)
        or (st == "torment" and you.torment_immune())
        or util.contains(NO_INSCRIPTION_NEEDED, st) then
          if inv.inscription:find("%!r") then inv.inscribe(inv.inscription:gsub("%!r", ""), false) end
      elseif not inv.inscription:find("%!r") then inv.inscribe("!r")
      end
    elseif inv_class == "potion" then
      if util.contains(NO_INSCRIPTION_NEEDED, st) then
        if inv.inscription:find("%!q") then inv.inscribe(inv.inscription:gsub("%!q", ""), false) end
      elseif not inv.inscription:find("%!q") then inv.inscribe("!q")
      end
    end
  end
end
