---------------------------------------------------------------------------------------------------
-- BRC feature test: manage-consumables (scroll inscription variants for Mummies)
-- Verifies NO_INSCRIPTION_NEEDED behavior vs. always-inscribed scrolls for a Mummy character.
--
-- Scrolls under test:
--   1. scroll of immolation   -- in NO_INSCRIPTION_NEEDED → should NOT get !r (even for Mummies
--                                who lack innate rFire and could be harmed by it)
--   2. scroll of vulnerability -- in NO_INSCRIPTION_NEEDED → should NOT get !r (even though it
--                                strips all resistances, which is particularly risky for Mummies)
--   3. scroll of teleportation -- NOT in NO_INSCRIPTION_NEEDED, no species condition →
--                                always gets !r regardless of species
--   4. scroll of silence       -- NOT in NO_INSCRIPTION_NEEDED, no species condition →
--                                always gets !r regardless of species
--
-- The test exercises the NO_INSCRIPTION_NEEDED list explicitly: immolation and vulnerability
-- are listed there, so scroll_needs_inscription() returns false for them unconditionally,
-- regardless of who is carrying them. teleportation and silence are NOT listed, so they always
-- return true from scroll_needs_inscription().
--
-- Phase flow (four give→pickup cycles, each followed by a verify turn):
--   "give_immolation"    (turn 0): wizard_give scroll of immolation → CMD_WAIT
--   "pickup_immolation"  (turn 1): CMD_PICKUP → CMD_WAIT
--   "give_vulnerability" (turn 2): wizard_give scroll of vulnerability → CMD_WAIT
--   "pickup_vulnerability" (turn 3): CMD_PICKUP → CMD_WAIT
--   "give_teleportation" (turn 4): wizard_give scroll of teleportation → CMD_WAIT
--   "pickup_teleportation" (turn 5): CMD_PICKUP → CMD_WAIT
--   "give_silence"       (turn 6): wizard_give scroll of silence → CMD_WAIT
--   "pickup_silence"     (turn 7): CMD_PICKUP → CMD_WAIT
--   "verify"             (turn 8): assert all four scrolls have correct inscriptions
---------------------------------------------------------------------------------------------------

test_manage_consumables_scroll_variants = {}
test_manage_consumables_scroll_variants.BRC_FEATURE_NAME = "test-manage-consumables-scroll-variants"

local _phase = "give_immolation"

function test_manage_consumables_scroll_variants.ready()
  if T._done then return end

  T.run("manage-consumables-scroll-variants", function()

    if _phase == "give_immolation" then
      T.wizard_give("scroll of immolation")
      T.wizard_identify_all()
      _phase = "pickup_immolation"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup_immolation" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give_vulnerability"

    elseif _phase == "give_vulnerability" then
      T.wizard_give("scroll of vulnerability")
      T.wizard_identify_all()
      _phase = "pickup_vulnerability"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup_vulnerability" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give_teleportation"

    elseif _phase == "give_teleportation" then
      T.wizard_give("scroll of teleportation")
      T.wizard_identify_all()
      _phase = "pickup_teleportation"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup_teleportation" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give_silence"

    elseif _phase == "give_silence" then
      T.wizard_give("scroll of silence")
      T.wizard_identify_all()
      _phase = "pickup_silence"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup_silence" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      -- Collect all four scrolls from inventory
      local scroll_immolation    = nil
      local scroll_vulnerability = nil
      local scroll_teleportation = nil
      local scroll_silence       = nil

      for _, it in ipairs(items.inventory()) do
        if it.class(true) == "scroll" then
          local st = it.subtype()
          if st == "immolation"    then scroll_immolation    = it
          elseif st == "vulnerability" then scroll_vulnerability = it
          elseif st == "teleportation" then scroll_teleportation = it
          elseif st == "silence"       then scroll_silence       = it
          end
        end
      end

      -- Confirm all four are present
      T.true_(scroll_immolation    ~= nil, "scroll-immolation-in-inventory")
      T.true_(scroll_vulnerability ~= nil, "scroll-vulnerability-in-inventory")
      T.true_(scroll_teleportation ~= nil, "scroll-teleportation-in-inventory")
      T.true_(scroll_silence       ~= nil, "scroll-silence-in-inventory")

      -- scroll of immolation: in NO_INSCRIPTION_NEEDED → must NOT have !r
      -- (scroll_needs_inscription returns false unconditionally; Mummy status is irrelevant)
      if scroll_immolation then
        T.false_(
          scroll_immolation.inscription:contains("!r"),
          "scroll-immolation-no-safe-inscription"
        )
      end

      -- scroll of vulnerability: in NO_INSCRIPTION_NEEDED → must NOT have !r
      -- (strips all resistances, but the design deliberately omits !r here)
      if scroll_vulnerability then
        T.false_(
          scroll_vulnerability.inscription:contains("!r"),
          "scroll-vulnerability-no-safe-inscription"
        )
      end

      -- scroll of teleportation: NOT in NO_INSCRIPTION_NEEDED, no species condition →
      -- scroll_needs_inscription returns true → must have !r
      if scroll_teleportation then
        T.true_(
          scroll_teleportation.inscription:contains("!r"),
          "scroll-teleportation-has-safe-inscription"
        )
      end

      -- scroll of silence: NOT in NO_INSCRIPTION_NEEDED, no species condition →
      -- scroll_needs_inscription returns true → must have !r
      if scroll_silence then
        T.true_(
          scroll_silence.inscription:contains("!r"),
          "scroll-silence-has-safe-inscription"
        )
      end

      T.pass("manage-consumables-scroll-variants")
      T.done()
    end
  end)
end
