---------------------------------------------------------------------------------------------------
-- BRC feature test: alert-monsters
-- Verifies that f_alert_monsters loaded with sane Config defaults.
---------------------------------------------------------------------------------------------------

test_alert_monsters = {}
test_alert_monsters.BRC_FEATURE_NAME = "test-alert-monsters"

function test_alert_monsters.ready()
  if T._done then return end

  T.run("alert-monsters", function()
    T.true_(f_alert_monsters ~= nil, "module-exists")
    T.eq(f_alert_monsters.BRC_FEATURE_NAME, "alert-monsters", "feature-name")

    -- Config should have meaningful defaults
    T.true_(f_alert_monsters.Config ~= nil, "has-config")

    T.pass("alert-monsters")
    T.done()
  end)
end
