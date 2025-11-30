---------------------------------------------------------------------------------------------------
-- BRC feature module: drop-inferior
-- @module f_drop_inferior
-- When picking up an item, inscribes inferior items with "~~DROP_ME" and alerts you.
-- Items with "~~DROP_ME" are added to the drop list, and can be quickly selected with `,`
---------------------------------------------------------------------------------------------------

f_drop_inferior = {}
f_drop_inferior.BRC_FEATURE_NAME = "drop-inferior"
f_drop_inferior.Config = {
  msg_on_inscribe = true, -- Show a message when an item is marked for drop
  hotkey_drop = true, -- BRC hotkey drops all items on the drop list
} -- f_drop_inferior.Config (do not remove this comment)

---- Local constants ----
local DROP_KEY = "~~DROP_ME"

---- Initialization ----
function f_drop_inferior.init()
  crawl.setopt("drop_filter += " .. DROP_KEY)
end

---- Local functions ----
local function inscribe_drop(it)
  local new_inscr = it.inscription:gsub(DROP_KEY, "") .. DROP_KEY
  it.inscribe(new_inscr, false)
  if f_drop_inferior.Config.msg_on_inscribe then
    local item_name = BRC.txt.yellow(BRC.txt.int2char(it.slot) .. " - " .. it.name())
    BRC.mpr.cyan(BRC.txt.wrap("You can drop: " .. item_name, BRC.EMOJI.CAUTION))
  end
end

---- Crawl hook functions ----
function f_drop_inferior.c_assign_invletter(it)
  -- Remove any previous DROP_KEY inscriptions
  it.inscribe(it.inscription:gsub(DROP_KEY, ""), false)

  if
    not (it.is_weapon or BRC.it.is_armour(it))
    or BRC.eq.is_risky(it)
    or BRC.you.num_eq_slots(it) > 1
  then
    return
  end

  local it_ego = BRC.eq.get_ego(it)
  local marked_something = false
  for _, inv in ipairs(items.inventory()) do
    -- To be a clear upgrade: Not artefact, same subtype, and ego is same or a clear upgrade
    local inv_ego = BRC.eq.get_ego(inv)
    local not_worse = inv_ego == it_ego or not inv_ego or BRC.eq.is_risky(inv)
    if not_worse and not inv.artefact and inv.subtype() == it.subtype() then
      if it.is_weapon then
        if inv.plus <= (it.plus or 0) then
          inscribe_drop(inv)
          marked_something = true
        end
      else
        local not_more_ac = BRC.eq.get_ac(inv) <= BRC.eq.get_ac(it)
        if not_more_ac and inv.encumbrance >= it.encumbrance then
          inscribe_drop(inv)
          marked_something = true
        end
      end
    end
  end

  if marked_something and f_drop_inferior.Config.hotkey_drop and BRC.Hotkey then
    BRC.Hotkey.set("drop", "your useless items", false, function()
      crawl.sendkeys(BRC.util.get_cmd_key("CMD_DROP") .. ",\r")
      crawl.flush_input()
    end)
  end
end
