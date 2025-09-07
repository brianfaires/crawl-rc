--[[
Feature: drop-inferior
Description: Auto-tags inferior items and adds them to the drop list for quick dropping with ","
Author: buehler
Dependencies: CONFIG, BRC.COLORS, BRC.text, iter
--]]

f_drop_inferior = {}
f_drop_inferior.BRC_FEATURE_NAME = "drop-inferior"

-- Local constants
local DROP_KEY = "~~DROP_ME"

-- Local functions
local function inscribe_drop(it)
  local new_inscr = it.inscription:gsub(DROP_KEY, "") .. DROP_KEY
  it.inscribe(new_inscr, false)
  if BRC.Config.msg_on_inscribe then
    BRC.mpr.col(string.format("(You can drop %s - %s)", it.slot, it.name()), BRC.COLORS.cyan)
  end
end

-- Hook functions
function f_drop_inferior.init()
  if not BRC.Config.drop_inferior then return end
  crawl.setopt(string.format("drop_filter += %s", DROP_KEY))
end

function f_drop_inferior.c_assign_invletter(it)
  if not BRC.Config.drop_inferior then return end
  -- Remove any previous DROP_KEY inscriptions
  it.inscribe(it.inscription:gsub(DROP_KEY, ""), false)

  if not (it.is_weapon or BRC.is.armour(it)) then return end
  if BRC.is.risky_ego(it) then return end

  for inv in iter.invent_iterator:new(items.inventory()) do
    if
      not inv.artefact
      and inv.subtype() == it.subtype()
      and (not BRC.is.branded(inv) or BRC.get.ego(inv) == BRC.get.ego(it))
    then
      if it.is_weapon then
        if you.race() == "Coglin" then return end -- More trouble than it's worth
        if inv.plus <= it.plus then inscribe_drop(inv) end
      else
        if BRC.get.armour_ac(inv) <= BRC.get.armour_ac(it) and inv.encumbrance >= it.encumbrance then
          if you.race() == "Poltergeist" then return end -- More trouble than it's worth
          inscribe_drop(inv)
        end
      end
    end
  end
end
