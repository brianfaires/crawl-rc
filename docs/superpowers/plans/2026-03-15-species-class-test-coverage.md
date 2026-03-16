# Species/Class Test Coverage — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the BRC test suite from 94 Mummy-only tests to include a per-test character override mechanism and 12 new tests covering species-specific BRC logic across Gnoll, Octopode, Gargoyle, Formicid, Naga, Djinni, Spriggan, Kobold, Poltergeist, Revenant, Demonspawn, and Coglin.

**Architecture:** Two independent changes: (1) `tests/run.sh` gains per-test character override extraction from `-- @species`/`-- @background`/`-- @weapon` header comments, substituted into `$TEST_FLAGS` before each crawl launch; (2) 12 new Lua test files implement targeted assertions against existing BRC species-specific code paths, following established patterns from `test_pickup_alert_branded_weapon.lua` and `test_pickup_alert_unneeded_ring.lua`.

**Tech Stack:** Bash (`run.sh`), Lua (test files), DCSS headless console binary + `fake_pty`

---

## File Structure

**Modified:**
- `tests/run.sh` — insert 7-line per-test override block after TEMP_RC build; change `$CRAWL_FLAGS` → `$TEST_FLAGS` in launch command

**Created — Tier 1 (named exceptions):**
- `tests/test_pickup_alert_gnoll_falchion.lua` — Gnoll bypasses `UPGRADE_SKILL_FACTOR` gate in `is_upgradable_weapon()`, allowing cross-skill floor weapon to reach ego comparison
- `tests/test_pickup_alert_octopode_ring.lua` — Octopode `is_unneeded_ring()` short-circuits to false regardless of ring count
- `tests/test_dynamic_options_race_gargoyle.lua` — Gargoyle is NONLIVING + POIS_RES (not UNDEAD); holy not useless, rPois useless
- `tests/test_pickup_alert_formicid_gloves.lua` — Formicid `num_eq_slots(gloves)` returns 2 (4 arms)

**Created — Tier 2 (race table membership):**
- `tests/test_dynamic_options_race_naga.lua` — Naga LARGE size + POIS_RES; not undead or nonliving
- `tests/test_announce_hp_mp_djinni.lua` — Djinni `mmp=0` (MUT_HP_CASTING) does not crash `f_announce_hp_mp`
- `tests/test_dynamic_options_race_spriggan.lua` — Spriggan LITTLE size; absent from all other race tables
- `tests/test_dynamic_options_race_kobold.lua` — Kobold SMALL size; not LITTLE or LARGE

**Created — Tier 3 (full table coverage):**
- `tests/test_dynamic_options_race_poltergeist.lua` — Poltergeist UNDEAD + mutation_immune + 6 aux slots
- `tests/test_dynamic_options_race_revenant.lua` — Revenant UNDEAD + POIS_RES; not NONLIVING
- `tests/test_dynamic_options_race_demonspawn.lua` — Demonspawn in `BRC.UNDEAD_RACES` (BRC-only; US_ALIVE in DCSS)
- `tests/test_pickup_alert_coglin_dual_weapon.lua` — Coglin `num_eq_slots(weapon)` returns 2

Each test file is self-contained — one responsibility, one feature assertion, one species. No shared state between files.

---

## Chunk 1: Infrastructure + Tier 1 Tests

### Task 1: Add per-test character override to run.sh

**Files:**
- Modify: `tests/run.sh:101-108`

- [ ] **Step 1: Verify current run.sh structure**

Read `tests/run.sh` lines 97–112 to confirm the `tail -n` line and `$CRAWL_FLAGS` line are where expected before editing.

- [ ] **Step 2: Insert the override block + change $CRAWL_FLAGS**

In `tests/run.sh`, replace the block from after the `tail -n` line through the `$CRAWL_FLAGS` launch line. The old text:

```
  tail -n "+${INIT_LINE}" "${REPO_ROOT}/bin/buehler.rc" >> "${TEMP_RC}"

  # Run crawl with timeout.
  # fake_pty provides a PTY for stdin/stdout so the console binary runs headlessly.
  # It does NOT wrap stderr, so crawl.stderr() output flows directly to the shell redirection.
  set +e
  $TIMEOUT_CMD "${TIMEOUT_SEC}" \
    "${FAKE_PTY_BIN_RESOLVED}" "${CRAWL_BIN_RESOLVED}" $CRAWL_FLAGS -rc "${TEMP_RC}" \
```

Replace with:

```
  tail -n "+${INIT_LINE}" "${REPO_ROOT}/bin/buehler.rc" >> "${TEMP_RC}"

  # Per-test character overrides: read -- @species / -- @background / -- @weapon header comments.
  SPECIES_OVERRIDE=$(grep -m1 "^-- @species "    "$TEST_FILE" | sed 's/^-- @species //')
  BG_OVERRIDE=$(grep -m1     "^-- @background " "$TEST_FILE" | sed 's/^-- @background //')
  WEAPON_OVERRIDE=$(grep -m1 "^-- @weapon "     "$TEST_FILE" | sed 's/^-- @weapon //')
  TEST_FLAGS="$CRAWL_FLAGS"
  [[ -n "$SPECIES_OVERRIDE" ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/-species [^ ]*/-species $SPECIES_OVERRIDE/")
  [[ -n "$BG_OVERRIDE"      ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/-background [^ ]*/-background $BG_OVERRIDE/")
  [[ -n "$WEAPON_OVERRIDE"  ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/weapon=[^ ]*/weapon=$WEAPON_OVERRIDE/")

  # Run crawl with timeout.
  # fake_pty provides a PTY for stdin/stdout so the console binary runs headlessly.
  # It does NOT wrap stderr, so crawl.stderr() output flows directly to the shell redirection.
  set +e
  $TIMEOUT_CMD "${TIMEOUT_SEC}" \
    "${FAKE_PTY_BIN_RESOLVED}" "${CRAWL_BIN_RESOLVED}" $TEST_FLAGS -rc "${TEMP_RC}" \
```

- [ ] **Step 3: Run the full existing test suite to confirm no regression**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh
```

Expected: all existing tests pass (`Results: 94/94 passed` or similar, `OK`).

- [ ] **Step 4: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/run.sh
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: add per-test species/background/weapon override to run.sh"
```

---

### Task 2: Gnoll Berserker falchion — cross-skill UPGRADE_SKILL_FACTOR bypass

**Files:**
- Create: `tests/test_pickup_alert_gnoll_falchion.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Gn
-- @background Be
-- @weapon falchion
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Gnoll cross-skill UPGRADE_SKILL_FACTOR bypass)
-- Verifies f_pa_weapons.alert_weapon() fires an alert for a cross-skill floor weapon
-- (flaming mace vs starting falchion) for Gnoll, where the UPGRADE_SKILL_FACTOR gate at
-- pa-weapons.lua:65 is bypassed.
--
-- For non-Gnoll, is_upgradable_weapon() returns false at line 65 when the floor weapon's
-- skill is untrained: skill(M&F=0) >= 0.5 * skill(LongBlades=3) → 0 >= 1.5 → false.
-- Gnoll skips this gate, so the flaming mace reaches get_upgrade_alert() and the ego
-- comparison in check_upgrade_cross_subtype, where it fires "Gain ego".
--
-- gain_ego=0 makes the assertion config-independent (any non-zero ratio fires).
-- All other alert paths (early_weap, high_score) are suppressed to isolate the upgrade path.
--
-- Phase flow:
--   "give"   (turn 0): wizard-give flaming mace, identify, CMD_WAIT → turn 1
--   "verify" (turn 1): find floor mace, suppress other alerts, set gain_ego=0,
--                      call alert_weapon, assert fires, restore, T.pass, T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_gnoll_falchion = {}
test_pickup_alert_gnoll_falchion.BRC_FEATURE_NAME = "test-pickup-alert-gnoll-falchion"

local _phase = "give"

function test_pickup_alert_gnoll_falchion.ready()
  if T._done then return end

  T.run("pickup-alert-gnoll-falchion", function()

    if _phase == "give" then
      T.wizard_give("mace ego:flaming plus:3")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.eq(you.race(), "Gnoll", "char-is-gnoll")

      local floor_mace = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name():find("flaming") and it.subtype() == "mace" then
          floor_mace = it
          break
        end
      end
      T.true_(floor_mace ~= nil, "flaming-mace-on-floor")
      if not floor_mace then T.done() return end

      -- Disable force_more for all weapon alert types to prevent headless hang
      local M = f_pickup_alert.Config.Alert.More
      local orig_upgrade   = M.upgrade_weap
      local orig_early     = M.early_weap
      local orig_hs        = M.high_score_weap
      local orig_ego       = M.weap_ego
      M.upgrade_weap    = false
      M.early_weap      = false
      M.high_score_weap = false
      M.weap_ego        = false

      -- Suppress early-weapon window (XL 1 <= Early.xl=7 would fire before upgrade path)
      local orig_early_xl        = f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl
      local orig_early_ranged_xl = f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl       = 0
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl = 0

      -- Pre-fill pa_high_score so the floor mace never triggers a high-score alert
      local orig_hs_weapon    = pa_high_score.weapon
      local orig_hs_plain     = pa_high_score.plain_dmg
      pa_high_score.weapon    = 999
      pa_high_score.plain_dmg = 999

      -- Set gain_ego=0: any non-zero ego ratio fires (config-independent assertion)
      local W_Alert = f_pickup_alert.Config.Tuning.Weap.Alert
      local orig_gain_ego = W_Alert.gain_ego
      W_Alert.gain_ego = 0

      -- Core assertion: Gnoll bypasses UPGRADE_SKILL_FACTOR → cross-skill ego alert fires
      local result = f_pa_weapons.alert_weapon(floor_mace)
      T.true_(result ~= nil and result ~= false, "gnoll-cross-skill-upgrade-fires")

      -- Restore all settings
      W_Alert.gain_ego                                          = orig_gain_ego
      pa_high_score.weapon                                      = orig_hs_weapon
      pa_high_score.plain_dmg                                   = orig_hs_plain
      f_pickup_alert.Config.Tuning.Weap.Alert.Early.xl          = orig_early_xl
      f_pickup_alert.Config.Tuning.Weap.Alert.EarlyRanged.xl    = orig_early_ranged_xl
      M.upgrade_weap    = orig_upgrade
      M.early_weap      = orig_early
      M.high_score_weap = orig_hs
      M.weap_ego        = orig_ego

      T.pass("pickup-alert-gnoll-falchion")
      T.done()
    end
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_pickup_alert_gnoll_falchion
```

Expected output includes: `[PASS] pickup-alert-gnoll-falchion` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_pickup_alert_gnoll_falchion.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: gnoll cross-skill UPGRADE_SKILL_FACTOR bypass (Tier 1)"
```

---

### Task 3: Octopode Berserker handaxe — is_unneeded_ring short-circuit

**Files:**
- Create: `tests/test_pickup_alert_octopode_ring.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Op
-- @background Be
-- @weapon handaxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Octopode is_unneeded_ring short-circuit)
-- Verifies f_pa_misc.is_unneeded_ring() returns false for Octopode even when 2 rings of
-- the same subtype are in inventory (pa-misc.lua:108 short-circuits on you.race() == "Octopode").
--
-- Octopode can wear 8 rings (one per tentacle arm), so no ring is ever "unneeded" for them.
-- For non-Octopode with 2 same-type rings in inventory, is_unneeded_ring returns true.
-- For Octopode, it returns false regardless.
--
-- Phase flow:
--   "give1"   (turn 0): wizard-give 1st ring of slaying, identify, CMD_WAIT -> turn 1
--   "pickup1" (turn 1): CMD_PICKUP (pick up 1st ring), phase -> "give2"
--   "give2"   (turn 2): wizard-give 2nd ring of slaying, identify, CMD_WAIT -> turn 3
--   "pickup2" (turn 3): CMD_PICKUP (pick up 2nd ring), phase -> "verify"
--   "verify"  (turn 4): wizard-give 3rd ring, find on floor, assert is_unneeded_ring=false;
--                       T.pass, T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_octopode_ring = {}
test_pickup_alert_octopode_ring.BRC_FEATURE_NAME = "test-pickup-alert-octopode-ring"

local _phase = "give1"

function test_pickup_alert_octopode_ring.ready()
  if T._done then return end

  T.run("pickup-alert-octopode-ring", function()

    if _phase == "give1" then
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()
      _phase = "pickup1"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup1" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give2"

    elseif _phase == "give2" then
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()
      _phase = "pickup2"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "pickup2" then
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "verify"

    elseif _phase == "verify" then
      T.eq(you.race(), "Octopode", "char-is-octopode")

      -- Confirm 2 rings of slaying are in inventory
      local ring_st = nil
      local inv_count = 0
      for _, inv in ipairs(items.inventory()) do
        if BRC.it.is_ring(inv) then
          ring_st = ring_st or inv.subtype()
          if inv.subtype() == ring_st then
            inv_count = inv_count + 1
          end
        end
      end
      T.true_(inv_count >= 2, "two-rings-of-slaying-in-inventory")

      -- Give a 3rd ring of same type and leave it on the floor
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()

      local floor_ring = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_ring(it) and it.subtype() == ring_st then
          floor_ring = it
          break
        end
      end
      T.true_(floor_ring ~= nil, "third-ring-on-floor")

      -- Core assertion: Octopode short-circuit → ring is NOT unneeded even with 2 in inventory
      if floor_ring then
        local result = f_pa_misc.is_unneeded_ring(floor_ring)
        T.false_(result, "octopode-ring-not-unneeded")
      end

      -- Sanity: a DIFFERENT ring type (0 in inventory) is also not unneeded for Octopode
      T.wizard_give("ring of evasion")
      T.wizard_identify_all()
      local other_ring = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_ring(it) and it.subtype() ~= ring_st then
          other_ring = it
          break
        end
      end
      T.true_(other_ring ~= nil, "evasion-ring-on-floor")
      if other_ring then
        T.false_(f_pa_misc.is_unneeded_ring(other_ring), "octopode-different-ring-not-unneeded")
      end

      T.pass("pickup-alert-octopode-ring")
      T.done()
    end
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_pickup_alert_octopode_ring
```

Expected: `[PASS] pickup-alert-octopode-ring` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_pickup_alert_octopode_ring.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: octopode is_unneeded_ring short-circuit (Tier 1)"
```

---

### Task 4: Gargoyle Berserker mace — NONLIVING + POIS_RES race tables

**Files:**
- Create: `tests/test_dynamic_options_race_gargoyle.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Gr
-- @background Be
-- @weapon mace
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Gargoyle race table classification)
-- Gargoyle is NONLIVING (not UNDEAD) and in POIS_RES_RACES.
-- Exercises the nonliving miasma path and the rPois useless-ego path,
-- without triggering the undead holy-wrath path.
--
-- Key distinctions vs Mummy (which is UNDEAD + POIS_RES):
--   - Gargoyle: NONLIVING=true, UNDEAD=false → holy wrath force_more NOT set
--   - Gargoyle: rPois useless, but holy NOT useless
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_gargoyle = {}
test_dynamic_options_race_gargoyle.BRC_FEATURE_NAME = "test-dynamic-options-race-gargoyle"

function test_dynamic_options_race_gargoyle.ready()
  if T._done then return end

  T.run("dynamic-options-race-gargoyle", function()
    local race = you.race()
    T.eq(race, "Gargoyle", "char-is-gargoyle")

    T.true_(util.contains(BRC.NONLIVING_RACES, race), "gargoyle-nonliving")
    T.true_(util.contains(BRC.POIS_RES_RACES, race), "gargoyle-pois-res")
    T.false_(util.contains(BRC.UNDEAD_RACES, race), "gargoyle-not-undead")

    T.true_(BRC.you.miasma_immune(), "gargoyle-miasma-immune")
    T.false_(BRC.eq.is_useless_ego("holy"), "holy-not-useless-for-gargoyle")
    T.true_(BRC.eq.is_useless_ego("rPois"), "rpois-useless-for-gargoyle")

    T.pass("dynamic-options-race-gargoyle")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_dynamic_options_race_gargoyle
```

Expected: `[PASS] dynamic-options-race-gargoyle` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_dynamic_options_race_gargoyle.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: gargoyle NONLIVING+POIS_RES race table membership (Tier 1)"
```

---

### Task 5: Formicid Fighter waraxe — 2 glove slots via num_eq_slots

**Files:**
- Create: `tests/test_pickup_alert_formicid_gloves.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Fo
-- @background Fi
-- @weapon waraxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Formicid 2 glove equipment slots)
-- Verifies BRC.you.num_eq_slots() returns 2 for gloves for Formicid (you.lua:92 branch).
-- Formicid has 4 arms, so gloves occupy 2 aux slots.
-- Other item types (helmet, weapon) still return 1 for Formicid.
---------------------------------------------------------------------------------------------------

test_pickup_alert_formicid_gloves = {}
test_pickup_alert_formicid_gloves.BRC_FEATURE_NAME = "test-pickup-alert-formicid-gloves"

function test_pickup_alert_formicid_gloves.ready()
  if T._done then return end

  T.run("pickup-alert-formicid-gloves", function()
    T.eq(you.race(), "Formicid", "char-is-formicid")

    -- Place gloves and helmet on floor; leave both there
    T.wizard_give("pair of gloves")
    T.wizard_give("helmet")
    T.wizard_identify_all()

    local floor_gloves = nil
    local floor_helmet = nil
    for _, it in ipairs(you.floor_items()) do
      if it.is_armour then
        local n = it.name()
        if n:find("gloves") and not floor_gloves then
          floor_gloves = it
        elseif n:find("helmet") and not floor_helmet then
          floor_helmet = it
        end
      end
    end
    T.true_(floor_gloves ~= nil, "gloves-on-floor")
    T.true_(floor_helmet ~= nil, "helmet-on-floor")

    if floor_gloves then
      T.eq(BRC.you.num_eq_slots(floor_gloves), 2, "formicid-glove-slots-2")
    end
    if floor_helmet then
      T.eq(BRC.you.num_eq_slots(floor_helmet), 1, "formicid-helmet-slots-1")
    end

    -- Starting waraxe in weapon slot: Formicid has 1 weapon slot (not Coglin)
    local weap = items.equipped_at("weapon")
    if weap then
      T.eq(BRC.you.num_eq_slots(weap), 1, "formicid-weapon-slots-1")
    end

    T.pass("pickup-alert-formicid-gloves")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_pickup_alert_formicid_gloves
```

Expected: `[PASS] pickup-alert-formicid-gloves` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_pickup_alert_formicid_gloves.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: formicid 2-glove-slot num_eq_slots (Tier 1)"
```

---

## Chunk 2: Tier 2 Tests

### Task 6: Naga Berserker falchion — LARGE size + POIS_RES

**Files:**
- Create: `tests/test_dynamic_options_race_naga.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Na
-- @background Be
-- @weapon falchion
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Naga race table classification)
-- Naga is LARGE (SIZE_PENALTY.LARGE) and in POIS_RES_RACES.
-- Not in UNDEAD_RACES or NONLIVING_RACES.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_naga = {}
test_dynamic_options_race_naga.BRC_FEATURE_NAME = "test-dynamic-options-race-naga"

function test_dynamic_options_race_naga.ready()
  if T._done then return end

  T.run("dynamic-options-race-naga", function()
    local race = you.race()
    T.eq(race, "Naga", "char-is-naga")

    T.true_(util.contains(BRC.POIS_RES_RACES, race), "naga-pois-res")
    T.true_(util.contains(BRC.LARGE_RACES, race), "naga-large")
    T.false_(util.contains(BRC.UNDEAD_RACES, race), "naga-not-undead")
    T.false_(util.contains(BRC.NONLIVING_RACES, race), "naga-not-nonliving")

    T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.LARGE, "naga-large-size-penalty")
    T.true_(BRC.eq.is_useless_ego("rPois"), "naga-rpois-useless")
    T.false_(BRC.eq.is_useless_ego("holy"), "holy-not-useless-for-naga")

    T.pass("dynamic-options-race-naga")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_dynamic_options_race_naga
```

Expected: `[PASS] dynamic-options-race-naga` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_dynamic_options_race_naga.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: naga LARGE+POIS_RES race tables (Tier 2)"
```

---

### Task 7: Djinni Berserker handaxe — mmp=0 no-crash regression guard

**Files:**
- Create: `tests/test_announce_hp_mp_djinni.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Dj
-- @background Be
-- @weapon handaxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (Djinni mmp=0 regression guard)
-- Djinni has MUT_HP_CASTING: get_real_mp() returns 0. Both you.mp() values are 0.
-- f_announce_hp_mp must not crash on the first turn when mmp=0.
--
-- Phase flow:
--   "check" (turn 0): assert you.mp() == (0, 0), verify race tables, CMD_WAIT → turn 1
--   "done"  (turn 1): T.pass — no crash occurred during turn 1's announce_hp_mp call
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_djinni = {}
test_announce_hp_mp_djinni.BRC_FEATURE_NAME = "test-announce-hp-mp-djinni"

local _phase = "check"

function test_announce_hp_mp_djinni.ready()
  if T._done then return end

  T.run("announce-hp-mp-djinni", function()

    if _phase == "check" then
      T.eq(you.race(), "Djinni", "char-is-djinni")

      local mp, mmp = you.mp()
      T.eq(mp,  0, "djinni-mp-zero")
      T.eq(mmp, 0, "djinni-mmp-zero")

      local race = you.race()
      T.true_(util.contains(BRC.NONLIVING_RACES, race), "djinni-nonliving")
      T.true_(util.contains(BRC.POIS_RES_RACES, race), "djinni-pois-res")
      T.false_(util.contains(BRC.UNDEAD_RACES, race), "djinni-not-undead")

      _phase = "done"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "done" then
      -- Reaching here means announce_hp_mp did not crash with mmp=0
      T.pass("announce-hp-mp-djinni")
      T.done()
    end
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_announce_hp_mp_djinni
```

Expected: `[PASS] announce-hp-mp-djinni` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_announce_hp_mp_djinni.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: djinni mmp=0 no-crash regression guard (Tier 2)"
```

---

### Task 8: Spriggan Monk unarmed — LITTLE size, absent from other size tables

**Files:**
- Create: `tests/test_dynamic_options_race_spriggan.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Sp
-- @background Mo
-- @weapon unarmed
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Spriggan race table classification)
-- Spriggan is LITTLE (SIZE_PENALTY.LITTLE). Not in any other size table,
-- and not in POIS_RES_RACES, UNDEAD_RACES, or NONLIVING_RACES.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_spriggan = {}
test_dynamic_options_race_spriggan.BRC_FEATURE_NAME = "test-dynamic-options-race-spriggan"

function test_dynamic_options_race_spriggan.ready()
  if T._done then return end

  T.run("dynamic-options-race-spriggan", function()
    local race = you.race()
    T.eq(race, "Spriggan", "char-is-spriggan")

    T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.LITTLE, "spriggan-little-size-penalty")
    T.true_(util.contains(BRC.LITTLE_RACES,     race), "spriggan-in-little-races")

    T.false_(util.contains(BRC.POIS_RES_RACES,  race), "spriggan-not-pois-res")
    T.false_(util.contains(BRC.UNDEAD_RACES,    race), "spriggan-not-undead")
    T.false_(util.contains(BRC.NONLIVING_RACES, race), "spriggan-not-nonliving")
    T.false_(util.contains(BRC.SMALL_RACES,     race), "spriggan-not-small")
    T.false_(util.contains(BRC.LARGE_RACES,     race), "spriggan-not-large")

    T.pass("dynamic-options-race-spriggan")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_dynamic_options_race_spriggan
```

Expected: `[PASS] dynamic-options-race-spriggan` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_dynamic_options_race_spriggan.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: spriggan LITTLE size, absent from other race tables (Tier 2)"
```

---

### Task 9: Kobold Berserker shortsword — SMALL size

**Files:**
- Create: `tests/test_dynamic_options_race_kobold.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Ko
-- @background Be
-- @weapon shortsword
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Kobold race table classification)
-- Kobold is SMALL (SIZE_PENALTY.SMALL). Not LITTLE or LARGE.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_kobold = {}
test_dynamic_options_race_kobold.BRC_FEATURE_NAME = "test-dynamic-options-race-kobold"

function test_dynamic_options_race_kobold.ready()
  if T._done then return end

  T.run("dynamic-options-race-kobold", function()
    local race = you.race()
    T.eq(race, "Kobold", "char-is-kobold")

    T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.SMALL, "kobold-small-size-penalty")
    T.true_(util.contains(BRC.SMALL_RACES,   race), "kobold-in-small-races")

    T.false_(util.contains(BRC.LITTLE_RACES, race), "kobold-not-little")
    T.false_(util.contains(BRC.LARGE_RACES,  race), "kobold-not-large")
    T.false_(util.contains(BRC.UNDEAD_RACES, race), "kobold-not-undead")

    T.pass("dynamic-options-race-kobold")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_dynamic_options_race_kobold
```

Expected: `[PASS] dynamic-options-race-kobold` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_dynamic_options_race_kobold.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: kobold SMALL size (Tier 2)"
```

---

## Chunk 3: Tier 3 Tests

### Task 10: Poltergeist Berserker mace — mutation_immune + 6 aux slots

**Files:**
- Create: `tests/test_dynamic_options_race_poltergeist.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Po
-- @background Be
-- @weapon mace
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Poltergeist race table classification + 6 aux slots)
-- Poltergeist is in UNDEAD_RACES and POIS_RES_RACES.
-- mutation_immune() and miasma_immune() both return true.
-- As a ghost, Poltergeist has 6 aux equipment slots (num_eq_slots for aux armour returns 6).
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_poltergeist = {}
test_dynamic_options_race_poltergeist.BRC_FEATURE_NAME = "test-dynamic-options-race-poltergeist"

function test_dynamic_options_race_poltergeist.ready()
  if T._done then return end

  T.run("dynamic-options-race-poltergeist", function()
    local race = you.race()
    T.eq(race, "Poltergeist", "char-is-poltergeist")

    T.true_(util.contains(BRC.UNDEAD_RACES,    race), "poltergeist-undead")
    T.true_(util.contains(BRC.POIS_RES_RACES,  race), "poltergeist-pois-res")
    T.false_(util.contains(BRC.NONLIVING_RACES, race), "poltergeist-not-nonliving")

    T.true_(BRC.you.mutation_immune(), "poltergeist-mutation-immune")
    T.true_(BRC.you.miasma_immune(), "poltergeist-miasma-immune")

    T.true_(BRC.eq.is_useless_ego("holy"),  "poltergeist-holy-useless")
    T.true_(BRC.eq.is_useless_ego("rPois"), "poltergeist-rpois-useless")

    -- Give a helmet (aux armour); leave on floor; verify num_eq_slots returns 6
    T.wizard_give("helmet")
    T.wizard_identify_all()
    local floor_helmet = nil
    for _, it in ipairs(you.floor_items()) do
      if it.is_armour and it.name():find("helmet") then
        floor_helmet = it
        break
      end
    end
    T.true_(floor_helmet ~= nil, "helmet-on-floor")
    if floor_helmet then
      T.eq(BRC.you.num_eq_slots(floor_helmet), 6, "poltergeist-6-aux-slots")
    end

    T.pass("dynamic-options-race-poltergeist")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_dynamic_options_race_poltergeist
```

Expected: `[PASS] dynamic-options-race-poltergeist` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_dynamic_options_race_poltergeist.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: poltergeist UNDEAD + mutation_immune + 6 aux slots (Tier 3)"
```

---

### Task 11: Revenant Gladiator quarterstaff — UNDEAD + POIS_RES, not NONLIVING

**Files:**
- Create: `tests/test_dynamic_options_race_revenant.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Re
-- @background Gl
-- @weapon quarterstaff
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Revenant race table classification)
-- Revenant is in UNDEAD_RACES and POIS_RES_RACES. Not in NONLIVING_RACES.
-- Both holy and rPois egos are useless for Revenant.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_revenant = {}
test_dynamic_options_race_revenant.BRC_FEATURE_NAME = "test-dynamic-options-race-revenant"

function test_dynamic_options_race_revenant.ready()
  if T._done then return end

  T.run("dynamic-options-race-revenant", function()
    local race = you.race()
    T.eq(race, "Revenant", "char-is-revenant")

    T.true_(util.contains(BRC.UNDEAD_RACES,     race), "revenant-undead")
    T.true_(util.contains(BRC.POIS_RES_RACES,   race), "revenant-pois-res")
    T.false_(util.contains(BRC.NONLIVING_RACES, race), "revenant-not-nonliving")

    T.true_(BRC.eq.is_useless_ego("holy"),  "revenant-holy-useless")
    T.true_(BRC.eq.is_useless_ego("rPois"), "revenant-rpois-useless")

    T.pass("dynamic-options-race-revenant")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_dynamic_options_race_revenant
```

Expected: `[PASS] dynamic-options-race-revenant` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_dynamic_options_race_revenant.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: revenant UNDEAD+POIS_RES, not NONLIVING (Tier 3)"
```

---

### Task 12: Demonspawn Berserker handaxe — in BRC.UNDEAD_RACES (BRC-specific)

**Files:**
- Create: `tests/test_dynamic_options_race_demonspawn.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Ds
-- @background Be
-- @weapon handaxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: dynamic-options (Demonspawn BRC.UNDEAD_RACES membership)
-- Demonspawn is in BRC.UNDEAD_RACES by intentional BRC design even though it is US_ALIVE
-- in DCSS. This makes holy ego useless for Demonspawn in BRC.
-- Demonspawn is NOT in NONLIVING_RACES or POIS_RES_RACES.
---------------------------------------------------------------------------------------------------

test_dynamic_options_race_demonspawn = {}
test_dynamic_options_race_demonspawn.BRC_FEATURE_NAME = "test-dynamic-options-race-demonspawn"

function test_dynamic_options_race_demonspawn.ready()
  if T._done then return end

  T.run("dynamic-options-race-demonspawn", function()
    local race = you.race()
    T.eq(race, "Demonspawn", "char-is-demonspawn")

    -- BRC-specific: Demonspawn is in BRC.UNDEAD_RACES even though US_ALIVE in DCSS
    T.true_(util.contains(BRC.UNDEAD_RACES, race), "demonspawn-in-brc-undead-races")
    T.true_(BRC.eq.is_useless_ego("holy"), "demonspawn-holy-useless")

    T.false_(util.contains(BRC.NONLIVING_RACES, race), "demonspawn-not-nonliving")
    T.false_(util.contains(BRC.POIS_RES_RACES,  race), "demonspawn-not-pois-res")
    T.false_(BRC.eq.is_useless_ego("rPois"), "rpois-not-useless-for-demonspawn")

    T.pass("dynamic-options-race-demonspawn")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_dynamic_options_race_demonspawn
```

Expected: `[PASS] dynamic-options-race-demonspawn` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_dynamic_options_race_demonspawn.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: demonspawn in BRC.UNDEAD_RACES (BRC-specific, Tier 3)"
```

---

### Task 13: Coglin Fighter flail — 2 weapon slots via num_eq_slots

**Files:**
- Create: `tests/test_pickup_alert_coglin_dual_weapon.lua`

- [ ] **Step 1: Write the test file**

```lua
-- @species Co
-- @background Fi
-- @weapon flail
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Coglin 2 weapon equipment slots)
-- Verifies BRC.you.num_eq_slots() returns 2 for weapons for Coglin (you.lua:84 branch).
-- Coglin can dual-wield, so a weapon occupies 2 slots (main + offhand).
-- Non-weapon items (helmet) still return 1 for Coglin.
---------------------------------------------------------------------------------------------------

test_pickup_alert_coglin_dual_weapon = {}
test_pickup_alert_coglin_dual_weapon.BRC_FEATURE_NAME = "test-pickup-alert-coglin-dual-weapon"

function test_pickup_alert_coglin_dual_weapon.ready()
  if T._done then return end

  T.run("pickup-alert-coglin-dual-weapon", function()
    T.eq(you.race(), "Coglin", "char-is-coglin")

    -- Give a hand axe; leave on floor
    T.wizard_give("hand axe")
    T.wizard_identify_all()

    local floor_axe = nil
    for _, it in ipairs(you.floor_items()) do
      if it.is_weapon and it.name():find("hand axe") then
        floor_axe = it
        break
      end
    end
    T.true_(floor_axe ~= nil, "hand-axe-on-floor")
    if floor_axe then
      T.eq(BRC.you.num_eq_slots(floor_axe), 2, "coglin-weapon-2-slots")
    end

    -- Give a helmet; leave on floor; non-weapon slots unaffected
    T.wizard_give("helmet")
    T.wizard_identify_all()

    local floor_helmet = nil
    for _, it in ipairs(you.floor_items()) do
      if it.is_armour and it.name():find("helmet") then
        floor_helmet = it
        break
      end
    end
    T.true_(floor_helmet ~= nil, "helmet-on-floor")
    if floor_helmet then
      T.eq(BRC.you.num_eq_slots(floor_helmet), 1, "coglin-non-weapon-slots-unaffected")
    end

    T.pass("pickup-alert-coglin-dual-weapon")
    T.done()
  end)
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh test_pickup_alert_coglin_dual_weapon
```

Expected: `[PASS] pickup-alert-coglin-dual-weapon` and `Results: 1/1 passed`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc add tests/test_pickup_alert_coglin_dual_weapon.lua
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc commit -m "test: coglin dual-weapon 2-slot num_eq_slots (Tier 3)"
```

---

### Task 14: Full suite regression check

- [ ] **Step 1: Run the full test suite**

```bash
cd /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc/tests && bash run.sh
```

Expected: all tests pass — `Results: 106/106 passed` (94 existing + 12 new), `OK`.

- [ ] **Step 2: Commit if clean (or investigate any failures)**

If all pass:
```bash
git -C /Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc log --oneline -15
```

Confirm 13 new commits appear (1 run.sh + 12 tests; this task has no commit of its own).
