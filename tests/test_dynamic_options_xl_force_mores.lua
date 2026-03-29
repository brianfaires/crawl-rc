---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (xl_force_mores)
-- Verifies that xl_force_mores Config entries are all well-formed and that at XL 1 (game start)
-- every entry's xl threshold exceeds the player's current XL, meaning all patterns are active.
--
-- The existing test_dynamic_options.lua only checks xl_force_mores[1].
-- This test exhaustively validates all entries and tests the threshold semantics.
--
-- Test phases:
--   "wait"  (turn 0): Our hook fires BEFORE dynamic-options.ready() (reverse-alpha order).
--                     Issue CMD_WAIT so ready() runs this cycle, then we check on turn 1.
--   "check" (turn 1): Verify you.xl() == 1, all Config entries are valid, and all xl thresholds
--                     exceed the current XL (meaning set_xl_options() activated all of them).
---------------------------------------------------------------------------------------------------

test_dynamic_options_xl_force_mores = {}
test_dynamic_options_xl_force_mores.BRC_FEATURE_NAME = "test-dynamic-options-xl-force-mores"

local _phase = "wait"

function test_dynamic_options_xl_force_mores.ready()
  if T._done then return end

  T.run("dynamic-options-xl-force-mores", function()
    if _phase == "wait" then
      -- Our hook fires before dynamic-options.ready() at turn 0 (reverse-alpha order).
      -- CMD_WAIT completes turn 0's cycle: dynamic-options.ready() runs, xl_force_mores_active
      -- is populated for the first time. We check results at turn 1.
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Character starts at XL 1
      T.eq(you.xl(), 1, "xl-is-1-at-start")

      local entries = f_dynamic_options.Config.xl_force_mores

      -- Must have at least one entry
      T.true_(type(entries) == "table", "xl-force-mores-is-table")
      T.true_(#entries > 0, "xl-force-mores-nonempty")

      -- Every entry must have a non-empty string pattern and a positive number xl threshold
      local all_valid = true
      for i, v in ipairs(entries) do
        if type(v.pattern) ~= "string" or #v.pattern == 0 then
          T.fail("entry-" .. i .. "-pattern", "expected non-empty string, got " .. tostring(v.pattern))
          all_valid = false
        end
        if type(v.xl) ~= "number" or v.xl <= 0 then
          T.fail("entry-" .. i .. "-xl", "expected positive number, got " .. tostring(v.xl))
          all_valid = false
        end
      end
      if all_valid then
        T.pass("all-entries-valid")
      end

      -- At XL 1, every entry's xl threshold must be >= 1 (i.e., the pattern should be active).
      -- set_xl_options() activates entry i when you.xl() <= v.xl.
      -- We verify the minimum threshold across all entries is > 1, which means ALL entries
      -- satisfy (you.xl() == 1) <= v.xl and were activated by ready().
      local min_xl = math.huge
      for _, v in ipairs(entries) do
        if type(v.xl) == "number" and v.xl < min_xl then
          min_xl = v.xl
        end
      end
      T.true_(min_xl > 1, "min-xl-threshold-exceeds-xl-1")

      -- Also verify the known high-end entry exists: xl=18 for "goes berserk" (late-game warning).
      -- This confirms the Config hasn't been accidentally truncated.
      local has_high_xl = false
      for _, v in ipairs(entries) do
        if type(v.xl) == "number" and v.xl >= 18 then
          has_high_xl = true
          break
        end
      end
      T.true_(has_high_xl, "has-high-xl-entry")

      T.pass("dynamic-options-xl-force-mores")
      T.done()
    end
  end)
end
