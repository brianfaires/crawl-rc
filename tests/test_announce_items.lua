---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-items
-- Verifies that f_announce_items loaded with sane Config defaults.
-- (Feature is disabled by default; this is a config regression test.)
---------------------------------------------------------------------------------------------------

test_announce_items = {}
test_announce_items.BRC_FEATURE_NAME = "test-announce-items"

function test_announce_items.ready()
  if T._done then return end

  T.run("announce-items", function()
    T.true_(f_announce_items ~= nil, "module-exists")

    -- Disabled by default (turncount/console runs only)
    T.true_(f_announce_items.Config.disabled, "disabled-by-default")

    -- announce_class covers key item types
    local ac = f_announce_items.Config.announce_class
    T.true_(type(ac) == "table" and #ac > 0, "has-announce-classes")

    -- Max gold announcements is a positive number
    T.true_(f_announce_items.Config.max_gold_announcements > 0, "max-gold-positive")

    T.pass("announce-items")
    T.done()
  end)
end
