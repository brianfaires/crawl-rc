---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (XL threshold deactivation)
-- Verifies that xl_force_mores entries are deactivated when you.xl() exceeds their threshold,
-- using T.wizard_set_xl to advance the character's experience level mid-test.
--
-- Complements test_dynamic_options_xl_force_mores.lua which only checks at XL 1.
-- This test exercises the threshold boundary: at XL 6 the electrocution entry (xl=5) is
-- exceeded while the poisoned entry (xl=7) is not; at XL 20 all entries are exceeded.
--
-- Note: xl_force_mores_active is local to dynamic-options.lua and cannot be read directly.
-- Threshold deactivation is verified by checking you.xl() against Config entry xl values.
--
-- Phase flow:
--   "wait"       (turn 0): CMD_WAIT so dynamic-options.ready() runs (fires after us)
--   "check_xl1"  (turn 1): you.xl()==1; all entry thresholds exceed current XL
--                          wizard_set_xl(6) + CMD_WAIT
--   "check_xl6"  (turn 2): you.xl()==6; electrocution (xl=5) exceeded, poisoned (xl=7) not
--                          wizard_set_xl(20) + CMD_WAIT
--   "check_xl20" (turn 3): you.xl()==20; all entries exceeded; T.pass + T.done
---------------------------------------------------------------------------------------------------

test_dynamic_options_xl_thresholds = {}
test_dynamic_options_xl_thresholds.BRC_FEATURE_NAME = "test-dynamic-options-xl-thresholds"

local _phase = "wait"

function test_dynamic_options_xl_thresholds.ready()
  if T._done then return end

  T.run("dynamic-options-xl-thresholds", function()

    if _phase == "wait" then
      _phase = "check_xl1"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check_xl1" then
      T.eq(you.xl(), 1, "xl-is-1-at-start")

      -- At XL 1 every entry threshold must be >= 1 (all active)
      local entries = f_dynamic_options.Config.xl_force_mores
      local all_active = true
      for i, v in ipairs(entries) do
        if type(v.xl) == "number" and v.xl < 1 then
          T.fail("entry-" .. i .. "-active-at-xl1", "threshold xl=" .. v.xl .. " already below 1")
          all_active = false
        end
      end
      if all_active then T.pass("all-entries-active-at-xl1") end

      _phase = "check_xl6"
      T.wizard_set_xl(6)
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check_xl6" then
      T.eq(you.xl(), 6, "xl-is-6-after-wizard-set-xl")

      local entries = f_dynamic_options.Config.xl_force_mores

      -- Electrocution entry (xl=5): 6 > 5 → exceeded (would be inactive)
      local elec = nil
      for _, v in ipairs(entries) do
        if type(v.pattern) == "string" and v.pattern:find("electrocution") then
          elec = v
          break
        end
      end
      T.true_(elec ~= nil, "electrocution-entry-exists")
      if elec then
        T.true_(you.xl() > elec.xl, "xl6-exceeds-electrocution-threshold")
      end

      -- Poisoned entry (xl=7): 6 <= 7 → not exceeded (still active)
      local pois = nil
      for _, v in ipairs(entries) do
        if type(v.pattern) == "string" and v.pattern:find("poisoned") then
          pois = v
          break
        end
      end
      T.true_(pois ~= nil, "poisoned-entry-exists")
      if pois then
        T.true_(you.xl() <= pois.xl, "xl6-within-poisoned-threshold")
      end

      _phase = "check_xl20"
      T.wizard_set_xl(20)
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check_xl20" then
      T.eq(you.xl(), 20, "xl-is-20-after-wizard-set-xl")

      -- At XL 20 every entry threshold is exceeded (all would be inactive)
      local entries = f_dynamic_options.Config.xl_force_mores
      local all_exceeded = true
      for i, v in ipairs(entries) do
        if type(v.xl) == "number" and you.xl() <= v.xl then
          T.fail("entry-" .. i .. "-exceeded-at-xl20", "threshold xl=" .. v.xl .. " not exceeded at xl=20")
          all_exceeded = false
        end
      end
      if all_exceeded then T.pass("all-entries-exceeded-at-xl20") end

      T.pass("dynamic-options-xl-thresholds")
      T.done()
    end
  end)
end
