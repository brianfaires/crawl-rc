--[[
Feature: drop-inferior
Description: Auto-tags inferior items and adds them to the drop list for quick dropping with ","
Author: buehler
Dependencies: core/config.lua, core/util.lua
--]]

f_drop_inferior = {}
f_drop_inferior.BRC_FEATURE_NAME = "drop-inferior"
f_drop_inferior.Config = {
  msg_on_inscribe = true, -- Show a message when an item is marked for drop
} -- f_drop_inferior.Config (do not remove this comment)

---- Local constants ----
local DROP_KEY = "~~DROP_ME"

---- Local functions ----
local function inscribe_drop(it)
  local new_inscr = it.inscription:gsub(DROP_KEY, "") .. DROP_KEY
  it.inscribe(new_inscr, false)
  if f_drop_inferior.Config.msg_on_inscribe then
    local item_name = BRC.text.yellow(string.format("%s - %s", BRC.util.int2char(it.slot), it.name()))
    local msg = string.format("%s You can drop: %s %s", BRC.EMOJI.CAUTION, item_name, BRC.EMOJI.CAUTION)
    BRC.mpr.cyan(msg)
  end
end

---- Hook functions ----
function f_drop_inferior.init()
  crawl.setopt(string.format("drop_filter += %s", DROP_KEY))
end

function f_drop_inferior.c_assign_invletter(it)
  -- Remove any previous DROP_KEY inscriptions
  it.inscribe(it.inscription:gsub(DROP_KEY, ""), false)

  if not (it.is_weapon or BRC.is.armour(it)) or BRC.is.risky_item(it) then return end
  if BRC.get.num_equip_slots(it) > 1 then return end

  local it_ego = BRC.get.ego(it)
  for inv in iter.invent_iterator:new(items.inventory()) do
    -- To be a clear upgrade: Not artefact, same subtype, and ego is same or a clear upgrade
    local inv_ego = BRC.get.ego(inv)
    local ego_same_or_better = inv_ego == it_ego or not inv_ego or BRC.is.risky_item(inv)
    if not inv.artefact and inv.subtype() == it.subtype() and ego_same_or_better then
      if it.is_weapon then
        if you.race() == "Coglin" then return end -- More trouble than it's worth
        if inv.plus <= (it.plus or 0) then inscribe_drop(inv) end
      else
        if BRC.get.armour_ac(inv) <= BRC.get.armour_ac(it) and inv.encumbrance >= it.encumbrance then
          inscribe_drop(inv)
        end
      end
    end
  end
end
