---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (SAME_WEIGHT body armour ego alert)
-- Exercises the alert_body_armour() code path for encumb_delta == 0 with a GAIN ego.
--
-- Character: Mummy Berserker, starts wearing a plain robe (AC 2, enc 0, no ego).
--
-- NOTE on naming: this test is named "lighter_armour" to cover the LIGHTER body armour
-- alerting area.  A Mummy Berserker starts with a robe (enc 0) — there is no body
-- armour lighter than enc 0, so the directly reachable code path is the SAME_WEIGHT
-- branch (encumb_delta == 0) of alert_body_armour():
--
--   is_good_ego_change(GAIN, true) = true
--   encumb_delta == 0
--   -> send_armour_alert(it, ARMOUR_ALERT["gain_ego"])   (line ~242 in pa-armour.lua)
--
-- Two floor items are given:
--   1. robe of fire resistance  — used for Test A (ego GAIN -> alert fires)
--   2. plain robe               — used for Test B (SAME ego, same AC, same enc -> no alert)
--
-- Test A: ego GAIN fires an alert (encumb_delta == 0, is_good_ego_change(GAIN) = true).
-- Test B: no alert when floor item is identical to equipped armour (SAME ego, zero deltas,
--         pa_high_score.ac pre-filled to prevent highest-AC path, early_xl = 0 to prevent
--         the "Early armour" fallback; result is nil).
--
-- Preconditions to prevent force_more hangs in headless mode:
--   - M.body_armour, M.armour_ego, M.high_score_armour set to false
--   - pa_high_score.ac = 999
--   - armour_sensitivity restored to 1.0 (Testing config sets it to 0.5)
--
-- Phase flow:
--   "give"   (turn 0): wizard_give both robes + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): locate floor items, run Test A and Test B, T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_lighter_armour = {}
test_pickup_alert_lighter_armour.BRC_FEATURE_NAME = "test-pickup-alert-lighter-armour"

local _phase = "give"

function test_pickup_alert_lighter_armour.ready()
  if T._done then return end

  T.run("pickup-alert-lighter-armour", function()

    -- ----------------------------------------------------------------
    -- Phase "give": place a robe of fire_resistance and a plain robe
    -- on the floor, then identify all items.
    -- ----------------------------------------------------------------
    if _phase == "give" then
      T.wizard_give("robe ego:fire_resistance")
      T.wizard_give("robe")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    -- ----------------------------------------------------------------
    -- Phase "verify": exercise alert_body_armour() directly.
    -- ----------------------------------------------------------------
    elseif _phase == "verify" then

      -- ── Find floor items ──────────────────────────────────────────
      local floor_robe_ego = nil   -- robe of fire resistance
      local floor_robe_plain = nil -- plain robe
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and it.name("base"):find("robe") then
          if BRC.eq.get_ego(it) then
            floor_robe_ego = it
          else
            floor_robe_plain = it
          end
        end
      end
      T.true_(floor_robe_ego ~= nil, "floor-robe-fire-res-found")
      T.true_(floor_robe_plain ~= nil, "floor-robe-plain-found")
      if not floor_robe_ego or not floor_robe_plain then T.done() return end

      -- ── Sanity: equipped robe has no ego; floor robe has fire_resistance ──
      local cur = items.equipped_at("armour")
      T.true_(cur ~= nil, "body-armour-equipped")
      if not cur then T.done() return end
      T.false_(BRC.eq.get_ego(cur) ~= nil, "equipped-robe-has-no-ego")
      T.true_(BRC.eq.get_ego(floor_robe_ego) ~= nil, "floor-robe-has-ego")

      -- ── Snapshot and disable all force_more that could hang headless ──
      local M          = f_pickup_alert.Config.Alert.More
      local orig_body  = M.body_armour
      local orig_ego   = M.armour_ego
      local orig_hs    = M.high_score_armour
      M.body_armour    = false
      M.armour_ego     = false
      M.high_score_armour = false

      -- Suppress highest-AC path (set 999 so the "new record" branch never fires).
      local orig_hs_ac = pa_high_score.ac
      pa_high_score.ac = 999

      -- Restore armour_sensitivity to 1.0; Testing config sets it to 0.5.
      local A          = f_pickup_alert.Config.Alert
      local orig_sens  = A.armour_sensitivity
      A.armour_sensitivity = 1.0

      -- Snapshot early_xl; we zero it in Test B to prevent "Early armour" fallback.
      local H          = f_pickup_alert.Config.Tuning.Armour
      local orig_early = H.early_xl

      -- ── Test A: SAME_WEIGHT + GAIN ego -> alert fires ─────────────
      -- Code path (pa-armour.lua ~line 241-242):
      --   is_good_ego_change("gain_ego", true) = true
      --   encumb_delta == 0  (both robes enc 0)
      --   -> send_armour_alert(it, ARMOUR_ALERT["gain_ego"]) -> truthy
      f_pa_data.forget_alert(floor_robe_ego)
      local result_a = f_pa_armour.alert_armour(floor_robe_ego)
      T.true_(result_a ~= nil and result_a ~= false, "test-a-gain-ego-alert-fires")

      -- ── Test B: SAME_WEIGHT + SAME ego (plain robe) -> no alert ──
      -- Code path:
      --   ego_change = SAME  (both nil egos)
      --   is_good_ego_change(SAME, true) = false  -> skip fast-path
      --   encumb_delta == 0  -> neither LIGHTER nor HEAVIER branch fires
      --   alert_highest_ac: pa_high_score.ac = 999, robe AC 2 < 999 -> false
      --   early_xl = 0, xl = 1 -> 1 <= 0 is false -> no "Early armour"
      --   -> function returns nil (falsy)
      H.early_xl = 0
      f_pa_data.forget_alert(floor_robe_plain)
      local result_b = f_pa_armour.alert_armour(floor_robe_plain)
      T.false_(result_b ~= nil and result_b ~= false, "test-b-no-alert-for-same-weight-same-ego")

      -- ── Restore all settings ──────────────────────────────────────
      H.early_xl           = orig_early
      M.body_armour        = orig_body
      M.armour_ego         = orig_ego
      M.high_score_armour  = orig_hs
      pa_high_score.ac     = orig_hs_ac
      A.armour_sensitivity = orig_sens

      T.pass("pickup-alert-lighter-armour")
      T.done()
    end
  end)
end
