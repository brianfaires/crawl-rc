--[[
Feature: safe-consumables
Description: Automatically manages !q and !r inscriptions. An upgrade to using autoinscribe.
Author: buehler
Dependencies: core/util.lua
--]]

f_safe_consumables = {}
f_safe_consumables.BRC_FEATURE_NAME = "safe-consumables"

---- Local constants ----
local NO_INSCRIPTION_NEEDED = {
  "acquirement", "amnesia", "blinking", "brand weapon", "enchant armour", "enchant weapon", "identify",
  "immolation", "noise", "vulnerability", "attraction", "lignification", "mutation",
} -- NO_INSCRIPTION_NEEDED (do not remove this comment)

---- Local functions ----
local function inscription_needed(class, st)
  if util.contains(NO_INSCRIPTION_NEEDED, st) then return false end
  if class == "scroll" then
    if st == "poison" then return you.res_poison() > 0 end
    if st == "torment" then return you.torment_immune() end
  end
  return true
end

---- Hook functions ----
function f_safe_consumables.ready()
  -- Remove the default "!r" and "!q" inscriptions after identify
  for inv in iter.invent_iterator:new(items.inventory()) do
    local inv_class = inv.class(true)
    if inv_class == "scroll" then
      if inscription_needed(inv_class, inv.subtype()) then
        if not inv.inscription:contains("!r") then inv.inscribe("!r") end
      else
        if inv.inscription:contains("!r") then inv.inscribe(inv.inscription:gsub("%!r", ""), false) end
      end
    elseif inv_class == "potion" then
      if inscription_needed(inv_class, inv.subtype()) then
        if not inv.inscription:contains("!q") then inv.inscribe("!q") end
      else
        if inv.inscription:contains("!q") then inv.inscribe(inv.inscription:gsub("%!q", ""), false) end
      end
    end
  end
end
