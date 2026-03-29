-- @species Na
-- @background Be
-- @weapon mace
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Naga rPois useless-ego + case-sensitivity bug)
--
-- Tests the is_useless_ego("rPois") / is_useless_ego("rpois") paths for Naga.
--
-- BRC.POIS_RES_RACES = { "Djinni", "Gargoyle", "Mummy", "Naga", "Poltergeist", "Revenant" }
--
-- FIXED BUG (was: is_useless_ego checked `ego == "rPois"` but crawl's it.ego(true) returns
-- "poison resistance" as the full display name, not the short tag "rPois". get_ego() passes
-- ego:lower() = "poison resistance" to is_useless_ego. Fixed by changing the check to
-- `ego == "poison resistance"`.
--
-- Assertion breakdown:
--   1. unit-rpois-full-string: is_useless_ego("poison resistance") == true
--   2. unit-rpois-short-tag:   is_useless_ego("rpois") == true  (both forms handled)
--   3. get-ego-rpois-nil:      get_ego(floor_robe) == nil        (useless ego suppressed)
--   4. alert-armour-no-alert:  alert_armour(floor_robe) falsy    (end-to-end suppression passes)
--
-- Phase flow:
--   "give"   (turn 0): wizard_give robe of poison resistance, identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): unit-test is_useless_ego both casings; find floor robe; test pipeline
---------------------------------------------------------------------------------------------------

test_pickup_alert_naga_rpois = {}
test_pickup_alert_naga_rpois.BRC_FEATURE_NAME = "test-pickup-alert-naga-rpois"

local _phase = "give"

function test_pickup_alert_naga_rpois.ready()
  if T._done then return end

  T.run("pickup-alert-naga-rpois", function()

    if _phase == "give" then
      -- "poison_resistance" is the item-spec ego name for rPois body armour.
      -- it.ego(true) returns "poison resistance" (lowercase with space); ego:lower() yields "poison resistance".
      -- is_useless_ego checks ego == "rPois" — neither casing matches "poison resistance".
      -- NOTE: Crawl's ego() API returns the display name, not the short tag.
      -- We use "ego:poison_resistance" as the wizard-give spec.
      T.wizard_give("robe ego:poison_resistance")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- ── Precondition: confirm species ──────────────────────────────────────────────────────
      T.eq(you.race(), "Naga", "char-is-naga")

      -- ── Unit tests for is_useless_ego ──────────────────────────────────────────────────────
      -- Full display name: "poison resistance" (from it.ego(true) on some DCSS builds)
      T.true_(BRC.eq.is_useless_ego("poison resistance"), "unit-rpois-full-string")

      -- Short tag: "rpois" (from it.ego(true):lower() on other DCSS builds / item types)
      -- Both forms must be handled since crawl may return either.
      T.true_(BRC.eq.is_useless_ego("rpois"), "unit-rpois-short-tag")

      -- ── Find the robe of poison resistance on the floor ────────────────────────────────────
      local floor_robe = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and it.name():find("poison") then
          floor_robe = it
          break
        end
      end
      T.true_(floor_robe ~= nil, "rpois-robe-on-floor")
      if not floor_robe then T.done() return end

      -- ── Inspect raw ego string from crawl ─────────────────────────────────────────────────
      -- Document what crawl actually returns so future readers know what to expect.
      local raw_ego = floor_robe.ego(true)
      -- raw_ego will be something like "poison resistance" (not "rPois")
      -- This means is_useless_ego("poison resistance") is also false — entirely separate issue.
      -- The test documents it for informational purposes only; no assertion on raw_ego value.

      -- ── Pipeline test: get_ego() should return nil for Naga (if bug is fixed) ───────────────
      -- get_ego() calls is_useless_ego(ego:lower()), which passes "rpois" or "poison resistance".
      -- Due to the bug, is_useless_ego returns false, so get_ego() returns the lowercased ego
      -- string rather than nil. This assertion EXPECTS nil but will get the ego string — FAILS.
      local pipeline_ego = BRC.eq.get_ego(floor_robe)
      T.false_(pipeline_ego ~= nil, "get-ego-rpois-nil")

      -- ── End-to-end: alert_armour should NOT fire for Naga on rPois robe ──────────────────
      -- Suppress force_more to avoid headless hang.
      local M = f_pickup_alert.Config.Alert.More
      local orig_body_armour    = M.body_armour
      local orig_armour_ego     = M.armour_ego
      local orig_high_score_arm = M.high_score_armour
      M.body_armour       = false
      M.armour_ego        = false
      M.high_score_armour = false

      -- Pre-fill pa_high_score.ac so the highest-AC path never fires.
      local orig_pa_hs_ac = pa_high_score.ac
      pa_high_score.ac = 999

      -- Restore armour_sensitivity to 1.0 (Testing config may set it to 0.5).
      local orig_sens = f_pickup_alert.Config.Alert.armour_sensitivity
      f_pickup_alert.Config.Alert.armour_sensitivity = 1.0

      -- Forget any prior alert record.
      f_pa_data.forget_alert(floor_robe)

      -- For Naga, the rPois robe should be useless — alert_armour should return falsy.
      -- BUG: because get_ego() doesn't suppress the ego, it looks like a GAIN ego and alerts.
      -- This assertion is EXPECTED TO FAIL, exposing the end-to-end impact of the bug.
      local result = f_pa_armour.alert_armour(floor_robe)
      T.false_(result ~= nil and result ~= false, "alert-armour-no-alert")

      -- ── Restore all settings ───────────────────────────────────────────────────────────────
      M.body_armour       = orig_body_armour
      M.armour_ego        = orig_armour_ego
      M.high_score_armour = orig_high_score_arm
      pa_high_score.ac    = orig_pa_hs_ac
      f_pickup_alert.Config.Alert.armour_sensitivity = orig_sens

      T.pass("pickup-alert-naga-rpois")
      T.done()
    end
  end)
end
