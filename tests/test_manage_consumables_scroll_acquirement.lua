---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (scroll of acquirement -- NO_INSCRIPTION_NEEDED)
-- Verifies that scroll of acquirement does NOT receive a "!r" inscription.
--
-- "acquirement" is in NO_INSCRIPTION_NEEDED, so scroll_needs_inscription() returns false.
-- Acquirement is a highly valuable, non-harmful scroll; players must be able to read it freely,
-- so it must never receive a confirmation inscription regardless of species.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → scroll on floor → CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP → scroll in inventory
--   "verify" (turn 2): assert inscription does NOT contain "!r"
---------------------------------------------------------------------------------------------------

test_manage_consumables_scroll_acquirement = {}
test_manage_consumables_scroll_acquirement.BRC_FEATURE_NAME = "test-manage-consumables-scroll-acquirement"

local _phase = "give"

function test_manage_consumables_scroll_acquirement.ready()
  if T._done then return end

  T.run("manage-consumables-scroll-acquirement", function()
    if _phase == "give" then
      T.wizard_give("scroll of acquirement")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local scroll = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" and it.subtype() == "acquirement" then
          scroll = it
          break
        end
      end

      T.true_(scroll ~= nil, "scroll-of-acquirement-in-inventory")
      if scroll then
        -- acquirement is in NO_INSCRIPTION_NEEDED; scroll_needs_inscription returns false
        -- unconditionally → must NOT have !r
        T.false_(scroll.inscription:contains("!r"), "scroll-of-acquirement-no-safe-inscription")
      end
      T.pass("manage-consumables-scroll-acquirement")
      T.done()
    end
  end)
end
