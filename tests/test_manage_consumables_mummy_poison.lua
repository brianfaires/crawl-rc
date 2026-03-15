---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (Mummy + scroll of poison)
-- Verifies species-specific scroll inscription logic.
--
-- scroll_needs_inscription("poison") returns you.res_poison() > 0.
-- Mummies are in BRC.POIS_RES_RACES (immune to poison), so you.res_poison() > 0.
-- Therefore scroll of poison SHOULD receive "!r" for a Mummy character.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → scroll on floor → CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP → scroll in inventory
--   "verify" (turn 2): assert inscription contains "!r"
---------------------------------------------------------------------------------------------------

test_manage_consumables_mummy_poison = {}
test_manage_consumables_mummy_poison.BRC_FEATURE_NAME = "test-manage-consumables-mummy-poison"

local _phase = "give"

function test_manage_consumables_mummy_poison.ready()
  if T._done then return end

  T.run("manage-consumables-mummy-poison", function()
    if _phase == "give" then
      T.wizard_give("scroll of poison")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local scroll = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" and it.subtype() == "poison" then
          scroll = it
          break
        end
      end

      T.true_(scroll ~= nil, "scroll-of-poison-in-inventory")
      if scroll then
        -- Prerequisite: Mummy has rPois (the condition scroll_needs_inscription checks)
        T.true_(you.res_poison() > 0, "mummy-has-rpois")
        -- scroll of poison needs !r when you have poison resistance
        T.true_(scroll.inscription:contains("!r"), "scroll-of-poison-has-safe-inscription")
      end
      T.pass("manage-consumables-mummy-poison")
      T.done()
    end
  end)
end
