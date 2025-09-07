--[[
Feature: exclude-dropped
Description: Automatically excludes dropped items from autopickup and removes exclusion when items are picked up
Author: buehler
Dependencies: core/config.lua, core/data.lua, core/constants.lua, core/util.lua
--]]

f_exclude_dropped = {}
f_exclude_dropped.BRC_FEATURE_NAME = "exclude-dropped"

-- Persistent variables
ed_dropped_items = BRC.data.persist("ed_dropped_items", {})

-- Local functions
local function add_exclusion(item_name)
  if not util.contains(ed_dropped_items, item_name) then table.insert(ed_dropped_items, item_name) end
  BRC.set.autopickup_exception(item_name, true)
end

local function remove_exclusion(item_name)
  util.remove(ed_dropped_items, item_name)
  BRC.set.autopickup_exception(item_name, false)
end

local function has_enchantable_weap_in_inv()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if
      inv.is_weapon
      and not BRC.is.magic_staff(inv)
      and inv.plus < 9
      and (not inv.artefact or you.race() == "Mountain Dwarf")
    then
      return true
    end
  end
  return false
end

--[[
  get_excludable_name() - Pulls name from text; returns nil if we should NOT exclude anything
  Returns name of item to exclude, or nil if we should NOT exclude anything
--]]
local function get_excludable_name(text, for_exclusion)
  text = BRC.text.clean_text(text, false) -- remove tags
  text = text:gsub("{.*}", "")
  text = text:gsub("[.]", "")
  text = text:gsub("%(.*%)", "")
  text = util.trim(text)

  -- jewellery and wands
  local idx = text:find("ring of", 1, true) or text:find("amulet of", 1, true) or text:find("wand of", 1, true)
  if idx then return text:sub(idx, #text) end

  -- misc items
  for _, item_name in ipairs(BRC.ALL_MISC_ITEMS) do
    if text:find(item_name) then return item_name end
  end

  -- Missiles; add regex to hit specific missiles
  for _, item_name in ipairs(BRC.ALL_MISSILES) do
    if text:find(item_name) then return item_name end
  end

  -- Potions
  idx = text:find("potions? of")
  if idx then return "potions? of " .. util.trim(text:sub(idx + 10, #text)) end

  -- Scrolls; Enchant scrolls are special; not always excluded
  idx = text:find("scrolls? of")
  if idx then
    -- Enchant/Brand weapon scrolls continue pickup if they're still useful
    if
      for_exclusion
      and BRC.Config.ignore_stashed_weapon_scrolls
      and (text:find("enchant weapon", 1, true) or text:find("brand weapon", 1, true))
      and has_enchantable_weap_in_inv()
    then
      return
    end
    return "scrolls? of " .. util.trim(text:sub(idx + 10, #text))
  end
end

-- Hook functions
function f_exclude_dropped.init()
  if not BRC.Config.exclude_dropped then return end

  for _, v in ipairs(ed_dropped_items) do
    add_exclusion(v)
  end
end

function f_exclude_dropped.c_message(text, channel)
  if not BRC.Config.exclude_dropped then return end
  if channel ~= "plain" then return end
  local exclude
  if text:find("ou drop ", 1, true) then
    exclude = true
  elseif text:find(" %- ") then
    exclude = false
  else
    return
  end

  local item_name = get_excludable_name(text, exclude)
  if not item_name then return end

  if exclude then
    -- Don't exclude if we dropped partial stack (except for jewellery)
    for inv in iter.invent_iterator:new(items.inventory()) do
      if inv.name("qual"):find(item_name, 1, true) then
        if BRC.is.jewellery(inv) then break end
        local qty_str = string.format("ou drop %s %s", inv.quantity, item_name)
        if inv.quantity == 1 or text:find(qty_str, 1, true) then break end
        return
      end
    end

    add_exclusion(item_name)
  else
    remove_exclusion(item_name)
  end
end
