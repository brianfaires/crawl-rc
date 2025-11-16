---------------------------------------------------------------------------------------------------
-- BRC feature module: announce-items
-- @module f_announce_items
-- Announce when items of certain classes come into view. Off by default.
-- Intended and configured for turncount runs, to avoid having to manually check floor items.
---------------------------------------------------------------------------------------------------
f_announce_items = {}
f_announce_items.BRC_FEATURE_NAME = "announce-items"
f_announce_items.Config = {
  disabled = true, -- Disabled by default. Intended only for turncount runs.
  announced_classes = { "book", "gold", "jewellery", "misc", "potion", "scroll", "wand" }
} -- f_announce_items.Config (do not remove this comment)

---- Local variables ----
local los_items
local prev_item_names

---- Initialization ----
function f_announce_items.init()
  los_items = {}
  prev_item_names = {}
end

---- Local functions ----
local function announce_item(it)
  local class = it.class(true):lower()
  if util.contains(f_announce_items.Config.announced_classes, class) then
    crawl.mpr(BRC.txt.white("You see: ") .. it.name())
  end
end

---- Crawl hook functions ----
function f_announce_items.ready()
  los_items = {}
  local r = you.los()
  for x = -r, r do
    for y = -r, r do
      if you.see_cell(x, y) then
        local items_xy = items.get_items_at(x, y)
        if items_xy and #items_xy > 0 then
          for _, it in ipairs(items_xy) do
            los_items[#los_items+1] = it
          end
        end
      end
    end
  end

  for _, it in ipairs(los_items) do
    if not util.contains(prev_item_names, it.name()) then
      announce_item(it)
    end
  end

  -- Save names for comparison
  prev_item_names = {}
  for _, it in ipairs(los_items) do
    prev_item_names[#prev_item_names+1] = it.name()
  end
end
