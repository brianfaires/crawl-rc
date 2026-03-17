---------------------------------------------------------------------------------------------------
-- test_pa_data_key_parsing: Verifies f_pa_data.get_keyname and f_pa_data.already_alerted
-- correctly handle item name parsing, especially the 3-char enchantment prefix logic.
--
-- Single-phase (turn 0):
--   1. Find the starting mace in inventory (Mummy Berserker starts with a mace).
--   2. Call f_pa_data.get_keyname(weapon) and verify it is non-empty and contains "mace".
--   3. Call f_pa_data.already_alerted(weapon) and verify it returns truthy.
--      (f_pickup_alert.init() calls remember_alert for all starting inventory items.)
--   4. Log keyname, already_alerted result, and pa_items_alerted["mace"] for debugging.
---------------------------------------------------------------------------------------------------

test_pa_data_key_parsing = {}
test_pa_data_key_parsing.BRC_FEATURE_NAME = "test-pa-data-key-parsing"

function test_pa_data_key_parsing.ready()
  if T._done then return end

  T.run("pa-data-key-parsing", function()

    -- Find starting weapon (Mummy Berserker starts with a mace)
    local weapon = nil
    for _, it in ipairs(items.inventory()) do
      if it.is_weapon then
        weapon = it
        break
      end
    end
    T.true_(weapon ~= nil, "has-weapon")

    -- Log raw item name for diagnostic context
    local raw_name = weapon.name("base")
    crawl.mpr("raw item name (base): " .. tostring(raw_name))

    -- Test get_keyname
    local keyname = f_pa_data.get_keyname(weapon)
    crawl.mpr("get_keyname result: " .. tostring(keyname))
    T.true_(keyname ~= nil and #keyname > 0, "keyname-non-empty")
    T.true_(keyname:find("mace") ~= nil, "keyname-contains-mace")

    -- Test already_alerted: f_pickup_alert.init() calls remember_alert for all starting
    -- inventory items, so the starting mace should already be in pa_items_alerted.
    local alerted = f_pa_data.already_alerted(weapon)
    crawl.mpr("already_alerted result: " .. tostring(alerted))
    crawl.mpr("pa_items_alerted[mace]: " .. tostring(pa_items_alerted["mace"]))
    T.true_(alerted ~= nil and alerted ~= false, "starting-mace-already-alerted")

    T.pass("pa-data-key-parsing")
    T.done()

  end)
end
