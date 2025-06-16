loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/emojis.lua")
loadfile("crawl-rc/lua/util.lua")

---- Track if found ID yet ----
create_persistent_data("found_scroll_of_id", 0)

---- Remind to identify items when you have scroll of ID + unidentified item ----
local function remind_unidentified_items()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if not inv.is_identified then
      for inv_id in iter.invent_iterator:new(items.inventory()) do
        if inv_id and inv_id.name("qual"):find("scroll of identify") then
          crawl.mpr(
            EMOJI.REMIND_IDENTIFY ..
            " <magenta> You have something to identify. </magenta>" ..
            EMOJI.REMIND_IDENTIFY
          )
          break
        end
      end

      return
    end
  end
end
crawl.setopt("runrest_stop_message += You have something to identify")

------------------- Hooks -------------------
function c_message_remind_identify(text, channel)
  if channel ~= "plain" then return end

  if text:find(" of identify") then
    found_scroll_of_id = 1
    if not text:find("drop") and not text:find("read") then
      remind_unidentified_items()
    end
  elseif found_scroll_of_id == 0 then
    local idx = text:find(" %- ")
    if idx then
      local slot = text:sub(idx - 1, idx - 1)
      local it = items.inslot(items.letter_to_index(slot))
      if it.class(true) == "scroll" and it.quantity >= CONFIG.stop_on_scrolls_count or
          it.class(true) == "potion" and it.quantity >= CONFIG.stop_on_pots_count then
        you.stop_activity()
      end
    end
  end
end

function c_assign_invletter_remind_identify(it)
  if not it.is_identified or it.name("qual"):find("scroll of identify") then
    remind_unidentified_items()
  end
end
