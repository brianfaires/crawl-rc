-- Add autopickup exclusion for any jewellery/missile/evocable item that is dropped
-- Exclusion is removed when you pick the item back up
-- Also exclude scrolls of enchant weapon/brand weapon, when no enchantable weapons are in inventory
if loaded_exclude_dropped then return end
loaded_exclude_dropped = true
loadfile("crawl-rc/lua/constants.lua")
loadfile("crawl-rc/lua/util.lua")

create_persistent_data("dropped_item_exclusions", "")

-- Init autopickup missiles
local started_with_ranged = false
if CACHE.s_ranged > 2 then
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.is_ranged then
      started_with_ranged = true
      break
    end
  end
end
if not started_with_ranged then crawl.setopt("autopickup_exceptions ^= < stone, <boomerang") end
crawl.setopt("autopickup_exceptions ^= <dart, <javelin")
if CACHE.size_penalty >= SIZE_PENALTY.LARGE then crawl.setopt("autopickup_exceptions ^= <large rock") end

if dropped_item_exclusions ~= "" then crawl.setopt("autopickup_exceptions ^= " .. dropped_item_exclusions) end

local function get_jewellery_name(text)
  local idx  = text:find("ring of ")
  if not idx then idx = text:find("amulet of ") end
  if not idx then return end

  text = text:gsub(" {.*}", "")
  text = text:gsub("[.]", "")
  return text:sub(idx,#text)
end

local function get_missile_name(text)
  for _,item_name in ipairs(all_missiles) do
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
end

local function get_misc_name(text)
  for _,item_name in ipairs(all_misc) do
    if text:find(item_name) then return item_name end
  end
end

local function has_enchantable_weap_in_inv()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_weapon(inv) and inv.plus < 9 and (not inv.artefact or you.race() == "Mountain Dwarf") then
      return true
    end
  end

  return false
end

local function get_excludable_scroll_name(text)
  if text:find("enchant weapon") then
    if has_enchantable_weap_in_inv() then return end
    return "enchant weapon"
  elseif text:find("brand weapon") then
    if has_enchantable_weap_in_inv() then return end
    return "brand weapon"
  else
    local excludable = { "enchant armour", "torment", "immolation", "silence" }
    for _,v in ipairs(excludable) do
      if text:find(v) then return v end
    end
  end
end


------------------ Hook ------------------
function c_message_exclude_dropped(text, channel)
  if channel ~= "plain" then return end

  local exclude
  if text:find("You drop ") then exclude = true
  elseif text:find(" %- ") then exclude = false
  else return
  end

  local item_name = get_jewellery_name(text)
  if not item_name then item_name = get_missile_name(text) end
  if not item_name then item_name = get_misc_name(text) end
  if not item_name then item_name = get_excludable_scroll_name(text) end
  if not item_name then return end

  if exclude then
    crawl.setopt("autopickup_exceptions ^= >" .. item_name)
    if dropped_item_exclusions ~= "" then dropped_item_exclusions = dropped_item_exclusions .. "," end
    dropped_item_exclusions = dropped_item_exclusions .. ">" .. item_name
  else
    crawl.setopt("autopickup_exceptions -= >" .. item_name)
    -- Remove persistent exclusion (try 3 times to make sure we capture comma)
    dropped_item_exclusions = dropped_item_exclusions:gsub(",>" .. item_name, "")
    dropped_item_exclusions = dropped_item_exclusions:gsub(">" .. item_name .. ",", "")
    dropped_item_exclusions = dropped_item_exclusions:gsub(">" .. item_name, "")
  end
end
