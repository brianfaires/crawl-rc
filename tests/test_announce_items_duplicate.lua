---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-items (duplicate consumable at 0,0 fires "Duplicate:")
-- Verifies the announce_duplicate_consumables path: when standing on an unidentified
-- scroll that matches one in inventory, "Duplicate: ..." is printed.
--
-- f_announce_items.ready() uses items.get_items_at() which reads map_knowledge cache.
-- Map knowledge is refreshed at turn boundaries, so wizard_give and ready() must be
-- in different turns (CMD_WAIT in between).
--
-- Phase flow:
--   "give-first"  (turn 0): wizard_give "scroll of fog" → CMD_WAIT
--   "pickup"      (turn 1): CMD_PICKUP (picks up scroll; real action, ends turn itself)
--   "give-second" (turn 2): wizard_give "scroll of fog" → CMD_WAIT (refresh map knowledge)
--   "check"       (turn 3): assert preconditions; init() + ready() → CMD_WAIT
--   "verify"      (turn 4): assert T.messages_contain("Duplicate")
---------------------------------------------------------------------------------------------------

test_announce_items_duplicate = {}
test_announce_items_duplicate.BRC_FEATURE_NAME = "test-announce-items-duplicate"

local _phase = "give-first"

function test_announce_items_duplicate.ready()
  if T._done then return end

  T.run("announce-items-duplicate", function()
    if _phase == "give-first" then
      T.wizard_give("scroll of fog")
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      -- CMD_PICKUP is a real turn action — no CMD_WAIT needed after it
      _phase = "give-second"
      crawl.do_commands({"CMD_PICKUP"})

    elseif _phase == "give-second" then
      T.wizard_give("scroll of fog")
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"}) -- let map knowledge refresh before ready()

    elseif _phase == "check" then
      -- Preconditions
      local has_in_inv = false
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" then has_in_inv = true; break end
      end
      T.true_(has_in_inv, "scroll-in-inventory")
      if not has_in_inv then T.done() return end

      local floor_scroll = nil
      for _, it in ipairs(you.floor_items()) do
        if it.class(true) == "scroll" then floor_scroll = it; break end
      end
      T.true_(floor_scroll ~= nil, "scroll-on-floor")
      if not floor_scroll then T.done() return end

      T.true_(not floor_scroll.is_identified, "floor-scroll-unidentified")

      f_announce_items.init()
      f_announce_items.ready()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.true_(T.messages_contain("Duplicate"), "duplicate-consumable-fired")
      T.pass("announce-items-duplicate")
      T.done()
    end
  end)
end
