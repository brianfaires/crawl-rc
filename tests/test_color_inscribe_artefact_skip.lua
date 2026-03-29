---------------------------------------------------------------------------------------------------
-- BRC feature test: color-inscribe (c_assign_invletter skips artefacts)
-- Verifies that f_color_inscribe.c_assign_invletter() returns early for artefact items
-- without modifying their inscription.
--
-- "sword of Power" is a Long Blades unrand (auto-identified via wizard_give).
-- Its inscription (whatever it starts with) must be unchanged after the call.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "sword of Power" → CMD_WAIT
--   "verify" (turn 1): find artefact on floor, snapshot inscription, call c_assign_invletter,
--                      assert inscription unchanged; T.done
---------------------------------------------------------------------------------------------------

test_color_inscribe_artefact_skip = {}
test_color_inscribe_artefact_skip.BRC_FEATURE_NAME = "test-color-inscribe-artefact-skip"

local _phase = "give"

function test_color_inscribe_artefact_skip.ready()
  if T._done then return end

  T.run("color-inscribe-artefact-skip", function()
    if _phase == "give" then
      T.wizard_give("sword of Power")
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      local floor_artefact = nil
      for _, it in ipairs(you.floor_items()) do
        if it.artefact then
          floor_artefact = it
          break
        end
      end

      T.true_(floor_artefact ~= nil, "artefact-on-floor")
      if not floor_artefact then T.done() return end

      local inscription_before = floor_artefact.inscription
      f_color_inscribe.c_assign_invletter(floor_artefact)
      local inscription_after = floor_artefact.inscription

      T.eq(inscription_after, inscription_before, "artefact-inscription-unchanged")

      T.pass("color-inscribe-artefact-skip")
      T.done()
    end
  end)
end
