---------------------------------------------------------------------------------------------------
-- BRC feature test: no-regressions
-- Runs all BRC features for 10 turns and asserts no crashes or hangs.
--
-- This is a smoke test: if any feature throws an unhandled error or causes a hang within
-- T.timeout_turns, the harness will catch it and emit [FAIL]/[ERROR]. Surviving 10 turns
-- cleanly indicates the feature set is stable.
---------------------------------------------------------------------------------------------------

test_no_regressions = {}
test_no_regressions.BRC_FEATURE_NAME = "test-no-regressions"

function test_no_regressions.ready()
  if T._done then return end

  T.run("no-regressions", function()
    if you.turns() < 10 then
      crawl.do_commands({"CMD_WAIT"})
    else
      T.pass("no-regressions")
      T.done()
    end
  end)
end
