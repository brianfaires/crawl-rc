---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (NO_INSCRIPTION_NEEDED)
-- Verifies that scrolls in NO_INSCRIPTION_NEEDED do NOT receive a "!r" inscription.
-- "scroll of identify" is in NO_INSCRIPTION_NEEDED, so scroll_needs_inscription returns false.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → scroll on floor → CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP → scroll in inventory; manage-consumables.ready()
--                      sees identify → no inscription added
--   "verify" (turn 2): find scroll in inventory, assert inscription does NOT contain "!r"
---------------------------------------------------------------------------------------------------

test_manage_consumables_no_inscription = {}
test_manage_consumables_no_inscription.BRC_FEATURE_NAME = "test-manage-consumables-no-inscription"

local _phase = "give"

function test_manage_consumables_no_inscription.ready()
  if T._done then return end

  T.run("manage-consumables-no-inscription", function()
    if _phase == "give" then
      T.wizard_give("scroll of identify")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local scroll = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" and it.subtype() == "identify" then
          scroll = it
          break
        end
      end

      T.true_(scroll ~= nil, "scroll-of-id-in-inventory")
      if scroll then
        -- scroll of identify is in NO_INSCRIPTION_NEEDED; must not get !r
        T.false_(scroll.inscription:contains("!r"), "scroll-of-id-no-safe-inscription")
      end
      T.pass("manage-consumables-no-inscription")
      T.done()
    end
  end)
end
