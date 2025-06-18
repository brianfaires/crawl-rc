-- Add autopickup exclusion for any jewellery/missile/evocable item that is dropped
-- Exclusion is removed when you pick the item back up
-- Also exclude scrolls of enchant weapon/brand weapon, when no enchantable weapons are in inventory
if loaded_exclude_dropped then return end
loaded_exclude_dropped = true
loadfile("crawl-rc/lua/constants.lua")
loadfile("crawl-rc/lua/util.lua")

create_persistent_data("dropped_item_exclusions", {})

local function add_exclusion(item_name)
  if util.contains(dropped_item_exclusions, item_name) then return end
  dropped_item_exclusions[#dropped_item_exclusions + 1] = item_name
  crawl.setopt("autopickup_exceptions ^= " .. item_name)
end

local function add_exclusions(item_names)
  for _,item_name in ipairs(item_names) do
    add_exclusion(item_name)
  end
end

local function remove_exclusion(item_name)
  util.remove(dropped_item_exclusions, item_name)
  crawl.setopt("autopickup_exceptions -= " .. item_name)
end

local function remove_exclusions(item_names)
  for _,item_name in ipairs(item_names) do
    remove_exclusion(item_name)
  end
end

-- Pulls name from text; returns nil if we should NOT exclude anything
local function get_excludable_name(text)
  -- jewellery and wands
  local idx = text:find("ring of ") or text:find("amulet of ") or text:find("wand of ")
  if idx then
    text = text:gsub(" {.*}", "")
    text = text:gsub("[.]", "")
    return text:sub(idx,#text)
  end

  -- misc items
  for _,item_name in ipairs(all_misc) do
    if text:find(item_name) then return item_name end
  end

  -- Commonly stashed scrolls; don't stop future pickups
  if text:find("enchant armour") then
    return "enchant armour"
  elseif text:find("enchant weapon") then
    if not has_enchantable_weap_in_inv() then return "enchant weapon" end
  elseif text:find("brand weapon") then
    if not has_enchantable_weap_in_inv() then return "brand weapon" end
  end

  -- Missiles; add regex to hit specific missiles
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

local function has_enchantable_weap_in_inv()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_weapon(inv) and inv.plus < 9 and (not inv.artefact or CACHE.race == "Mountain Dwarf") then
      return true
    end
  end
  return false
end

------------------ Hook ------------------
function c_message_exclude_dropped(text, channel)
  if channel ~= "plain" then return end

  local exclude
  if text:find("You drop ") then exclude = true
  elseif text:find(" %- ") then exclude = false
  else return
  end

  local item_name = get_excludable_name(text)
  if not item_name then return end

  if exclude then
    add_exclusion(item_name)
  else
    remove_exclusion(item_name)
  end
end


-- Startup logic
for _,v in ipairs(dropped_item_exclusions) do
  add_exclusion(v)
end

-- Missile logic at start of game
local started_with_ranged = false
if CACHE.turn == 0 then
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.is_ranged then
      started_with_ranged = true
      break
    end
  end
  if started_with_ranged then add_exclusions({ " stone", "boomerang" }) end
  if CACHE.size_penalty >= SIZE_PENALTY.LARGE then add_exclusion("large rock") end
end
