---------------------------------------------------------------------------------------------------
-- BRC feature test: remind-id
-- Verifies that f_remind_id loaded with sane Config and accessible persist state.
-- ri_found_scroll_of_id starts false (no scroll of ID found yet).
---------------------------------------------------------------------------------------------------

test_remind_id = {}
test_remind_id.BRC_FEATURE_NAME = "test-remind-id"

function test_remind_id.ready()
  if T._done then return end

  T.run("remind-id", function()
    T.true_(f_remind_id ~= nil, "module-exists")

    -- Default stop thresholds
    T.eq(f_remind_id.Config.stop_on_scrolls_count, 2, "scrolls-count-default")
    T.eq(f_remind_id.Config.stop_on_pots_count, 3, "pots-count-default")

    -- Persist: scroll of ID not found at game start
    T.false_(ri_found_scroll_of_id, "no-scroll-of-id-at-start")

    T.pass("remind-id")
    T.done()
  end)
end
