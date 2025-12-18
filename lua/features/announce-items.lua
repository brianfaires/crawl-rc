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
  announce_class = { "book", "gold", "jewellery", "misc", "missile", "potion", "scroll", "wand" },
  max_gold_announcements = 3, -- Stop announcing gold after 3rd pile on screen
  announce_extra_consumables_wo_id = true, -- Announce when standing on not-id'd duplicates
} -- f_announce_items.Config (do not remove this comment)

---- Local variables ----
local C -- config alias
local los_items
local prev_item_names
local prev_gold_count

---- Initialization ----
function f_announce_items.init()
  C = f_announce_items.Config
  los_items = {}
  prev_item_names = {}
  prev_gold_count = 0
end

---- Local functions ----
local function announce_item(it)
  if it.is_useless then return end
  local class = it.class(true):lower()
  if util.contains(C.announce_class, class) then
    if class == "gold" then
      prev_gold_count = prev_gold_count + 1
      if prev_gold_count > C.max_gold_announcements then return end
    end
    crawl.mpr(BRC.txt.yellow("You see: ") .. it.name())
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

            if C.announce_extra_consumables_wo_id then
              if x == 0 and y == 0 and not it.is_identified
                and (it.class(true) == "scroll" or it.class(true) == "potion")
               then
                if util.exists(items.inventory(), function(i)
                  return i.name("qual", false) == it.name("qual", false)
                end) then
                  crawl.mpr(BRC.txt.green("Duplicate: ") .. it.name())
                end
              end
            end
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
