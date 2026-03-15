---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (remove !r when not needed)
-- Verifies that manage-consumables.ready() removes a "!r" inscription from a scroll that
-- does NOT need it (i.e., is in NO_INSCRIPTION_NEEDED).
--
-- scroll of amnesia is in NO_INSCRIPTION_NEEDED → scroll_needs_inscription returns false.
-- The code branch: elseif inv.inscription:contains(SCROLL_INSCR) then ... strips it.
-- So manually pre-inscribing "!r" on the scroll should be cleaned up on the next ready().
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → scroll on floor → CMD_WAIT
--   "pickup" (turn 1): manually inscribe "!r" on floor item, then CMD_PICKUP
--   "verify" (turn 2): assert inscription does NOT contain "!r" (was removed)
---------------------------------------------------------------------------------------------------

test_manage_consumables_remove_inscription = {}
test_manage_consumables_remove_inscription.BRC_FEATURE_NAME = "test-manage-consumables-remove-inscription"

local _phase = "give"

function test_manage_consumables_remove_inscription.ready()
  if T._done then return end

  T.run("manage-consumables-remove-inscription", function()
    if _phase == "give" then
      T.wizard_give("scroll of amnesia")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      -- Find the scroll on the floor and manually inscribe "!r"
      local scroll = nil
      for _, it in ipairs(you.floor_items()) do
        if it.class(true) == "scroll" and it.subtype() == "amnesia" then
          scroll = it
          break
        end
      end
      T.true_(scroll ~= nil, "amnesia-scroll-on-floor")
      if scroll then
        scroll.inscribe("!r", false)
        T.true_(scroll.inscription:contains("!r"), "manually-inscribed-!r")
      end
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local scroll = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" and it.subtype() == "amnesia" then
          scroll = it
          break
        end
      end
      T.true_(scroll ~= nil, "amnesia-scroll-in-inventory")
      if scroll then
        -- amnesia is in NO_INSCRIPTION_NEEDED; manage-consumables should have removed "!r"
        T.false_(scroll.inscription:contains("!r"), "wrong-inscription-removed")
      end
      T.pass("manage-consumables-remove-inscription")
      T.done()
    end
  end)
end
