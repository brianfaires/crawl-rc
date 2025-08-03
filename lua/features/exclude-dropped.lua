-- Add autopickup exclusion for any jewellery/missile/evocable/consumable that is dropped
-- Exclusion is removed when you pick the item back up
-- Exclude enchant/brand weapon only when no enchantable weapons are in inventory
local function add_exclusion(item_name)
  if not util.contains(dropped_item_exclusions, item_name) then
    dropped_item_exclusions[#dropped_item_exclusions + 1] = item_name
  end
  local command = "autopickup_exceptions ^= " .. item_name
  crawl.setopt(command)
end

local function remove_exclusion(item_name)
  util.remove(dropped_item_exclusions, item_name)
  local command = "autopickup_exceptions -= " .. item_name
  crawl.setopt(command)
end

local function has_enchantable_weap_in_inv()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.is_weapon and inv.plus < 9 and (not inv.artefact or CACHE.race == "Mountain Dwarf") then
      return true
    end
  end
  return false
end

-- Pulls name from text; returns nil if we should NOT exclude anything
local function get_excludable_name(text, for_exclusion)
  text = cleanup_text(text, false) -- remove tags
  text = text:gsub("{.*}", "")
  text = text:gsub("[.]", "")
  text = text:gsub("%(.*%)", "")
  text = util.trim(text)

  -- jewellery and wands
  local idx = text:find("ring of", 1, true) or text:find("amulet of", 1, true) or text:find("wand of", 1, true)
  if idx then
    return text:sub(idx, #text)
  end

  -- misc items
  for _,item_name in ipairs(ALL_MISC_ITEMS) do
    if text:find(item_name) then return item_name end
  end

  -- Missiles; add regex to hit specific missiles
  for _,item_name in ipairs(ALL_MISSILES) do
    if text:find(item_name) then
      return item_name
    end
  end

  -- Potions
  idx = text:find("potions? of")
  if idx then
    return "potions? of " .. util.trim(text:sub(idx+10,#text))
  end

  -- Scrolls; Enchant scrolls are special; not always excluded
  idx = text:find("scrolls? of")
  if idx then
    -- Enchant/Brand weapon scrolls continue pickup if they're still useful
    if for_exclusion and CONFIG.ignore_stashed_weapon_scrolls
    and (text:find("enchant weapon", 1, true) or text:find("brand weapon", 1, true))
    and has_enchantable_weap_in_inv() then
      return
    end
    return "scrolls? of " .. util.trim(text:sub(idx+10,#text))
  end
end


function init_exclude_dropped()
  if not CONFIG.exclude_dropped then return end
  if CONFIG.debug_init then crawl.mpr("Initializing exclude-dropped") end

  create_persistent_data("dropped_item_exclusions", {})

  for _,v in ipairs(dropped_item_exclusions) do
    add_exclusion(v)
  end
end


------------------ Hooks ------------------
function c_message_exclude_dropped(text, channel)
  if not CONFIG.exclude_dropped then return end
  if channel ~= "plain" then return end
  local exclude
  if text:find("ou drop ", 1, true) then exclude = true
  elseif text:find(" %- ") then exclude = false
  else return end

  local item_name = get_excludable_name(text, exclude)
  if not item_name then return end

  if exclude then
    -- Don't exclude if we dropped partial stack (except for jewellery)
    for inv in iter.invent_iterator:new(items.inventory()) do
      if inv.name("qual"):find(item_name, 1, true) then
        if is_jewellery(inv) then break end
        local qty_str = "ou drop " .. inv.quantity .. " " .. item_name
        if inv.quantity == 1 or text:find(qty_str, 1, true) then break end
        return
      end
    end

    add_exclusion(item_name)
  else
    remove_exclusion(item_name)
  end
end
