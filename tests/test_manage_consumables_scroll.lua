---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (scroll inscription via CMD_PICKUP)
-- Verifies that f_manage_consumables inscribes a scroll of fear with "!r" after pickup.
--
-- "scroll of fear" is not in NO_INSCRIPTION_NEEDED, so scroll_needs_inscription returns true.
-- CMD_PICKUP picks up the wizard-given scroll; f_manage_consumables.ready() then inscribes it.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → scroll on floor → CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP → scroll in inventory; manage-consumables.ready()
--                      inscribes it with !r in the same turn-1 cycle → CMD_WAIT
--   "verify" (turn 2): find scroll in inventory, assert inscription contains "!r"
---------------------------------------------------------------------------------------------------

test_manage_consumables_scroll = {}
test_manage_consumables_scroll.BRC_FEATURE_NAME = "test-manage-consumables-scroll"

local _phase = "give"

function test_manage_consumables_scroll.ready()
  if T._done then return end

  T.run("manage-consumables-scroll", function()
    if _phase == "give" then
      T.wizard_give("scroll of fear")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      -- Pick up all floor items (should be the scroll of fear only)
      crawl.do_commands({"CMD_PICKUP"})
      -- After returning: scroll is in inventory. manage-consumables.ready() fires
      -- later this same cycle and inscribes it with !r.
      _phase = "verify"

    elseif _phase == "verify" then
      local scroll = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" and it.subtype() == "fear" then
          scroll = it
          break
        end
      end

      T.true_(scroll ~= nil, "scroll-in-inventory")
      if scroll then
        T.true_(scroll.inscription:contains("!r"), "scroll-has-safe-inscription")
      end
      T.pass("manage-consumables-scroll")
      T.done()
    end
  end)
end
