--[[
Feature: exclude-dropped
Description: Automatically excludes dropped items from autopickup and removes exclusion when items are picked up
Author: buehler
Dependencies: core/config.lua, core/data.lua, core/constants.lua, core/util.lua
--]]

f_exclude_dropped = {}
f_exclude_dropped.BRC_FEATURE_NAME = "exclude-dropped"
f_exclude_dropped.Config = {
  not_weapon_scrolls = true, -- Don't exclude enchant/brand scrolls if holding an enchantable weapon
} -- f_exclude_dropped.Config (do not remove this comment)

-- Persistent variables
ed_dropped_items = BRC.data.persist("ed_dropped_items", {})

-- Local functions
local function add_exclusion(item_name)
  if not util.contains(ed_dropped_items, item_name) then table.insert(ed_dropped_items, item_name) end
  BRC.set.autopickup_exceptions(item_name, true)
end

local function remove_exclusion(item_name)
  util.remove(ed_dropped_items, item_name)
  BRC.set.autopickup_exceptions(item_name, false)
end

local function enchantable_weap_in_inv()
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

local function clean_item_text(text)
  text = BRC.text.clean(text, false) -- remove tags
  text = text:gsub("{.*}", "")
  text = text:gsub("[.]", "")
  text = text:gsub("%(.*%)", "")
  return util.trim(text)
end

local function extract_jewellery_or_evoker(text)
  local idx = text:find("ring of", 1, true) or text:find("amulet of", 1, true) or text:find("wand of", 1, true)
  if idx then return text:sub(idx, #text) end

  for _, item_name in ipairs(BRC.MISC_ITEMS) do
    if text:find(item_name) then return item_name end
  end
end

local function extract_missile(text)
  for _, item_name in ipairs(BRC.MISSILES) do
    if text:find(item_name) then return item_name end
  end
end

local function extract_potion(text)
  local idx = text:find("potions? of")
  if idx then return "potions? of " .. util.trim(text:sub(idx + 10, #text)) end
end

local function extract_scroll(text)
  local idx = text:find("scrolls? of")
  if idx then return "scrolls? of " .. util.trim(text:sub(idx + 10, #text)) end
end

--[[
  get_item_name() - Tries to extract item name from text.
  Returns name of item, or nil if not recognized as an excludable item.
--]]
local function get_item_name(text)
  text = clean_item_text(text)
  return extract_jewellery_or_evoker(text) or extract_missile(text) or extract_potion(text) or extract_scroll(text)
end

local function should_exclude(item_name)
  -- Enchant/Brand weapon scrolls continue pickup if they're still useful
  local weap_scroll = item_name:contains("enchant weapon") or item_name:contains("brand weapon")
  if f_exclude_dropped.Config.not_weapon_scrolls and weap_scroll and enchantable_weap_in_inv() then return false end

  -- Don't exclude if we dropped partial stack (except for jewellery)
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.name("qual"):contains(item_name) then
      if BRC.is.jewellery(inv) then return true end
      local qty_str = string.format("ou drop %s %s", inv.quantity, item_name)
      return inv.quantity == 1 or item_name:contains(qty_str)
    end
  end

  return true
end

-- Hook functions
function f_exclude_dropped.init()
  for _, v in ipairs(ed_dropped_items) do
    add_exclusion(v)
  end
end

function f_exclude_dropped.c_message(text, channel)
  if channel ~= "plain" then return end

  local picked_up = BRC.text.get_pickup_info(text)
  if not picked_up and not text:contains("ou drop ") then return end

  local item_name = get_item_name(text)
  if not item_name then return end

  if picked_up then
    remove_exclusion(item_name)
  elseif should_exclude(item_name) then
    add_exclusion(item_name)
  end
end
