---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (body armour ego alert)
-- Verifies that f_pa_armour.alert_armour() fires an alert when a floor body armour has an ego
-- that the currently equipped armour lacks.
--
-- Character: Mummy Berserker, starts wearing a plain robe (AC 2, enc 0, no ego).
-- Floor item: ring mail of fire resistance (AC 4, enc 7, ego = fire_resistance).
--
-- Expected alert path in alert_body_armour():
--   ego_change = GAIN (cur_ego = nil, it_ego = "fire resistance")
--   encumb_delta = 7  ->  weight = HEAVIER
--   is_good_ego_change(GAIN, true) = true
--   Either:
--     (a) ignore_small path: |ac_delta + ev_delta| <= H.Heavier.ignore_small * sensitivity
--     (b) should_alert_body_armour(HEAVIER, ac_delta, -adj_ev_delta, GAIN) passes, OR
--     (c) fallthrough: it_ego and you.xl() <= H.early_xl (XL 1 <= 6)
--   Any of these yields a truthy return -> test passes.
--
-- To prevent a force_more hang in headless mode:
--   - More.body_armour is already false in the default config.
--   - More.armour_ego is true by default; we temporarily set it to false.
--   - More.high_score_armour is true by default; we set pa_high_score.ac = 999 so the
--     highest-AC path never fires its own force_more.
--
-- armour_sensitivity is restored to 1.0 for the test (Testing config sets it to 0.5,
-- which would make the Heavier thresholds much tighter).
--
-- Phase flow:
--   "give"   (turn 0): wizard_give + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): call f_pa_armour.alert_armour(floor_item) directly; assert truthy
---------------------------------------------------------------------------------------------------

test_pickup_alert_ego_armour = {}
test_pickup_alert_ego_armour.BRC_FEATURE_NAME = "test-pickup-alert-ego-armour"

local _phase = "give"

function test_pickup_alert_ego_armour.ready()
  if T._done then return end

  T.run("pickup-alert-ego-armour", function()
    if _phase == "give" then
      -- Place a ring mail of fire resistance on the floor and identify it.
      -- Ring mail (AC 4, enc 7) has higher AC than the starting robe (AC 2, enc 0).
      T.wizard_give("ring mail ego:fire_resistance")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    elseif _phase == "verify" then
      -- ── Find the ring mail on the floor ────────────────────────────────────────────────────
      local floor_armour = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and it.name("base"):find("ring mail") then
          floor_armour = it
          break
        end
      end
      T.true_(floor_armour ~= nil, "ring-mail-on-floor")
      if not floor_armour then T.done() return end

      -- ── Sanity-check preconditions ──────────────────────────────────────────────────────────
      -- Current equipped armour must exist and have no ego.
      local cur = items.equipped_at("armour")
      T.true_(cur ~= nil, "body-armour-equipped")
      if not cur then T.done() return end
      T.false_(BRC.eq.get_ego(cur) ~= nil, "cur-armour-has-no-ego")

      -- Floor item must have a fire_resistance ego.
      local it_ego = BRC.eq.get_ego(floor_armour)
      T.true_(it_ego ~= nil, "floor-armour-has-ego")

      -- ── Temporarily suppress all force_more that could hang headless mode ──────────────────
      local M = f_pickup_alert.Config.Alert.More
      local orig_body_armour    = M.body_armour
      local orig_armour_ego     = M.armour_ego
      local orig_high_score_arm = M.high_score_armour
      M.body_armour    = false
      M.armour_ego     = false
      M.high_score_armour = false

      -- Pre-fill pa_high_score.ac to a large value so alert_highest_ac() returns false,
      -- ensuring the test exercises the ego-change code path rather than the high-score path.
      local orig_pa_hs_ac = pa_high_score.ac
      pa_high_score.ac = 999

      -- Restore armour_sensitivity to 1.0; Testing config sets it to 0.5 which tightens
      -- Heavier thresholds and could mask the ego-alert path we want to verify.
      local orig_sens = f_pickup_alert.Config.Alert.armour_sensitivity
      f_pickup_alert.Config.Alert.armour_sensitivity = 1.0

      -- Forget any prior alert record so already_alerted() doesn't short-circuit.
      f_pa_data.forget_alert(floor_armour)

      -- ── Exercise: alert_armour should return truthy for a GAIN ego on heavier body armour ──
      local result = f_pa_armour.alert_armour(floor_armour)
      T.true_(result ~= nil and result ~= false, "ego-armour-alert-fires")

      -- ── Restore all settings ────────────────────────────────────────────────────────────────
      M.body_armour       = orig_body_armour
      M.armour_ego        = orig_armour_ego
      M.high_score_armour = orig_high_score_arm
      pa_high_score.ac    = orig_pa_hs_ac
      f_pickup_alert.Config.Alert.armour_sensitivity = orig_sens

      T.pass("pickup-alert-ego-armour")
      T.done()
    end
  end)
end
