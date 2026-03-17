---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (very_low_hp logic)
-- Verifies config values and synthetic math for the very_low_hp threshold in f_announce_hp_mp.
--
-- Tests (all synthetic, no game turns needed):
--   1. very_low_hp threshold is in range (0, 0.5)
--   2. dmg_flash_threshold is in range (0, 1.0)
--   3. At full HP (100%), is_very_low_hp formula evaluates to false
--   4. At 1% of mhp, is_very_low_hp formula evaluates to true
--   5. dmg_flash_threshold is >= 0.10
--   6. dmg_flash_threshold is <= 0.50
--   7. Synthetic 30% damage exceeds dmg_flash_threshold (confirms alert would fire normally)
--   8. very_low_hp equals 0.10 exactly
--
-- No CMD_WAIT needed — all assertions run in the init/turn-0 ready() call.
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_very_low_hp = {}
test_announce_hp_mp_very_low_hp.BRC_FEATURE_NAME = "test-announce-hp-mp-very-low-hp"

function test_announce_hp_mp_very_low_hp.ready()
  if T._done then return end

  T.run("announce-hp-mp-very-low-hp", function()
    local C = f_announce_hp_mp.Config

    -- ── 1. very_low_hp threshold is a fraction between 0 and 0.5 ─────────────
    T.true_(C.Announce.very_low_hp > 0 and C.Announce.very_low_hp < 0.5,
            "very-low-hp-threshold-in-range")

    -- ── 2. dmg_flash_threshold is a fraction between 0 and 1 ─────────────────
    T.true_(C.dmg_flash_threshold > 0 and C.dmg_flash_threshold < 1.0,
            "dmg-flash-threshold-in-range")

    -- ── 3. At full HP, is_very_low_hp should be false ─────────────────────────
    -- A mummy starts at full HP; 100% > 10% threshold.
    local hp, mhp = you.hp()
    local is_very_low_hp_now = hp <= C.Announce.very_low_hp * mhp
    T.false_(is_very_low_hp_now, "full-hp-is-not-very-low")

    -- ── 4. Synthetic: hp at 1% of mhp => is_very_low_hp is true ──────────────
    local syn_hp_1pct = math.floor(mhp * 0.01)
    local syn_is_very_low = syn_hp_1pct <= C.Announce.very_low_hp * mhp
    T.true_(syn_is_very_low, "1pct-hp-is-very-low")

    -- ── 5. dmg_flash_threshold is at least 10% ────────────────────────────────
    T.true_(C.dmg_flash_threshold >= 0.10, "dmg-flash-threshold-at-least-10pct")

    -- ── 6. dmg_flash_threshold is at most 50% ────────────────────────────────
    T.true_(C.dmg_flash_threshold <= 0.50, "dmg-flash-threshold-at-most-50pct")

    -- ── 7. Synthetic 30% damage exceeds flash threshold ───────────────────────
    -- Confirms that without the very_low_hp guard, a damage alert would fire.
    local syn_damage = math.floor(mhp * 0.30)
    local syn_exceeds_threshold = syn_damage >= mhp * C.dmg_flash_threshold
    T.true_(syn_exceeds_threshold, "synthetic-30pct-damage-exceeds-flash-threshold")

    -- ── 8. very_low_hp default value is exactly 0.10 ─────────────────────────
    T.eq(C.Announce.very_low_hp, 0.10, "very-low-hp-equals-0.10")

    T.pass("announce-hp-mp-very-low-hp")
    T.done()
  end)
end
