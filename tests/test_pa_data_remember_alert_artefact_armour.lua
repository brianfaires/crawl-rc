---------------------------------------------------------------------------------------------------
-- BRC feature test: pa-data remember_alert for artefact armour (artprops branch)
-- Verifies that remember_alert stores artprop-derived keys in pa_items_alerted for an
-- artefact armour with known artprops matching BRC.ARTPROPS_EGO.
--
-- pa-data.lua remember_alert artprops branch (lines ~74-84):
--   if it.artefact and BRC.it.is_armour(it) then
--     for k, v in pairs(it.artprops) do
--       if v > 0 and BRC.ARTPROPS_EGO[k] then
--         branded_name = name .. " of " .. BRC.ARTPROPS_EGO[k]
--         pa_items_alerted[branded_name] = value
--
-- Item: "robe of Night" (unrand artefact body armour).
--   - it.artefact = true
--   - BRC.it.is_armour(it) = true
--   - artprops includes rN (positive energy resistance): BRC.ARTPROPS_EGO["rN"] = "positive energy"
--   - Expected artprops key: "robe of positive energy" stored in pa_items_alerted
--
-- NOTE: it.ego() returns nil for unequipped floor items (DCSS API limitation).
-- remember_alert uses it.name("db") for the plain-name branch instead of get_ego(),
-- so the artprops branch (which uses it.artprops directly) still works on floor items.
--
-- The robe of Night is auto-identified by wizard_give, so is_identified = true
-- and artprops is accessible immediately.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "robe of Night"; CMD_WAIT → turn 1
--   "verify" (turn 1): find robe on floor, call remember_alert, assert pa_items_alerted entries
--                      (no message queued; no verify phase needed)
---------------------------------------------------------------------------------------------------

test_pa_data_remember_alert_artefact_armour = {}
test_pa_data_remember_alert_artefact_armour.BRC_FEATURE_NAME = "test-pa-data-remember-alert-artefact-armour"

local _phase = "give"

function test_pa_data_remember_alert_artefact_armour.ready()
  if T._done then return end

  T.run("pa-data-remember-alert-artefact-armour", function()

    -- ── Phase 1: place robe of Night on the floor ───────────────────────────────────────────
    if _phase == "give" then
      -- wizard_give calls wizard_create_spec_object_by_name which auto-identifies the item.
      T.wizard_give("robe of Night")
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    -- ── Phase 2: call remember_alert and assert artprops keys ───────────────────────────────
    elseif _phase == "verify" then

      -- Find robe of Night on floor
      local floor_robe = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and it.artefact then
          floor_robe = it
          break
        end
      end
      T.true_(floor_robe ~= nil, "robe-of-night-on-floor")
      if not floor_robe then T.done() return end

      T.true_(floor_robe.is_identified, "robe-of-night-is-identified")

      -- Log item details for diagnosis
      crawl.stderr("robe name(): "       .. tostring(floor_robe.name()))
      crawl.stderr("robe name(base): "   .. tostring(floor_robe.name("base")))
      crawl.stderr("robe name(db): "     .. tostring(floor_robe.name("db")))
      crawl.stderr("robe ego(false): "   .. tostring(floor_robe.ego(false)))
      crawl.stderr("robe artefact: "     .. tostring(floor_robe.artefact))
      crawl.stderr("robe artprops type: " .. type(floor_robe.artprops))

      -- Log artprops keys that match ARTPROPS_EGO
      if floor_robe.artprops then
        for k, v in pairs(floor_robe.artprops) do
          crawl.stderr("artprop: " .. tostring(k) .. " = " .. tostring(v)
            .. " -> ARTPROPS_EGO=" .. tostring(BRC.ARTPROPS_EGO[k]))
        end
      end

      -- Clear all potentially relevant keys for a clean baseline
      local base_name = floor_robe.name("db")
      crawl.stderr("base_name (db): " .. tostring(base_name))
      pa_items_alerted[base_name] = nil

      -- Also clear artprop-derived keys if artprops available
      if floor_robe.artprops then
        for k, v in pairs(floor_robe.artprops) do
          if v > 0 and BRC.ARTPROPS_EGO[k] then
            local branded_name = base_name .. " of " .. BRC.ARTPROPS_EGO[k]
            pa_items_alerted[branded_name] = nil
          end
        end
      end

      -- Call the function under test
      f_pa_data.remember_alert(floor_robe)

      -- Assert 1: already_alerted returns truthy (base key was stored)
      local alerted = f_pa_data.already_alerted(floor_robe)
      crawl.stderr("already_alerted result: " .. tostring(alerted))
      T.true_(alerted ~= nil and alerted ~= false, "artefact-armour-already-alerted-after-remember")

      -- Assert 2: base name key stored in pa_items_alerted
      crawl.stderr("pa_items_alerted[base_name]: " .. tostring(pa_items_alerted[base_name]))
      T.true_(pa_items_alerted[base_name] ~= nil, "base-name-key-stored")

      -- Assert 3: artprop-derived keys stored (the core of this test)
      -- The robe of Night has rN (positive energy). Verify at least one artprop key was stored.
      local artprop_key_stored = false
      if floor_robe.artprops then
        for k, v in pairs(floor_robe.artprops) do
          if v > 0 and BRC.ARTPROPS_EGO[k] then
            local branded_name = base_name .. " of " .. BRC.ARTPROPS_EGO[k]
            crawl.stderr("checking artprop key: " .. tostring(branded_name)
              .. " = " .. tostring(pa_items_alerted[branded_name]))
            if pa_items_alerted[branded_name] ~= nil then
              artprop_key_stored = true
            end
          end
        end
      end
      T.true_(artprop_key_stored, "artprop-branded-key-stored-in-pa_items_alerted")

      T.pass("pa-data-remember-alert-artefact-armour")
      T.done()
    end
  end)
end
