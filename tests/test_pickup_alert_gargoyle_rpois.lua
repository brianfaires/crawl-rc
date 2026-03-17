-- @species Gr
-- @background Be
-- @weapon mace
---------------------------------------------------------------------------------------------------
-- BRC feature test: is_useless_ego rPois case-sensitivity bug (Gargoyle)
--
-- BRC.POIS_RES_RACES includes "Gargoyle", so rPois armour should be useless for Gargoyle.
-- BRC.NONLIVING_RACES includes "Gargoyle", so BRC.you.miasma_immune() should return true.
--
-- FIXED BUG (was: checked `ego == "rPois"` but crawl's it.ego(true) returns "poison resistance"
-- as the full display name; get_ego() lowercases to "poison resistance" before calling
-- is_useless_ego. Fixed by changing the check to `ego == "poison resistance"`.
--
-- Phase flow:
--   "give"   (turn 0): wizard-give robe of poison resistance, identify, CMD_WAIT
--   "verify" (turn 1): check raw ego string, is_useless_ego both cases, get_ego, miasma_immune
---------------------------------------------------------------------------------------------------

test_pickup_alert_gargoyle_rpois = {}
test_pickup_alert_gargoyle_rpois.BRC_FEATURE_NAME = "test-pickup-alert-gargoyle-rpois"

local _phase = "give"

function test_pickup_alert_gargoyle_rpois.ready()
  if T._done then return end

  T.run("pickup-alert-gargoyle-rpois", function()

    if _phase == "give" then
      T.wizard_give("robe ego:poison_resistance")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Confirm character
      T.eq(you.race(), "Gargoyle", "char-is-gargoyle")

      -- Gargoyle is in NONLIVING_RACES → miasma_immune() must be true
      T.true_(BRC.you.miasma_immune(), "gargoyle-miasma-immune")

      -- Find the robe on the floor
      local robe = nil
      for _, it in ipairs(you.floor_items()) do
        local n = it.name()
        if n:find("robe") then
          robe = it
          break
        end
      end
      T.true_(robe ~= nil, "rpois-robe-on-floor")
      if not robe then T.done() return end

      -- Inspect the raw ego string crawl returns for the item
      local raw_ego = robe.ego(true)
      -- crawl returns "poison resistance" (full display name, not short tag "rPois")
      T.true_(raw_ego ~= nil, "raw-ego-not-nil")
      T.true_(raw_ego ~= "", "raw-ego-not-empty")

      -- Both ego string forms must work: full display name and short tag
      T.true_(BRC.eq.is_useless_ego("poison resistance"), "is_useless_ego-poison-resistance-true")
      T.true_(BRC.eq.is_useless_ego("rpois"), "is_useless_ego-rpois-short-tag-true")

      -- get_ego() on the robe should return nil for Gargoyle (useless ego → suppressed)
      local processed_ego = BRC.eq.get_ego(robe)
      T.true_(processed_ego == nil, "get_ego-returns-nil-for-useless-rpois")

      T.pass("pickup-alert-gargoyle-rpois")
      T.done()
    end
  end)
end
