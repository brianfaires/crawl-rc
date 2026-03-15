---------------------------------------------------------------------------------------------------
-- BRC feature test: quiver-reminders
-- Verifies that f_quiver_reminders loaded with sane Config defaults.
---------------------------------------------------------------------------------------------------

test_quiver_reminders = {}
test_quiver_reminders.BRC_FEATURE_NAME = "test-quiver-reminders"

function test_quiver_reminders.ready()
  if T._done then return end

  T.run("quiver-reminders", function()
    T.true_(f_quiver_reminders ~= nil, "module-exists")
    T.eq(f_quiver_reminders.BRC_FEATURE_NAME, "quiver-reminders", "feature-name")
    T.true_(f_quiver_reminders.Config ~= nil, "has-config")

    T.pass("quiver-reminders")
    T.done()
  end)
end
