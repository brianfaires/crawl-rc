---------------------------------------------------------------------------------------------------
-- test_pa_data_remember_alert_branded: Verifies f_pa_data.remember_alert(it) stores BOTH
-- the branded key ("mace of flaming") AND the unbranded key ("mace") in pa_items_alerted
-- for a branded (non-artefact) weapon.
--
-- We use "flaming" rather than "holy wrath" because the test character is a Mummy Berserker,
-- and BRC.eq.get_ego() returns nil for egos that are useless to the current species. The
-- "holy" ego (holy wrath) is useless for undead (Mummies), so it would be treated as no ego.
-- "flaming" is not in the useless-ego list for Mummies, so get_ego() returns "flaming".
--
-- NOTE: it.ego() returns nil for floor items that have not been picked up, so we add a
-- CMD_PICKUP phase to move the item into inventory before calling remember_alert.
--
-- Phase flow:
--   "give"    (turn 0): wizard-give "mace ego:flaming plus:3", identify, CMD_WAIT → turn 1
--   "pickup"  (turn 1): CMD_PICKUP to grab the mace → turn 2
--   "verify"  (turn 2): find the mace in inventory, call remember_alert,
--                       check pa_items_alerted for both branded and unbranded keys
---------------------------------------------------------------------------------------------------

test_pa_data_remember_alert_branded = {}
test_pa_data_remember_alert_branded.BRC_FEATURE_NAME = "test-pa-data-remember-alert-branded"

local _phase = "give"

function test_pa_data_remember_alert_branded.ready()
  if T._done then return end

  T.run("pa-data-remember-alert-branded", function()
    if _phase == "give" then
      T.wizard_give("mace ego:flaming plus:3")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup" then
      -- The mace is on the floor; pick it up so ego() returns a value in the next phase.
      _phase = "verify"
      crawl.do_commands({"CMD_PICKUP"})

    elseif _phase == "verify" then
      -- Find the +3 flaming mace in inventory
      local flaming_mace = nil
      for _, it in ipairs(items.inventory()) do
        if it.is_weapon and it.subtype() == "mace" and (it.plus or 0) >= 3 then
          flaming_mace = it
          break
        end
      end
      T.true_(flaming_mace ~= nil, "flaming-mace-in-inventory")
      if not flaming_mace then T.done() return end

      -- Log names and ego for debugging
      crawl.stderr("mace name(base): "  .. tostring(flaming_mace.name("base")))
      crawl.stderr("mace name(db): "    .. tostring(flaming_mace.name("db")))
      crawl.stderr("mace ego(true): "   .. tostring(flaming_mace.ego(true)))
      crawl.stderr("mace ego(false): "  .. tostring(flaming_mace.ego(false)))
      crawl.stderr("BRC.eq.get_ego: "   .. tostring(BRC.eq.get_ego(flaming_mace)))

      -- Clear any pre-existing entries so we get a clean baseline
      pa_items_alerted["mace"] = nil
      pa_items_alerted["mace of flaming"] = nil

      -- Call the function under test
      f_pa_data.remember_alert(flaming_mace)

      -- Log what was stored
      crawl.stderr("pa_items_alerted[mace]: "           .. tostring(pa_items_alerted["mace"]))
      crawl.stderr("pa_items_alerted[mace of flaming]: " .. tostring(pa_items_alerted["mace of flaming"]))

      -- Branded key should be stored
      T.true_(pa_items_alerted["mace of flaming"] ~= nil, "branded-key-stored")
      -- Unbranded key should be stored (ego branch fires because flaming is not useless for Mummies)
      T.true_(pa_items_alerted["mace"] ~= nil, "unbranded-key-stored")
      -- Both values should be positive (value = 3, parsed from "+3 " prefix)
      T.true_((tonumber(pa_items_alerted["mace of flaming"]) or 0) > 0, "branded-value-positive")
      T.true_((tonumber(pa_items_alerted["mace"]) or 0) > 0, "unbranded-value-positive")

      -- already_alerted should return truthy for the item itself
      local alerted = f_pa_data.already_alerted(flaming_mace)
      crawl.stderr("already_alerted result: " .. tostring(alerted))
      T.true_(alerted ~= nil and alerted ~= false, "already-alerted-returns-truthy")

      T.pass("remember-alert-branded")
      T.done()
    end
  end)
end
