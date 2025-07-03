---- Remind to identify items when you have scroll of ID + unidentified item ----
---- Before finding scroll of ID, stops for potions/scrolls stack size increases ----
local function remind_unidentified_items(have_scroll, have_unidentified)
  if not have_unidentified then
    for inv in iter.invent_iterator:new(items.inventory()) do
      if not inv.is_identified then
        have_unidentified = true
        break
      end
    end
  end

  if not have_scroll then
    for inv_id in iter.invent_iterator:new(items.inventory()) do
      if inv_id.name("qual") == "scroll of identify" then
        have_scroll = true
        break
      end
    end
  end

  if have_scroll and have_unidentified then
    mpr_with_stop(
      EMOJI.REMIND_IDENTIFY ..
      with_color(COLORS.magenta, " You have something to identify. ") ..
      EMOJI.REMIND_IDENTIFY
    )
  end
end

function init_remind_id()
  if CONFIG.debug_init then crawl.mpr("Initializing remind-id") end

  create_persistent_data("found_scroll_of_id", 0)
  create_persistent_data("next_stack_size_scrolls", CONFIG.stop_on_scrolls_count)
  create_persistent_data("next_stack_size_pots", CONFIG.stop_on_pots_count)
end


------------------- Hooks -------------------
function c_assign_invletter_remind_identify(it)
  if not it.is_identified then
    remind_unidentified_items(false, true)
  elseif it.name("qual") == "scroll of identify" then
    remind_unidentified_items(true, false)
  end
end

function c_message_remind_identify(text, channel)
  if channel ~= "plain" then return end

  if text:find("scrolls? of identify") then
    found_scroll_of_id = 1
    if not (text:find("You drop") or text:find("You read")) then
      remind_unidentified_items(true, false)
    end
  elseif found_scroll_of_id == 0 then
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
