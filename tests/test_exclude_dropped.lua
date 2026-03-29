---------------------------------------------------------------------------------------------------
-- BRC feature test: exclude-dropped (drop message adds item to ed_dropped_items)
-- Verifies that c_message adds an exclusion entry when a drop message arrives.
--
-- "You drop a potion of heal wounds." → extract_potion → "potions? of heal wounds"
-- The mummy berserker has no heal wounds potions in inventory, so should_exclude() → true.
--
-- ed_dropped_items is a global persist; save/restore around the test.
---------------------------------------------------------------------------------------------------

test_exclude_dropped = {}
test_exclude_dropped.BRC_FEATURE_NAME = "test-exclude-dropped"

function test_exclude_dropped.ready()
  if T._done then return end

  T.run("exclude-dropped", function()
    -- Save state
    local orig = {}
    for i, v in ipairs(ed_dropped_items) do orig[i] = v end

    -- Clear ed_dropped_items for clean test
    for i = #ed_dropped_items, 1, -1 do ed_dropped_items[i] = nil end

    -- Test 1: drop message adds item name to ed_dropped_items
    f_exclude_dropped.c_message("You drop a potion of heal wounds.", "plain")
    T.true_(#ed_dropped_items >= 1, "drop-added-to-exclusion-list")

    -- Check the extracted name matches expected pattern
    local found = false
    for _, v in ipairs(ed_dropped_items) do
      -- stored as "potions? of heal wounds" (literal ? is the pattern the exclusion uses)
      if v:find("potion", 1, true) and v:find("heal wounds", 1, true) then
        found = true; break
      end
    end
    T.true_(found, "drop-extracted-potion-name")

    -- Test 2: non-plain channel → no addition
    for i = #ed_dropped_items, 1, -1 do ed_dropped_items[i] = nil end
    f_exclude_dropped.c_message("You drop a potion of heal wounds.", "warn")
    T.true_(#ed_dropped_items == 0, "non-plain-drop-ignored")

    -- Test 3: unrecognized item type → no addition (weapons not handled by exclude-dropped)
    for i = #ed_dropped_items, 1, -1 do ed_dropped_items[i] = nil end
    f_exclude_dropped.c_message("You drop a mace.", "plain")
    T.true_(#ed_dropped_items == 0, "weapon-drop-not-excluded")

    -- Restore state
    for i = #ed_dropped_items, 1, -1 do ed_dropped_items[i] = nil end
    for i, v in ipairs(orig) do ed_dropped_items[i] = v end

    T.pass("exclude-dropped")
    T.done()
  end)
end
