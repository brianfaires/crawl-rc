-- @species Po
-- @background Be
-- @weapon mace
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Poltergeist race table classification + 6 aux slots)
-- Poltergeist is in UNDEAD_RACES and POIS_RES_RACES.
-- mutation_immune() and miasma_immune() both return true.
-- As a ghost, Poltergeist has 6 aux equipment slots (num_eq_slots for aux armour returns 6).
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_poltergeist = {}
test_dynamic_options_race_poltergeist.BRC_FEATURE_NAME = "test-dynamic-options-race-poltergeist"

local _phase = "give"

function test_dynamic_options_race_poltergeist.ready()
  if T._done then return end

  T.run("dynamic-options-race-poltergeist", function()

    if _phase == "give" then
      T.wizard_give("helmet")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      local race = you.race()
      T.eq(race, "Poltergeist", "char-is-poltergeist")

      T.true_(util.contains(BRC.UNDEAD_RACES,     race), "poltergeist-undead")
      T.true_(util.contains(BRC.POIS_RES_RACES,   race), "poltergeist-pois-res")
      T.false_(util.contains(BRC.NONLIVING_RACES, race), "poltergeist-not-nonliving")

      T.true_(BRC.you.mutation_immune(), "poltergeist-mutation-immune")
      T.true_(BRC.you.miasma_immune(), "poltergeist-miasma-immune")

      T.true_(BRC.eq.is_useless_ego("holy"),  "poltergeist-holy-useless")
      T.true_(BRC.eq.is_useless_ego("rPois"), "poltergeist-rpois-useless")

      -- Find the wizard-given helmet on floor (or in inventory if autopickup fired)
      local floor_helmet = nil
      for _, it in ipairs(you.floor_items()) do
        if it.name():find("helmet") then
          floor_helmet = it
          break
        end
      end
      if not floor_helmet then
        -- Check inventory if autopickup consumed it
        for _, it in ipairs(items.inventory()) do
          if it.name():find("helmet") then
            floor_helmet = it
            break
          end
        end
      end
      T.true_(floor_helmet ~= nil, "helmet-found")
      if not floor_helmet then T.done() return end

      T.eq(BRC.you.num_eq_slots(floor_helmet), 6, "poltergeist-6-aux-slots")

      T.pass("dynamic-options-race-poltergeist")
      T.done()
    end
  end)
end
