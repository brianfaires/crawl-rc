---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (scroll of butterflies -- always inscribed)
-- Verifies that scroll of butterflies receives a "!r" inscription.
--
-- "butterflies" is NOT in NO_INSCRIPTION_NEEDED and has no species-specific condition in
-- scroll_needs_inscription(). Therefore scroll_needs_inscription("butterflies") returns true
-- unconditionally for every species, including Mummy Berserker.
--
-- Note: "butterflies" appears in scroll_slots mapped to slot "s" (shared with "summoning").
-- This test confirms that the slot-assignment path does not interfere with inscription logic --
-- both features operate independently in f_manage_consumables.ready().
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → scroll on floor → CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP → scroll in inventory
--   "verify" (turn 2): assert inscription contains "!r"
---------------------------------------------------------------------------------------------------

test_manage_consumables_scroll_butterflies = {}
test_manage_consumables_scroll_butterflies.BRC_FEATURE_NAME = "test-manage-consumables-scroll-butterflies"

local _phase = "give"

function test_manage_consumables_scroll_butterflies.ready()
  if T._done then return end

  T.run("manage-consumables-scroll-butterflies", function()
    if _phase == "give" then
      T.wizard_give("scroll of butterflies")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local scroll = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" and it.subtype() == "butterflies" then
          scroll = it
          break
        end
      end

      T.true_(scroll ~= nil, "scroll-of-butterflies-in-inventory")
      if scroll then
        -- butterflies is NOT in NO_INSCRIPTION_NEEDED and has no species condition →
        -- scroll_needs_inscription returns true → must have !r
        T.true_(scroll.inscription:contains("!r"), "scroll-of-butterflies-has-safe-inscription")
      end
      T.pass("manage-consumables-scroll-butterflies")
      T.done()
    end
  end)
end
