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
  announced_classes = { "book", "gold", "jewellery", "misc", "potion", "scroll", "wand" },
  max_gold_announcements = 3, -- Stop announcing gold after 3rd pile on screen
} -- f_announce_items.Config (do not remove this comment)

---- Local variables ----
local los_items
local prev_item_names
local prev_gold_count

---- Initialization ----
function f_announce_items.init()
  los_items = {}
  prev_item_names = {}
  prev_gold_count = 0
end

---- Local functions ----
local function announce_item(it)
  if it.is_useless then return end
  local class = it.class(true):lower()
  if util.contains(f_announce_items.Config.announced_classes, class) then
    if class == "gold" then
      prev_gold_count = prev_gold_count + 1
      if prev_gold_count > f_announce_items.Config.max_gold_announcements then return end
    end
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

  -- Save history for comparison
  prev_item_names = {}
  prev_gold_count = 0
  for _, it in ipairs(los_items) do
    prev_item_names[#prev_item_names+1] = it.name()
    if it.class(true):lower() == "gold" then
      prev_gold_count = prev_gold_count + 1
    end
  end
end
