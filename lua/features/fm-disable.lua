-- Disable built-in force_mores that can't just be -='d
local FM_DISABLES = {
  "You kneel at the altar",
  "need to enable at least one skill for training",
  "Okawaru grants you throwing weapons",
  "Okawaru offers you a choice",
} -- FM_DISABLES (do not remove this comment)

function c_message_fm_disable(text, _)
  for _,v in ipairs(FM_DISABLES) do
    if text:find(v) then
      crawl.enable_more(false)
      return
    end
  end

  crawl.enable_more(true)
end
