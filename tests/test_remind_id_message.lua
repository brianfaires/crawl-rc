---------------------------------------------------------------------------------------------------
-- BRC feature test: remind-id (c_message sets ri_found_scroll_of_id)
-- Verifies that c_message sets ri_found_scroll_of_id when "scroll of identify" appears in a
-- plain-channel message, and that non-plain channels are ignored.
--
-- ri_found_scroll_of_id is a global persist variable; readable and writable from tests.
---------------------------------------------------------------------------------------------------

test_remind_id_message = {}
test_remind_id_message.BRC_FEATURE_NAME = "test-remind-id-message"

function test_remind_id_message.ready()
  if T._done then return end

  T.run("remind-id-message", function()
    -- Snapshot original value so we can restore it
    local orig = ri_found_scroll_of_id

    -- Test 1: plain channel + matching text → flag set
    ri_found_scroll_of_id = false
    f_remind_id.c_message("You see here a scroll of identify.", "plain")
    T.true_(ri_found_scroll_of_id, "plain-sets-flag")

    -- Test 2: non-plain channel → flag not set
    ri_found_scroll_of_id = false
    f_remind_id.c_message("You see here a scroll of identify.", "warn")
    T.false_(ri_found_scroll_of_id, "non-plain-ignored")

    -- Test 3: plain channel + unrelated message → flag not set
    ri_found_scroll_of_id = false
    f_remind_id.c_message("You pick up a scroll of fog.", "plain")
    T.false_(ri_found_scroll_of_id, "unrelated-message-ignored")

    ri_found_scroll_of_id = orig
    T.pass("remind-id-message")
    T.done()
  end)
end
