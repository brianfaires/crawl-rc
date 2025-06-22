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

-- Pulls name from text; returns nil if we should NOT exclude anything
local function get_excludable_name(text, for_exclusion)
  text = cleanup_text(text, false) -- remove tags
  text = text:gsub("{.*}", "")
  text = text:gsub("[.]", "")
  text = text:gsub("%(.*%)", "")
  text = util.trim(text)

  -- jewellery and wands
  local idx = text:find("ring of ") or text:find("amulet of ") or text:find("wand of ")
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
      if item_name == "boomerang" or item_name == "javelin" then
        if text:find("silver") then
          item_name = "silver " .. item_name
        elseif text:find("dispersal") then
          item_name = item_name .. "s? of dispersal"
        else
          item_name = "(?<!silver )" .. item_name .. "(?!(s? of dispersal))"
        end
      end
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
    if for_exclusion and not CONFIG.exclude_stashed_enchant_scrolls and
        text:find(" weapon") and has_enchantable_weap_in_inv() then return
    end
    return "scrolls? of " .. util.trim(text:sub(idx+10,#text))
  end
end

local function has_enchantable_weap_in_inv()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_weapon(inv) and inv.plus < 9 and (not inv.artefact or CACHE.race == "Mountain Dwarf") then
      return true
    end
  end
  return false
end


function init_exclude_dropped()
  if CONFIG.debug_init then crawl.mpr("Initializing exclude-dropped") end

  create_persistent_data("dropped_item_exclusions", {})

  for _,v in ipairs(dropped_item_exclusions) do
    add_exclusion(v)
  end
end


------------------ Hooks ------------------
function c_message_exclude_dropped(text, channel)
  if channel ~= "plain" then return end
  local exclude
  if text:find("You drop ") then exclude = true
  elseif text:find(" %- ") then exclude = false
  else return end

  local item_name = get_excludable_name(text, exclude)
  if not item_name then return end

  if exclude then
    add_exclusion(item_name)
  else
    remove_exclusion(item_name)
  end
end
