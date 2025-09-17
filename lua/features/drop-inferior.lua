--[[
Feature: drop-inferior
Description: Auto-tags inferior items and adds them to the drop list for quick dropping with ","
Author: buehler
Dependencies: core/config.lua, core/constants.lua, core/util.lua
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
    local emoji = BRC.Emoji.CAUTION or ""
    local item_name = BRC.text.yellow(string.format("%s - %s", BRC.util.int2char(it.slot), it.name()))
    local msg = util.trim(string.format("%s You can drop: %s %s", emoji, item_name, emoji))
    BRC.mpr.cyan(msg)
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

  local it_ego = BRC.get.ego(it)
  for inv in iter.invent_iterator:new(items.inventory()) do
    local inv_ego = BRC.get.ego(inv)
    -- To be an upgrade: subtypes must match, and either the egos match or we upgraded no ego to a non-risky ego
    if inv.subtype() == it.subtype() and (inv_ego == it_ego or not (inv_ego or BRC.is.risky_ego(it_ego))) then
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
