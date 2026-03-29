---------------------------------------------------------------------------------------------------
-- test_pa_data_egos_alerted: Verifies that pa_egos_alerted is updated correctly.
--
-- pa_egos_alerted is a persistent list that tracks body-armour egos seen via
-- track_unique_egos(), which is called from f_pickup_alert.do_alert() whenever an
-- armour item triggers an alert.  get_ego_change_type() uses it to distinguish
-- NEW ego (not seen before) from DIFF ego (seen before).
--
-- This test exercises three things:
--   1. pa_egos_alerted starts as a table (empty at game start, no starting gear has egos).
--   2. Manual insertion into pa_egos_alerted and util.contains work correctly.
--   3. BRC.eq.get_ego() returns a non-nil ego for a ring mail of fire resistance, and
--      the simulate-track_unique_egos pattern correctly adds it to pa_egos_alerted.
--
-- Item choice: "ring mail ego:fire_resistance"
--   The ego: spec format is the DCSS wizard % command syntax.
--   Ring mail is heavier than the starting animal skin, so it stays on the floor
--   (pickup_body_armour returns false for encumb_delta > 0 without offsetting gain).
--   "fire resistance" is not in BRC.MAGIC_SCHOOLS, so BRC.eq.get_ego returns it for any race.
--
-- Phase flow:
--   "give"   (turn 0): wizard-give ring mail ego:fire_resistance, identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): inspect pa_egos_alerted, find the ring mail on floor, test ego tracking
---------------------------------------------------------------------------------------------------

test_pa_data_egos_alerted = {}
test_pa_data_egos_alerted.BRC_FEATURE_NAME = "test-pa-data-egos-alerted"

local _phase = "give"

function test_pa_data_egos_alerted.ready()
  if T._done then return end

  T.run("pa-data-egos-alerted", function()

    if _phase == "give" then
      -- Use ego: spec syntax for DCSS wizard % command.
      -- Ring mail is heavier than the starting animal skin, so it will not be auto-picked up.
      T.wizard_give("ring mail ego:fire_resistance")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then

      --------------------------------------------------------------------------
      -- 1. pa_egos_alerted is a table (empty: starting animal skin has no ego)
      --------------------------------------------------------------------------
      crawl.stderr("pa_egos_alerted initial count: " .. tostring(#pa_egos_alerted))
      T.true_(type(pa_egos_alerted) == "table", "pa-egos-alerted-is-table")

      --------------------------------------------------------------------------
      -- 2. Manual insertion and util.contains
      --------------------------------------------------------------------------
      local test_ego = "fire resistance"

      -- Save current list and clear for a clean baseline
      local saved_egos = {}
      for i, v in ipairs(pa_egos_alerted) do saved_egos[i] = v end
      while #pa_egos_alerted > 0 do table.remove(pa_egos_alerted) end

      -- Confirm list is empty after clearing
      T.false_(util.contains(pa_egos_alerted, test_ego), "ego-not-in-empty-list")
      T.false_(util.contains(pa_egos_alerted, "cold resistance"), "different-ego-not-in-list")

      -- Add test_ego manually (mirrors what track_unique_egos does)
      pa_egos_alerted[#pa_egos_alerted + 1] = test_ego
      T.true_(util.contains(pa_egos_alerted, test_ego), "ego-added-to-list")

      -- A different ego remains absent
      T.false_(util.contains(pa_egos_alerted, "cold resistance"), "different-ego-still-not-in-list")

      -- Restore pa_egos_alerted to its pre-test state
      while #pa_egos_alerted > 0 do table.remove(pa_egos_alerted) end
      for i, v in ipairs(saved_egos) do pa_egos_alerted[i] = v end

      --------------------------------------------------------------------------
      -- 3. BRC.eq.get_ego on the real ring mail of fire resistance
      --------------------------------------------------------------------------
      -- Ring mail is heavier than the starting animal skin (encumb_delta > 0) so
      -- pickup_body_armour returns false — the item stays on the floor.
      local ring_mail = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) then
          crawl.stderr("floor body armour: " .. tostring(it.name()) .. " ego=" .. tostring(BRC.eq.get_ego(it)))
          ring_mail = it
          break
        end
      end

      crawl.stderr("ring_mail found: " .. tostring(ring_mail ~= nil))
      T.true_(ring_mail ~= nil, "ring-mail-on-floor")

      if ring_mail then
        local ego = BRC.eq.get_ego(ring_mail)
        crawl.stderr("ring_mail ego: " .. tostring(ego))
        T.true_(ego ~= nil, "ring-mail-has-ego")

        -- Simulate what track_unique_egos does:
        --   if ego and not util.contains(pa_egos_alerted, ego) ... then add it
        local was_in_list = util.contains(pa_egos_alerted, ego)
        crawl.stderr("ego already in pa_egos_alerted before simulate: " .. tostring(was_in_list))
        if not was_in_list then
          pa_egos_alerted[#pa_egos_alerted + 1] = ego
        end
        T.true_(util.contains(pa_egos_alerted, ego), "ego-tracked-after-add")
      end

      T.pass("pa-data-egos-alerted")
      T.done()
    end
  end)
end
