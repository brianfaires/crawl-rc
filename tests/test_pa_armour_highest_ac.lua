---------------------------------------------------------------------------------------------------
-- BRC feature test: pa-armour alert_highest_ac
-- Verifies alert_highest_ac initialization and suppression behavior.
--
-- Character: Mummy Berserker, starts wearing a plain robe (low AC).
-- XL 1 (well below the >12 guard), no Spellcasting or Ranged Weapons skill.
--
-- alert_highest_ac flow (lines ~205-223 of pa-armour.lua):
--   if you.xl() > 12               → return false (guard)
--   if total_skill > 0 and Armour==0 → return false (caster guard)
--   if pa_high_score.ac == 0        → seed from equipped armour, return false
--   else if floor_AC > high_score   → update and fire "Highest AC"
--
-- Sub-test A: pa_high_score.ac seeding
--   Reset pa_high_score.ac = 0, give a plain robe (same as equipped),
--   call alert_body_armour. Since both items are identical plain robes:
--   no artefact, no ego change, same encumbrance, same AC → falls through to
--   alert_highest_ac → seeding branch fires → returns false, high score set.
--
-- Sub-test B: no alert when floor AC <= high score
--   pa_high_score.ac is now set from the equipped robe.
--   Give a second plain robe (same AC). Call again.
--   Floor robe AC == high_score → no alert → returns nil/false.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "robe"; identify; CMD_WAIT → turn 1
--   "check"  (turn 1): run sub-tests A and B, then T.pass + T.done()
--                      (no message queued; no verify phase needed)
---------------------------------------------------------------------------------------------------

test_pa_armour_highest_ac = {}
test_pa_armour_highest_ac.BRC_FEATURE_NAME = "test-pa-armour-highest-ac"

local _phase = "give"
local _floor_robe = nil

function test_pa_armour_highest_ac.ready()
  if T._done then return end

  T.run("pa-armour-highest-ac", function()

    -- ── Phase 1: place a plain robe on the floor ────────────────────────────────────────────
    if _phase == "give" then
      T.wizard_give("robe")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    -- ── Phase 2: run alert_highest_ac sub-tests ─────────────────────────────────────────────
    elseif _phase == "check" then

      -- Find plain robe on floor
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and not it.artefact then
          _floor_robe = it
          break
        end
      end
      T.true_(_floor_robe ~= nil, "plain-robe-on-floor")
      if not _floor_robe then T.done() return end

      -- Debug: log names for diagnosis
      crawl.stderr("floor_robe name(): "    .. tostring(_floor_robe.name()))
      crawl.stderr("floor_robe name(base):" .. tostring(_floor_robe.name("base")))
      crawl.stderr("you.xl(): "             .. tostring(you.xl()))
      crawl.stderr("pa_high_score.ac before reset: " .. tostring(pa_high_score.ac))

      -- Suppress all force_more flags that body armour or high-score paths might trigger.
      -- M.armour_ego must be false: has_configured_force_more() checks it last.
      local M = f_pickup_alert.Config.Alert.More
      local orig_body_armour    = M.body_armour
      local orig_armour_ego     = M.armour_ego
      local orig_high_score_arm = M.high_score_armour
      M.body_armour    = false
      M.armour_ego     = false
      M.high_score_arm = false

      -- ---- Sub-test A: seeding branch (pa_high_score.ac == 0) ----
      -- Reset to zero so the seeding branch fires.
      local saved_ac = pa_high_score.ac
      pa_high_score.ac = 0

      f_pa_data.forget_alert(_floor_robe)
      local result_A = f_pa_armour.alert_armour(_floor_robe)

      crawl.stderr("result_A (seeding): " .. tostring(result_A))
      crawl.stderr("pa_high_score.ac after seeding: " .. tostring(pa_high_score.ac))

      -- After seeding, high score should be > 0 (set from the equipped robe)
      T.true_(pa_high_score.ac > 0, "ac-high-score-seeded-from-equipped-robe")
      -- Seeding returns false (not an alert)
      T.true_(result_A == nil or result_A == false, "no-alert-on-seeding-turn")

      -- ---- Sub-test B: no alert when floor AC <= high score ----
      -- pa_high_score.ac is now set. Floor robe has same AC as equipped robe,
      -- so itAC <= pa_high_score.ac → no alert.
      f_pa_data.forget_alert(_floor_robe)
      local result_B = f_pa_armour.alert_armour(_floor_robe)

      crawl.stderr("result_B (no-alert): " .. tostring(result_B))

      T.true_(result_B == nil or result_B == false, "no-alert-when-floor-ac-not-above-high-score")

      -- Restore More flags and pa_high_score
      M.body_armour    = orig_body_armour
      M.armour_ego     = orig_armour_ego
      M.high_score_arm = orig_high_score_arm
      pa_high_score.ac = saved_ac

      T.pass("pa-armour-highest-ac")
      T.done()
    end
  end)
end
