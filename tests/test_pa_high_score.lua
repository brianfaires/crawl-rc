---------------------------------------------------------------------------------------------------
-- BRC feature test: pa_high_score tracking
-- Verifies update_high_scores() returns the correct category name when a new high score is set,
-- and nil when no new high score is set.
--
-- How pa_high_score is seeded at game start (important context):
--   - pa_high_score.ac starts at 0 at BRC.init() time, but f_pickup_alert.ready() immediately
--     calls update_high_scores(items.equipped_at("armour")) on turn 0, seeding the animal skin.
--     By the time "verify" runs, pa_high_score.ac == animal skin effective AC (~5.34).
--   - pa_high_score.weapon starts at 0 at BRC.init() time, but f_pa_weapons.init() (called by
--     f_pickup_alert.init()) iterates inventory weapons and calls update_high_scores() for each,
--     seeding the starting mace's DPS (~11.004) before the first ready() ever fires.
--   - Consequence: pa_high_score.weapon > 0 from the very first ready() call. The starting mace
--     IS seeded (contrary to the original design assumption). This is because _weapon_cache.ready()
--     calls update_high_scores() for every inventory weapon on init.
--
-- This test:
--   1. Verifies pa_high_score.ac == 0 at BRC.init() time (before first ready()).
--   2. Verifies pa_high_score.weapon > 0 by turn 0 (seeded by f_pa_weapons.init()).
--   3. Gives plate armour — base AC 10, well above animal skin's seeded value (~5.34).
--      Temporarily disables Config.Alert.More.high_score_armour to prevent crawl.more() blocking
--      when the plate armour is seen by autopickup on the floor.
--      Verifies update_high_scores returns "Highest AC" and .ac increases.
--   4. Gives mace plus:5 — DPS beats the starting mace's seeded value (~11.004).
--      Disables weapon-related More flags to prevent blocking.
--      Verifies update_high_scores returns "Highest damage" or "Highest plain damage".
--   5. Calling update_high_scores again with the same items returns nil.
--
-- Phase flow:
--   "init"   (turn 0): assert pa_high_score initial state -> CMD_WAIT
--   "give"   (turn 1): disable force_more flags, wizard_give plate armour + mace plus:5,
--                      identify, re-enable force_more flags -> CMD_WAIT
--   "verify" (turn 2): find floor items, call update_high_scores directly, assert returns + state
---------------------------------------------------------------------------------------------------

test_pa_high_score = {}
test_pa_high_score.BRC_FEATURE_NAME = "test-pa-high-score"

local _phase = "init"

function test_pa_high_score.ready()
  if T._done then return end

  T.run("pa-high-score", function()

    -- ----------------------------------------------------------------
    -- Phase "init": verify pa_high_score state at BRC.init() time.
    -- This ready() fires on turn 0. BRC.init() has run (including
    -- f_pa_weapons.init() which seeded weapon/plain_dmg from starting
    -- mace) but f_pickup_alert.ready() has NOT yet fired this turn
    -- (it runs after us in reverse-alpha order since "pickup-alert"
    -- comes before "test-pa-high-score" alphabetically).
    -- So: .ac == 0, .weapon > 0, .plain_dmg > 0.
    -- ----------------------------------------------------------------
    if _phase == "init" then
      crawl.stderr("DEBUG init: pa_high_score={ ac="
        .. tostring(pa_high_score.ac) .. ", weapon="
        .. tostring(pa_high_score.weapon) .. ", plain_dmg="
        .. tostring(pa_high_score.plain_dmg) .. " }")

      -- ac starts at 0: equipped armour is scanned in ready(), not init()
      T.eq(pa_high_score.ac, 0, "initial-pa_high_score.ac-is-0")

      -- weapon and plain_dmg already seeded by f_pa_weapons.init() scanning inventory
      T.true_(pa_high_score.weapon > 0, "initial-pa_high_score.weapon-seeded-by-init")
      T.true_(pa_high_score.plain_dmg > 0, "initial-pa_high_score.plain_dmg-seeded-by-init")

      _phase = "give"
      crawl.do_commands({"CMD_WAIT"})

    -- ----------------------------------------------------------------
    -- Phase "give": disable force_more flags, give items, identify.
    --
    -- Must disable force_more settings before giving items: when
    -- f_pickup_alert.autopickup() sees plate armour on the floor on
    -- the next turn, it fires a "Highest AC" alert with
    -- high_score_armour=true (force_more), which calls crawl.more()
    -- and blocks. Same applies to the mace+5 (high_score_weap).
    -- ----------------------------------------------------------------
    elseif _phase == "give" then
      local M = f_pickup_alert.Config.Alert.More
      local orig_hs_armour  = M.high_score_armour
      local orig_hs_weap    = M.high_score_weap
      local orig_upgrade    = M.upgrade_weap
      local orig_early      = M.early_weap
      local orig_ego        = M.weap_ego
      M.high_score_armour   = false
      M.high_score_weap     = false
      M.upgrade_weap        = false
      M.early_weap          = false
      M.weap_ego            = false

      T.wizard_give("plate armour")
      T.wizard_give("mace plus:5")
      T.wizard_identify_all()

      M.high_score_armour   = orig_hs_armour
      M.high_score_weap     = orig_hs_weap
      M.upgrade_weap        = orig_upgrade
      M.early_weap          = orig_early
      M.weap_ego            = orig_ego

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    -- ----------------------------------------------------------------
    -- Phase "verify": call update_high_scores directly, check results.
    -- Disable force_more to prevent blocking during this phase too,
    -- in case autopickup or ready() fires alerts for items on floor.
    -- ----------------------------------------------------------------
    elseif _phase == "verify" then
      local M = f_pickup_alert.Config.Alert.More
      local orig_hs_armour  = M.high_score_armour
      local orig_hs_weap    = M.high_score_weap
      M.high_score_armour   = false
      M.high_score_weap     = false

      -- ---- find items on floor ----
      local floor_armour = nil
      local floor_weapon = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_body_armour(it) and not floor_armour then
          floor_armour = it
        elseif it.is_weapon and not floor_weapon then
          floor_weapon = it
        end
      end

      crawl.stderr("DEBUG verify: floor_armour=" .. tostring(floor_armour and floor_armour.name() or "nil"))
      crawl.stderr("DEBUG verify: floor_weapon=" .. tostring(floor_weapon and floor_weapon.name() or "nil"))

      -- ---- Guard: items must be present ----
      T.true_(floor_armour ~= nil, "plate-armour-on-floor")
      T.true_(floor_weapon ~= nil, "mace-plus5-on-floor")
      if not floor_armour or not floor_weapon then
        M.high_score_armour = orig_hs_armour
        M.high_score_weap   = orig_hs_weap
        T.done()
        return
      end

      -- ---- Snapshot pa_high_score before test calls ----
      -- By turn 2, pa_high_score.ac has been set from the animal skin by
      -- f_pickup_alert.ready() calls on turns 0 and 1. plate armour (AC 10)
      -- should produce get_ac() > that value.
      local ac_before     = pa_high_score.ac
      local weapon_before = pa_high_score.weapon
      local plain_before  = pa_high_score.plain_dmg

      crawl.stderr("DEBUG before-test: pa_high_score={ ac="
        .. tostring(ac_before) .. ", weapon="
        .. tostring(weapon_before) .. ", plain_dmg="
        .. tostring(plain_before) .. " }")

      -- ---- Test 1: plate armour sets "Highest AC" ----
      -- Plate armour base AC 10 produces get_ac() ~10.68, above animal skin (~5.34).
      -- By "verify" turn, autopickup may have already called update_high_scores for
      -- plate armour (via c_assign_invletter or autopickup). Reset pa_high_score.ac
      -- to 0 so we can reliably verify the "new high score" path returns "Highest AC".
      local saved_ac = pa_high_score.ac
      pa_high_score.ac = 0
      local armour_result = f_pa_data.update_high_scores(floor_armour)
      crawl.stderr("DEBUG update_high_scores(plate_armour)=" .. tostring(armour_result))
      T.eq(armour_result, "Highest AC", "plate-armour-returns-Highest-AC")
      T.true_(pa_high_score.ac > 0, "pa_high_score.ac-increased-from-zero")
      -- Restore to what autopickup/ready() set (the actual plate-armour value)
      pa_high_score.ac = saved_ac

      -- ---- Test 2: mace plus:5 sets a weapon high score ----
      -- By "verify" turn, autopickup may have already updated weapon scores for mace+5.
      -- Reset both to 0 so the "new high score" path reliably fires.
      local saved_weapon    = pa_high_score.weapon
      local saved_plain_dmg = pa_high_score.plain_dmg
      pa_high_score.weapon    = 0
      pa_high_score.plain_dmg = 0
      local weapon_result = f_pa_data.update_high_scores(floor_weapon)
      crawl.stderr("DEBUG update_high_scores(mace+5)=" .. tostring(weapon_result))
      T.true_(
        weapon_result == "Highest damage" or weapon_result == "Highest plain damage",
        "mace-plus5-returns-a-high-score-category"
      )
      T.true_(
        pa_high_score.weapon > 0 or pa_high_score.plain_dmg > 0,
        "pa_high_score-weapon-or-plain_dmg-increased-from-zero"
      )
      -- Leave pa_high_score.weapon/.plain_dmg at the values update_high_scores just set,
      -- so the "second call returns nil" check below can verify idempotency correctly.
      -- (saved_weapon/saved_plain_dmg were from before the reset, not from after the call)

      crawl.stderr("DEBUG after-test: pa_high_score={ ac="
        .. tostring(pa_high_score.ac) .. ", weapon="
        .. tostring(pa_high_score.weapon) .. ", plain_dmg="
        .. tostring(pa_high_score.plain_dmg) .. " }")

      -- ---- Test 3: calling again with same items returns nil ----
      local armour_result2 = f_pa_data.update_high_scores(floor_armour)
      crawl.stderr("DEBUG update_high_scores(plate_armour) 2nd=" .. tostring(armour_result2))
      T.eq(armour_result2, nil, "plate-armour-second-call-returns-nil")

      local weapon_result2 = f_pa_data.update_high_scores(floor_weapon)
      crawl.stderr("DEBUG update_high_scores(mace+5) 2nd=" .. tostring(weapon_result2))
      T.eq(weapon_result2, nil, "mace-plus5-second-call-returns-nil")

      -- Restore More flags
      M.high_score_armour = orig_hs_armour
      M.high_score_weap   = orig_hs_weap

      T.pass("pa-high-score")
      T.done()
    end
  end)
end
