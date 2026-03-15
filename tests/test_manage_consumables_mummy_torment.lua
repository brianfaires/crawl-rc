---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (Mummy + scroll of torment)
-- Verifies species-specific scroll inscription logic.
--
-- scroll_needs_inscription("torment") returns you.torment_immune().
-- Mummies are undead and torment-immune, so you.torment_immune() returns true.
-- Therefore scroll of torment SHOULD receive "!r" for a Mummy character.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify → scroll on floor → CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP → scroll in inventory
--   "verify" (turn 2): assert inscription contains "!r"
---------------------------------------------------------------------------------------------------

test_manage_consumables_mummy_torment = {}
test_manage_consumables_mummy_torment.BRC_FEATURE_NAME = "test-manage-consumables-mummy-torment"

local _phase = "give"

function test_manage_consumables_mummy_torment.ready()
  if T._done then return end

  T.run("manage-consumables-mummy-torment", function()
    if _phase == "give" then
      T.wizard_give("scroll of torment")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      local scroll = nil
      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" and it.subtype() == "torment" then
          scroll = it
          break
        end
      end

      T.true_(scroll ~= nil, "scroll-of-torment-in-inventory")
      if scroll then
        -- Prerequisite: Mummy is torment-immune (the condition scroll_needs_inscription checks)
        T.true_(you.torment_immune(), "mummy-is-torment-immune")
        -- scroll of torment needs !r when you are torment-immune (it becomes a useful weapon)
        T.true_(scroll.inscription:contains("!r"), "scroll-of-torment-has-safe-inscription")
      end
      T.pass("manage-consumables-mummy-torment")
      T.done()
    end
  end)
end
