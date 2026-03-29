---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (scroll of fog -- always inscribed)
-- Verifies that scroll of fog receives a "!r" inscription.
--
-- "fog" is NOT in NO_INSCRIPTION_NEEDED and has no species-specific condition in
-- scroll_needs_inscription(). Therefore scroll_needs_inscription("fog") returns true
-- unconditionally for every species, including Mummy Berserker.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → scroll on floor → CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP → scroll in inventory
--   "verify" (turn 2): assert inscription contains "!r"
---------------------------------------------------------------------------------------------------

test_manage_consumables_scroll_fog = {}
test_manage_consumables_scroll_fog.BRC_FEATURE_NAME = "test-manage-consumables-scroll-fog"

local _phase = "give"

function test_manage_consumables_scroll_fog.ready()
  if T._done then return end

  T.run("manage-consumables-scroll-fog", function()
    if _phase == "give" then
      T.wizard_give("scroll of fog")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local scroll = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" and it.subtype() == "fog" then
          scroll = it
          break
        end
      end

      T.true_(scroll ~= nil, "scroll-of-fog-in-inventory")
      if scroll then
        -- fog is NOT in NO_INSCRIPTION_NEEDED and has no species condition →
        -- scroll_needs_inscription returns true → must have !r
        T.true_(scroll.inscription:contains("!r"), "scroll-of-fog-has-safe-inscription")
      end
      T.pass("manage-consumables-scroll-fog")
      T.done()
    end
  end)
end
