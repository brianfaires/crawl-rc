dofile("crawl-rc/lua/config.lua")

--------------------------------------------
---- Protective consumable inscriptions ----
--------------------------------------------
-- Update inscriptions every turn
-- Handles on init (starting items don't get default inscriptions)
-- Handles after ID

---------------------------------------------
------------------- Hook -------------------
---------------------------------------------
function ready_safe_consumables()
  -- Remove the default "!r" and "!q" inscriptions after identify
  for it in iter.invent_iterator:new(items.inventory()) do
    if it.is_identified then
      local it_class = it.class(true)
      if it_class == "potion" or it_class == "scroll" then
        local st, _ = it.subtype()
        if (st == "poison" and you.res_poison() > 0)
          or (st == "torment" and you.torment_immune())
          or util.contains(no_inscription_needed, st) then
            if it.inscription:find("%!r") then it.inscribe(it.inscription:gsub("%!r", ""), false) end
            if it.inscription:find("%!q") then it.inscribe(it.inscription:gsub("%!q", ""), false) end
        elseif it_class == "scroll" and not it.inscription:find("!r") then
            it.inscribe("!r")
        elseif it_class == "potion" and not it.inscription:find("!q") then
            it.inscribe("!q")
        end
      end
    end
  end
end
