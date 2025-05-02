-- Add autopickup exclusion for any jewellery/missile/evocable item that is dropped
-- Exclusion is removed when you pick the item back up
-- Also exclude scrolls of enchant weapon/brand weapon, when no enchantable weapons are in inventory
if loaded_exclude_dropped then return end
local loaded_exclude_dropped = true
loadfile("crawl-rc/lua/constants.lua")

---------------- Persistent data ----------------
if not dropped_item_exclusions or you.turns() == 0 then
  dropped_item_exclusions = ""
end
local function persist_dropped_item_exclusions()
  return "dropped_item_exclusions = \""..dropped_item_exclusions.."\""..string.char(10)
end
table.insert(chk_lua_save, persist_dropped_item_exclusions)

-- Init autopickup missiles
local started_with_ranged = false
if you.skill("Ranged Weapons") > 2 then
  for it in iter.invent_iterator:new(items.inventory()) do
    if it.is_ranged then
      started_with_ranged = true
      break
    end
  end
end
if not started_with_ranged then crawl.setopt("autopickup_exceptions ^= < stone, <boomerang") end
crawl.setopt("autopickup_exceptions ^= <dart, <javelin")
if get_race_armour_penalty() >= RACE_SIZE.VERY_LARGE then crawl.setopt("autopickup_exceptions ^= <large rock") end

if dropped_item_exclusions ~= "" then crawl.setopt("autopickup_exceptions ^= "..dropped_item_exclusions) end

local function get_jewellery_name(text)
  local idx  = text:find("ring of ")
  if not idx then idx = text:find("amulet of ") end
  if not idx then return end

  text = text:gsub(" {.*}", "")
  text = text:gsub("[.]", "")
  return text:sub(idx,#text)
end

local function get_missile_name(text)
  for item_name in iter.invent_iterator:new(all_missiles) do
    if text:find(item_name) then
      if item_name == "boomerang" or item_name == "javelin" then
        if text:find("silver") then
          item_name = "silver "..item_name
        elseif text:find("dispersal") then
          item_name = item_name.."s? of dispersal"
        else
          item_name = "(?<!silver )"..item_name.."(?!(s? of dispersal))"
        end
      end

      return item_name
    end
  end
end

local function get_misc_name(text)
  for item_name in iter.invent_iterator:new(all_misc) do
    if text:find(item_name) then return item_name end
  end
end

local function has_enchantable_weap_in_inv()
  for cur in iter.invent_iterator:new(items.inventory()) do
    if cur.class(true) == "weapon" and not cur.artefact and cur.plus < 9 then return true end
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
    crawl.setopt("autopickup_exceptions ^= >"..item_name)
    if dropped_item_exclusions ~= "" then dropped_item_exclusions = dropped_item_exclusions.."," end
    dropped_item_exclusions = dropped_item_exclusions..">"..item_name
  else
    crawl.setopt("autopickup_exceptions -= >"..item_name)
    -- Remove persistent exclusion (try 3 times to make sure we capture comma)
    dropped_item_exclusions = dropped_item_exclusions:gsub(",>"..item_name, "")
    dropped_item_exclusions = dropped_item_exclusions:gsub(">"..item_name..",", "")
    dropped_item_exclusions = dropped_item_exclusions:gsub(">"..item_name, "")
  end
end