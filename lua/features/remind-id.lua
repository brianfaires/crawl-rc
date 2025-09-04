--[[
Feature: remind-id
Description: Reminds to read ID scrolls, and stops explore on increased stack sizes before finding ID scrolls
Author: buehler
Dependencies: CONFIG, COLORS, EMOJI, BRC.util.color, iter, persistent_data
--]]

f_remind_id = {}
f_remind_id.BRC_FEATURE_NAME = "remind-id"

-- Persistent variables
ri_max_scroll_stack = BRC.data.create("ri_max_scroll_stack", BRC.Config.stop_on_scrolls_count - 1)
ri_max_potion_stack = BRC.data.create("ri_max_potion_stack", BRC.Config.stop_on_pots_count - 1)
found_scroll_of_id = BRC.data.create("found_scroll_of_id", false)

-- Local constants / configuration
local IDENTIFY_MSG = BRC.util.color(COLORS.magenta, " You have something to identify. ")

-- Local variables
local do_remind_id_check

-- Local functions
local function alert_remind_identify()
  BRC.mpr.stop(BRC.Emoji.REMIND_ID .. IDENTIFY_MSG .. BRC.Emoji.REMIND_ID)
end

local function get_max_stack_size(class, skip_slot)
  local max_stack_size = 0
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.quantity > max_stack_size
      and inv.class(true) == class
      and inv.slot ~= skip_slot
      and not inv.is_identified
    then
      max_stack_size = inv.quantity
    end
  end
  return max_stack_size
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
  if not it.is_identified then
    if have_scroll_of_id() then
      you.stop_activity()
      do_remind_id_check = true
      return
    end
  elseif it.name("qual") == "scroll of identify" then
    if have_unid_item() then
      you.stop_activity()
      do_remind_id_check = true
      return
    end
  end
end

function f_remind_id.c_message(text, channel)
  if channel ~= "plain" then return end

  if text:find("scrolls? of identify") then
    found_scroll_of_id = true
    if not text:find("ou drop ", 1, true) and have_unid_item() then
      you.stop_activity()
      do_remind_id_check = true
    end
  elseif not found_scroll_of_id then
    -- Pre-ID: Stop when largest stack of pots/scrolls increases
    local idx = text:find(" %- ")
    if not idx then return end

    local slot = items.letter_to_index(text:sub(idx - 1, idx - 1))
    local it = items.inslot(slot)

    if it.is_identified then return end
    -- Picking up known items still returns identified == false
    -- Doing some hacky checks below instead

    local it_class = it.class(true)
    if it_class == "scroll" then
      if it.quantity > math.max(ri_max_scroll_stack, get_max_stack_size("scroll", slot)) then
        you.stop_activity()
        ri_max_scroll_stack = it.quantity
      end
    elseif it_class == "potion" then
      if it.quantity > math.max(ri_max_potion_stack, get_max_stack_size("potion", slot)) then
        you.stop_activity()
        ri_max_potion_stack = it.quantity
      end
    end
  end
end

function f_remind_id.ready()
  if do_remind_id_check then
    do_remind_id_check = false
    if have_unid_item() and have_scroll_of_id() then alert_remind_identify() end
  end
end
