-- When an item is moved to its assigned slot, mute the messages for the item that was previously in that slot
-- If we cared what slot the item was in, it'd already be assigned somewhere
-- This mostly matters when reading scroll of ID, where 5-6 lines of inventory items can be confusing

local muted_items = {}

-- Must define this separate from ready() if we want to call it from c_message_mute_swaps as well
local function unmute_items()
  for v in iter.invent_iterator:new(muted_items) do
    crawl.setopt("message_colour -= mute: - "..v)
  end
  muted_items = {}
end

------------------- Hooks -------------------
function ready_mute_swaps()
  unmute_items()
end

local last_pickup_turn = -1
function c_assign_invletter_mute_swaps(_)
  -- this causes an unmute command on the message
  -- we can't unmute in time from this hook
  if you.turns() == last_pickup_turn or crawl.messages(1):find(" %- ") then
    unmute_items()
  else
    last_pickup_turn = you.turns()
  end
end

function c_message_mute_swaps(text, channel)
  -- Mute subsequent item re-assignments in a single turn, for everything after the first item.
  -- Multiple slots for the same item will still be shown
  if channel == "plain" then
    text = cleanup_text(text, true)
    if text:sub(2,4) == " - " then
      local item = text:sub(5, #text)
      local mute_str = "(?!.*("..item.."))"
      table.insert(muted_items, mute_str)
      crawl.setopt("message_colour ^= mute: - "..mute_str)
      return
    end
  end

  unmute_items()
end