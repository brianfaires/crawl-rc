---- Remind to identify items when you have scroll of ID + unidentified item ----
---- Before finding scroll of ID, stops for potions/scrolls stack size increases ----
local do_remind_id_check

local function alert_remind_identify()
  crawl.mpr(
    EMOJI.REMIND_IDENTIFY ..
    with_color(COLORS.magenta, " You have something to identify. ") ..
    EMOJI.REMIND_IDENTIFY
  )
end

local function have_scroll_of_id()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if inv.name("qual") == "scroll of identify" then
      return true
    end
  end
  return false
end

local function have_unid_item()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if not inv.is_identified then
      return true
    end
  end
  return false
end

function init_remind_id()
  if CONFIG.debug_init then crawl.mpr("Initializing remind-id") end

  do_remind_id_check = true
  create_persistent_data("found_scroll_of_id", false)
  create_persistent_data("next_stack_size_scrolls", CONFIG.stop_on_scrolls_count)
  create_persistent_data("next_stack_size_pots", CONFIG.stop_on_pots_count)
end

------------------- Hooks -------------------
function c_assign_invletter_remind_identify(it)
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

function c_message_remind_identify(text, channel)
  if channel ~= "plain" then return end

  if text:find("scrolls? of identify") then
    found_scroll_of_id = true
    if not text:find("ou drop ", 1, true) and have_unid_item() then
      you.stop_activity()
      do_remind_id_check = true
    end
  elseif not found_scroll_of_id then
    local idx = text:find(" %- ")
    if not idx then return end

    local slot = text:sub(idx - 1, idx - 1)
    local it = items.inslot(items.letter_to_index(slot))

    if it.is_identified then return end
    -- Picking up known items still returns identified == false
    -- Doing some hacky checks below instead

    local it_class = it.class(true)
    if it_class == "scroll" then
      if it.quantity >= next_stack_size_scrolls then
        next_stack_size_scrolls = it.quantity + 1
        you.stop_activity()
      end
    elseif it_class == "potion" then
      if it.quantity >= next_stack_size_pots then
        next_stack_size_pots = it.quantity + 1
        you.stop_activity()
      end
    end
  end
end

function ready_remind_identify()
  if do_remind_id_check then
    do_remind_id_check = false
    if have_unid_item() and have_scroll_of_id() then
      alert_remind_identify()
      you.stop_activity()
    end
  end
end
