---------------------------------------------------------------------------------------------------
-- BRC feature module: manage-consumables
-- @module f_manage_consumables
-- Features for consumable management. Same as crawl's built-in options, without gaps in coverage.
-- safe_scrolls / safe_potions: !r and !q inscriptions. A more consistent version of autoinscribe.
-- slots: A more consistent version of crawl's item_slot option.
---------------------------------------------------------------------------------------------------

f_manage_consumables = {}
f_manage_consumables.BRC_FEATURE_NAME = "manage-consumables"
f_manage_consumables.Config = {
  maintain_safe_scrolls = true,
  maintain_safe_potions = true,
  scroll_slots = {
    ["acquirement"] = "A",
    ["amnesia"] = "x",
    ["blinking"] = "B",
    ["brand weapon"] = "W",
    ["butterflies"] = "s",
    ["enchant armour"] = "a",
    ["enchant weapon"] = "w",
    ["fear"] = "f",
    ["fog"] = "g",
    ["identify"] = "i",
    ["immolation"] = "I",
    ["noise"] = "N",
    ["revelation"] = "r",
    ["poison"] = "p",
    ["silence"] = "S",
    ["summoning"] = "s",
    ["teleportation"] = "t",
    ["torment"] = "T",
    ["vulnerability"] = "V",
  },
  potion_slots = {
    ["ambrosia"] = "a",
    ["attraction"] = "A",
    ["berserk rage"] = "B",
    ["brilliance"] = "b",
    ["cancellation"] = "C",
    ["curing"] = "c",
    ["experience"] = "E",
    ["enlightenment"] = "e",
    ["haste"] = "h",
    ["heal wounds"] = "w",
    ["invisibility"] = "i",
    ["lignification"] = "L",
    ["magic"] = "g",
    ["might"] = "z",
    ["resistance"] = "r",
    ["mutation"] = "M",
  },
} -- f_manage_consumables.Config

---- Local constants ----
local NO_INSCRIPTION_NEEDED = {
  "acquirement", "amnesia", "blinking", "brand weapon", "enchant armour", "enchant weapon",
  "identify", "immolation", "noise", "vulnerability", "attraction", "lignification", "mutation",
} -- NO_INSCRIPTION_NEEDED (do not remove this comment)
local SCROLL_CLASS = "scroll"
local POTION_CLASS = "potion"
local SCROLL_INSCR = "!r"
local POTION_INSCR = "!q"
local SCROLL_PATT = "%!r"
local POTION_PATT = "%!q"

---- Local variables ----
local C -- config alias
local found_scroll
local found_potion

---- Initialization ----
function f_manage_consumables.init()
  C = f_manage_consumables.Config
  C.scroll_slots = C.scroll_slots or {}
  C.potion_slots = C.potion_slots or {}
  found_scroll = nil
  found_potion = nil

  -- These options must use += to override crawl defaults
  for st, slot in pairs(C.scroll_slots) do
    crawl.setopt("consumable_shortcut += scroll of " .. st .. ":" .. slot)
  end
  for st, slot in pairs(C.potion_slots) do
    --crawl.setopt("consumable_shortcut ^= potion of " .. st .. ":" .. slot)
    crawl.setopt("consumable_shortcut += potion of " .. st .. ":" .. slot)
  end
end

---- Local functions ----
local function potion_needs_inscription(st)
  return not util.contains(NO_INSCRIPTION_NEEDED, st)
end

local function scroll_needs_inscription(st)
  if util.contains(NO_INSCRIPTION_NEEDED, st) then return false end
  if st == "poison" then return you.res_poison() > 0 end
  if st == "torment" then return you.torment_immune() end
  return true
end

local function change_slot(old_slot, new_slot, name, class)
  if old_slot == new_slot then return end
  BRC.mpr.lightgreen(" " .. BRC.txt.lightgrey(old_slot .. " -> ") .. new_slot .. " - " .. name)
  BRC.opt.single_turn_mute("Adjust")
  BRC.opt.single_turn_mute(" - ")
  local class_key = class == SCROLL_CLASS and "r" or "p"
  crawl.sendkeys("=" .. class_key .. old_slot .. new_slot)
end

local function maintain_slots()
  if found_scroll then
    local new_slot = C.scroll_slots[found_scroll]
    if new_slot then
      for _, inv in ipairs(items.inventory()) do
        if inv.class(true) == SCROLL_CLASS and inv.subtype() == found_scroll then
          change_slot(items.index_to_letter(inv.slot), new_slot, inv.name(), SCROLL_CLASS)
          break
        end
      end
    end
    found_scroll = nil
  elseif found_potion then
    local new_slot = C.potion_slots[found_potion]
    if new_slot then
      for _, inv in ipairs(items.inventory()) do
        if inv.class(true) == POTION_CLASS and inv.subtype() == found_potion then
          change_slot(items.index_to_letter(inv.slot), new_slot, inv.name(), POTION_CLASS)
          break
        end
      end
    end
    found_potion = nil
  end
end

local function maintain_inscriptions()
  if not (C.maintain_safe_scrolls or C.maintain_safe_potions) then return end
  for _, inv in ipairs(items.inventory()) do
    local inv_class = inv.class(true)
    if inv_class == SCROLL_CLASS and C.maintain_safe_scrolls then
      if scroll_needs_inscription(inv.subtype()) then
        if not inv.inscription:contains(SCROLL_INSCR) then inv.inscribe(SCROLL_INSCR) end
      elseif inv.inscription:contains(SCROLL_INSCR) then
        inv.inscribe(inv.inscription:gsub(SCROLL_PATT, ""), false)
      end
    elseif inv_class == POTION_CLASS and C.maintain_safe_potions then
      if potion_needs_inscription(inv.subtype()) then
        if not inv.inscription:contains(POTION_INSCR) then inv.inscribe(POTION_INSCR) end
      elseif inv.inscription:contains(POTION_INSCR) then
        inv.inscribe(inv.inscription:gsub(POTION_PATT, ""), false)
      end
    end
  end
end

---- Crawl hook functions ----
function f_manage_consumables.c_message(text, _)
  if next(C.scroll_slots) then
    local _, last = text:find(" .[^s]?s a scroll of ")
    if last then
      found_scroll = text:sub(last + 1, #text - 1)
      return
    end
  end

  if next(C.potion_slots) then
    local _, last = text:find(" .[^s]?s a potion of ")
    if last then
      found_potion = text:sub(last + 1, #text - 1)
      return
    end
  end
end

function f_manage_consumables.ready()
  maintain_slots()
  maintain_inscriptions()
end
