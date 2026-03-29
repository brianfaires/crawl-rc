---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (HEAVIER body armour, should_alert_body_armour returns false)
-- Exercises the code path in alert_body_armour() where encumb_delta > 0 (HEAVIER) but
-- should_alert_body_armour() returns false, suppressing the alert.
--
-- Character: Mummy Berserker, starts wearing a plain robe (AC 2, enc 0, no ego).
-- Floor item: chain mail (AC 4, enc 17, no ego).
--
-- Code path in alert_body_armour():
--   it_ego = nil, cur_ego = nil -> ego_change = SAME
--   encumb_delta = 17 > 0 -> weight = HEAVIER
--   is_good_ego_change(SAME, true) = false -> skip same-encumbrance fast path
--   encumb_delta > 0 -> HEAVIER branch:
--     adj_ev_delta = get_adjusted_ev_delta(17, ev_delta)  [negative: heavier -> EV penalty]
--     should_alert_body_armour(HEAVIER, ac_delta, -adj_ev_delta, SAME):
--       For SAME ego: return loss <= H.Heavier.max_loss * armour_sensitivity
--       With armour_sensitivity = 0.001: max_loss threshold = 8.0 * 0.001 = 0.008
--       -adj_ev_delta is a positive loss >> 0.008 -> returns FALSE
--   alert_highest_ac: pa_high_score.ac = 999 -> returns false
--   early_xl = 0: you.xl() (1) <= 0 is false -> no "Early armour"
--   -> function returns nil (no alert)
--
-- This exercises the untested path: HEAVIER + SAME ego where should_alert_body_armour
-- returns false due to armour_sensitivity being too low to pass the max_loss threshold.
--
-- To prevent force_more hangs in headless mode:
--   - M.body_armour, M.armour_ego, M.high_score_armour all set to false
--   - pa_high_score.ac = 999 to block the high-score alert path
--   - early_xl = 0 to block the "Early armour" fallback
--   - armour_sensitivity = 0.001 to ensure should_alert_body_armour returns false
--
-- Phase flow:
--   "give"   (turn 0): wizard_give chain mail + identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): locate floor item, assert alert_armour returns nil
---------------------------------------------------------------------------------------------------

test_pickup_alert_heavier_no_alert = {}
test_pickup_alert_heavier_no_alert.BRC_FEATURE_NAME = "test-pickup-alert-heavier-no-alert"

local _phase = "give"

function test_pickup_alert_heavier_no_alert.ready()
  if T._done then return end

  T.run("pickup-alert-heavier-no-alert", function()

    -- ----------------------------------------------------------------
    -- Phase "give": place a plain chain mail on the floor.
    -- chain mail: AC 4, enc 17, no ego.
    -- It is HEAVIER than the starting robe (enc 0) and has the SAME ego (nil).
    -- ----------------------------------------------------------------
    if _phase == "give" then
      T.wizard_give("chain mail")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    -- ----------------------------------------------------------------
    -- Phase "verify": call alert_armour directly and assert no alert.
    -- ----------------------------------------------------------------
    elseif _phase == "verify" then

      -- ── Find the chain mail on the floor ─────────────────────────
      local floor_armour = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and it.name("base"):find("chain mail") then
          floor_armour = it
          break
        end
      end
      T.true_(floor_armour ~= nil, "chain-mail-on-floor")
      if not floor_armour then T.done() return end

      -- ── Sanity-check preconditions ────────────────────────────────
      local cur = items.equipped_at("armour")
      T.true_(cur ~= nil, "body-armour-equipped")
      if not cur then T.done() return end

      -- Equipped armour must have no ego (plain robe).
      T.false_(BRC.eq.get_ego(cur) ~= nil, "equipped-has-no-ego")

      -- Floor item must also have no ego.
      T.false_(BRC.eq.get_ego(floor_armour) ~= nil, "floor-armour-has-no-ego")

      -- Floor item must be heavier (enc > cur enc).
      T.true_(floor_armour.encumbrance > cur.encumbrance, "chain-mail-is-heavier")

      -- ── Snapshot and override all settings ───────────────────────
      local M          = f_pickup_alert.Config.Alert.More
      local orig_body  = M.body_armour
      local orig_ego   = M.armour_ego
      local orig_hs    = M.high_score_armour
      M.body_armour    = false
      M.armour_ego     = false
      M.high_score_armour = false

      -- Block the highest-AC path: pre-fill pa_high_score.ac to 999.
      local orig_hs_ac    = pa_high_score.ac
      pa_high_score.ac    = 999

      -- Block the "Early armour" fallback by zeroing early_xl.
      local H             = f_pickup_alert.Config.Tuning.Armour
      local orig_early    = H.early_xl
      H.early_xl          = 0

      -- Set armour_sensitivity extremely low so should_alert_body_armour returns false:
      --   For SAME ego: return loss <= H.Heavier.max_loss * sensitivity
      --   0.001 * 8.0 = 0.008 — any real EV loss from enc 17 chain mail exceeds this.
      local A             = f_pickup_alert.Config.Alert
      local orig_sens     = A.armour_sensitivity
      A.armour_sensitivity = 0.001

      -- Forget any prior alert record so already_alerted() doesn't short-circuit.
      f_pa_data.forget_alert(floor_armour)

      -- ── Exercise: alert_armour should return nil (no alert) ──────
      -- Code path:
      --   ego_change = SAME (both nil)
      --   is_good_ego_change(SAME, true) = false -> skip fast ego path
      --   encumb_delta > 0 -> HEAVIER branch
      --   should_alert_body_armour(HEAVIER, ac_delta, -adj_ev_delta, SAME):
      --     loss > 0.008 threshold -> returns false
      --   alert_highest_ac: 999 blocks it
      --   early_xl = 0: xl(1) > 0 -> no "Early armour"
      --   -> returns nil
      local result = f_pa_armour.alert_armour(floor_armour)
      T.false_(result ~= nil and result ~= false, "heavier-same-ego-low-sensitivity-no-alert")

      -- ── Restore all settings ──────────────────────────────────────
      M.body_armour        = orig_body
      M.armour_ego         = orig_ego
      M.high_score_armour  = orig_hs
      pa_high_score.ac     = orig_hs_ac
      H.early_xl           = orig_early
      A.armour_sensitivity = orig_sens

      T.pass("pickup-alert-heavier-no-alert")
      T.done()
    end
  end)
end
