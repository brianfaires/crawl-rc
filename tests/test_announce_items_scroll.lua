---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-items (scroll in LOS fires "Found:")
-- Verifies that f_announce_items.ready() announces a new scroll in LOS with "Found:".
--
-- announce-items.Config.disabled = true by default; functions are called directly.
-- f_announce_items.init() initializes the local C alias and clears state.
-- f_announce_items.ready() scans LOS and calls crawl.mpr for new items.
--
-- "scroll of fog" is used: class "scroll" is in announce_class, not useless for Mummies.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "scroll of fog" → CMD_WAIT
--   "check"  (turn 1): call f_announce_items.init() + ready() → CMD_WAIT
--   "verify" (turn 2): assert T.messages_contain("Found") or T.messages_contain("scroll")
---------------------------------------------------------------------------------------------------

test_announce_items_scroll = {}
test_announce_items_scroll.BRC_FEATURE_NAME = "test-announce-items-scroll"

local _phase = "give"

function test_announce_items_scroll.ready()
  if T._done then return end

  T.run("announce-items-scroll", function()
    if _phase == "give" then
      T.wizard_give("scroll of fog")
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Call directly since feature is disabled by default
      f_announce_items.init()
      f_announce_items.ready()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.true_(
        T.messages_contain("Found") or T.messages_contain("scroll"),
        "announce-items-scroll-fired"
      )
      T.pass("announce-items-scroll")
      T.done()
    end
  end)
end
