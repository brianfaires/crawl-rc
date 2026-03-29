---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-items (wand in LOS fires "Found:")
-- Verifies that f_announce_items.ready() announces a wand in LOS.
-- "wand" is in announce_class; wands are not autopicked up and not useless for Mummies.
--
-- Also verifies the announce_glowing path indirectly: since wands are unidentified
-- by default, and not artefacts/branded, they hit the announce_class fallthrough.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "wand of acid" → CMD_WAIT
--   "check"  (turn 1): assert wand on floor; init() + ready() → CMD_WAIT
--   "verify" (turn 2): assert T.messages_contain("Found")
---------------------------------------------------------------------------------------------------

test_announce_items_wand = {}
test_announce_items_wand.BRC_FEATURE_NAME = "test-announce-items-wand"

local _phase = "give"

function test_announce_items_wand.ready()
  if T._done then return end

  T.run("announce-items-wand", function()
    if _phase == "give" then
      T.wizard_give("wand of acid")
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      local floor_wand = nil
      for _, it in ipairs(you.floor_items()) do
        if it.class(true):lower() == "wand" then
          floor_wand = it
          break
        end
      end

      T.true_(floor_wand ~= nil, "wand-on-floor")
      if not floor_wand then T.done() return end

      f_announce_items.init()
      f_announce_items.ready()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.true_(T.messages_contain("Found"), "announce-wand-fired")
      T.pass("announce-items-wand")
      T.done()
    end
  end)
end
