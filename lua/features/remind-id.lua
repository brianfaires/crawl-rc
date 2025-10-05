--[[
Feature: remind-id
Description: Reminds to read ID scrolls, and stops explore on increased stack sizes before finding ID scrolls
Author: buehler
Dependencies: core/config.lua, core/constants.lua, core/data.lua, core/util.lua
--]]

f_remind_id = {}
f_remind_id.BRC_FEATURE_NAME = "remind-id"
f_remind_id.Config = {
  stop_on_scrolls_count = 2, -- Stop when largest un-ID'd scroll stack increases and is >= this
  stop_on_pots_count = 3, -- Stop when largest un-ID'd potion stack increases and is >= this
  emoji = BRC.Config.emojis and "🎁" or BRC.text.magenta("?")
} -- f_remind_id.Config (do not remove this comment)

-- Persistent variables
ri_found_scroll_of_id = BRC.data.persist("ri_found_scroll_of_id", false)

-- Local config
local Config = f_remind_id.Config

-- Local constants / configuration
local IDENTIFY_MSG = BRC.text.magenta(" You have something to identify. ")
if Config.emoji then IDENTIFY_MSG = Config.emoji .. IDENTIFY_MSG .. Config.emoji end

-- Local variables
local do_remind_id_check

-- Local functions
local function get_max_stack(class)
  local max_stack_size = 0
  local slot = nil
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.class(true) == class and not inv.is_identified then
      if inv.quantity > max_stack_size then
        max_stack_size = inv.quantity
        slot = inv.slot
      elseif inv.quantity == max_stack_size then
        slot = nil -- If tied for max, no slot set a new max
      end
    end
  end
  return max_stack_size, slot
end

local function have_scroll_of_id()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.name("qual") == "scroll of identify" then return true end
  end
  return false
end

local function have_unid_item()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if not inv.is_identified then return true end
  end
  return false
end

-- Hook functions
function f_remind_id.init()
  do_remind_id_check = true
end

function f_remind_id.c_assign_invletter(it)
  if not it.is_identified and have_scroll_of_id() or it.name("qual") == "scroll of identify" and have_unid_item() then
    you.stop_activity()
    do_remind_id_check = true
  end
end

function f_remind_id.c_message(text, channel)
  if channel ~= "plain" then return end

  if text:find("scrolls? of identify") then
    ri_found_scroll_of_id = true
    if not text:contains("ou drop ") and have_unid_item() then
      you.stop_activity()
      do_remind_id_check = true
    end
  elseif not ri_found_scroll_of_id then
    local pickup_info = BRC.text.get_pickup_info(text)
    if not pickup_info then return end
    local is_scroll = pickup_info.item:contains("scroll")
    local is_potion = pickup_info.item:contains("potion")
    if not (is_scroll or is_potion) then return end

    local num_scrolls, slot_scrolls = get_max_stack("scroll")
    local num_pots, slot_pots = get_max_stack("potion")
    if is_scroll and num_scrolls >= Config.stop_on_scrolls_count and slot_scrolls == pickup_info.slot
      or is_potion and num_pots >= Config.stop_on_pots_count and slot_pots == pickup_info.slot then
        you.stop_activity()
    end
  end
end

function f_remind_id.ready()
  if do_remind_id_check then
    do_remind_id_check = false
    if have_unid_item() and have_scroll_of_id() then BRC.mpr.stop(IDENTIFY_MSG) end
  end
end
