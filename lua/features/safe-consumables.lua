--[[
Feature: safe-consumables
Description: Automatically manages !q and !r inscriptions. An upgrade to using autoinscribe.
Author: buehler
Dependencies: core/config.lua, core/util.lua
--]]

f_safe_consumables = {}
f_safe_consumables.BRC_FEATURE_NAME = "safe-consumables"

-- Local constants
local NO_INSCRIPTION_NEEDED = {
  "acquirement", "amnesia", "blinking", "brand weapon", "enchant armour", "enchant weapon", "identify",
  "immolation", "noise", "vulnerability", "attraction", "lignification", "mutation",
} -- NO_INSCRIPTION_NEEDED (do not remove this comment)

-- Hook functions
function f_safe_consumables.ready()
  if not BRC.Config.safe_consumables then return end
  -- Remove the default "!r" and "!q" inscriptions after identify
  for inv in iter.invent_iterator:new(items.inventory()) do
    local inv_class = inv.class(true)
    local st = inv.subtype()
    if inv_class == "scroll" then
      if
        (st == "poison" and you.res_poison() > 0)
        or (st == "torment" and you.torment_immune())
        or util.contains(NO_INSCRIPTION_NEEDED, st)
      then
        if inv.inscription:find("!r", 1, true) then inv.inscribe(inv.inscription:gsub("%!r", ""), false) end
      elseif not inv.inscription:find("!r", 1, true) then
        inv.inscribe("!r")
      end
    elseif inv_class == "potion" then
      if util.contains(NO_INSCRIPTION_NEEDED, st) then
        if inv.inscription:find("!q", 1, true) then inv.inscribe(inv.inscription:gsub("%!q", ""), false) end
      elseif not inv.inscription:find("!q", 1, true) then
        inv.inscribe("!q")
      end
    end
  end
end
