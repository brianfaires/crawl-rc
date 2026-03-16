# Species/Class Test Coverage — Design Spec

**Date:** 2026-03-15
**Branch:** integration-testing
**Status:** Approved for implementation

---

## Goal

Expand the BRC test suite (currently 94 tests, all Mummy Berserker) to cover a wide range
of DCSS species and backgrounds. Two objectives:

1. **Infrastructure:** give each test file the ability to declare its own species, background,
   and starting weapon, so the test runner launches crawl with the right character.
2. **Coverage:** add targeted tests for the BRC features that contain species-specific logic,
   prioritised by risk/complexity, with enough variety to surface real bugs.

---

## Infrastructure: per-test character override

### Mechanism (Approach A — verified working)

Each test file may declare overrides at the top using header comments:

```lua
-- @species Gn
-- @background Be
-- @weapon falchion
```

All three fields are optional. Fields not declared fall back to the defaults in `config.sh`
(currently `Mu`, `Be`, `weapon=mace`).

**Multi-word weapons:** Always write weapon names without spaces — crawl's `str_to_weapon`
strips whitespace before matching, so `handaxe` resolves to `hand axe`, `shortsword` to
`short sword`, `waraxe` to `war axe`, `longsword` to `long sword`. This avoids shell
word-splitting in `CRAWL_FLAGS`.

`run.sh` extracts overrides per-test with:

```bash
SPECIES_OVERRIDE=$(grep -m1 "^-- @species "    "$TEST_FILE" | sed 's/^-- @species //')
BG_OVERRIDE=$(grep -m1     "^-- @background " "$TEST_FILE" | sed 's/^-- @background //')
WEAPON_OVERRIDE=$(grep -m1 "^-- @weapon "     "$TEST_FILE" | sed 's/^-- @weapon //')
```

Then substitutes into `CRAWL_FLAGS` and replaces `$CRAWL_FLAGS` with `$TEST_FLAGS` in the
crawl launch command:

```bash
TEST_FLAGS="$CRAWL_FLAGS"
[[ -n "$SPECIES_OVERRIDE" ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/-species [^ ]*/-species $SPECIES_OVERRIDE/")
[[ -n "$BG_OVERRIDE"      ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/-background [^ ]*/-background $BG_OVERRIDE/")
[[ -n "$WEAPON_OVERRIDE"  ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/weapon=[^ ]*/weapon=$WEAPON_OVERRIDE/")

# Launch line (replace $CRAWL_FLAGS with $TEST_FLAGS at run.sh line 108):
$TIMEOUT_CMD "${TIMEOUT_SEC}" \
  "${FAKE_PTY_BIN_RESOLVED}" "${CRAWL_BIN_RESOLVED}" $TEST_FLAGS -rc "${TEMP_RC}" \
  > "${TMPDIR_BRC}/${TEST_NAME}.stdout" 2> "${STDERR_LOG}"
```

No change to `config.sh`. Tests without override headers get `TEST_FLAGS == CRAWL_FLAGS`.

### Verified constraints (from DCSS source + live binary runs)

**Species codes** (2-letter, passed to `-species`):
`Mu`, `Gn`, `Op`, `Gr`, `Fo`, `Na`, `Dj`, `Sp`, `Ko`, `Po`, `Re`, `Ds`, `Co`, `At`, `On`, `Hu`, `MD`, …

**Background codes** (2-letter, passed to `-background`):
`Be`, `Fi`, `Mo`, `Gl`, `Wn`, `HW`, `AE`, `Ne`, `CK`, …

**Weapon names** — all confirmed against the live binary:
- Berserker/Monk `weapon_choice::plain`: `mace`, `handaxe`, `spear`, `falchion`, `shortsword`, `unarmed`
  - `quarterstaff` is **banned** for Berserker (causes headless hang)
- Fighter/Gladiator `weapon_choice::good`: `flail`, `waraxe`, `trident`, `longsword`, `rapier`, `quarterstaff`
  - `mace` is **not** in Fighter's good list (causes headless hang)
- No-choice backgrounds (AE, HW, Ne, Wn, …): omit `-- @weapon` entirely

**Background bans:**
- Berserker is banned only for Demigod (MUT_FORLORN). All other target species can be Berserker
  including all US_UNDEAD species (Mummy, Poltergeist, Revenant, Demonspawn) — confirmed live.
- Shapeshifter is banned for all US_UNDEAD species.

**Special cases:**
- **Djinni:** `mmp = 0` — `get_real_mp()` returns 0 for MUT_HP_CASTING. Confirmed live.
- **Formicid:** permanent stasis but Formicid Berserker is valid character creation.

**All Tier 1–3 combos verified against the live binary (0.35-a0).**

---

## Implementation conventions

These patterns come from reading existing tests; new tests must follow them.

**Item retrieval:** `T.wizard_give("item spec")` places items on the floor. Retrieve them
via `you.floor_items()` in the same `ready()` call or the next turn. Do not use
`items.inventory()` unless the item was explicitly picked up with `CMD_PICKUP`.

**Calling alert functions directly:** Tests call `f_pa_weapons.alert_weapon(it)` or
`f_pa_misc.is_unneeded_ring(it)` directly rather than triggering autopickup. The return
value is checked with `T.true_` / `T.false_`.

**Suppressing force_more before alert calls:** Always disable relevant `M.*` options
(e.g. `M.weap_ego = false`) before calling alert functions that might fire a force_more
prompt — otherwise the test hangs headlessly. Restore original values after assertions.

**Config manipulation for threshold-independent assertions:** Set ratio thresholds to 0
(always fires) or 999 (never fires) to isolate specific code branches. Restore originals.
See `test_pickup_alert_branded_weapon.lua` for the full pattern.

---

## BRC features with species-specific logic

| Feature | File | Species-specific logic |
|---------|------|------------------------|
| `dynamic-options` | `dynamic-options.lua:95` | UNDEAD_RACES → holy wrath force_more; POIS_RES_RACES → skip curare force_more; Mountain Dwarf → ignore_magic exception |
| `pickup-alert pa-weapons` | `pa-weapons.lua:61–67,367–384` | Gnoll: bypasses `UPGRADE_SKILL_FACTOR` gate in `is_upgradable_weapon()`; Gnoll: enables cross-skill weapons to reach upgrade comparison in `get_upgrade_alert()` |
| `pickup-alert pa-misc` | `pa-misc.lua:107–108` | Octopode: `is_unneeded_ring()` short-circuits and returns false |
| `inscribe-stats` | `inscribe-stats.lua` | Size penalty affects DPS inscription |
| `startup` | `startup.lua:176,205,210,215` | Gnoll: no skill targets; Wanderer: always show skills menu |
| `exclude-dropped` | `exclude-dropped.lua:36` | Mountain Dwarf: artefact exception |
| `runrest-features` | `runrest-features.lua:79` | Demigod: always feel safe |
| `BRC.you.num_eq_slots` | `you.lua:84–92` | Coglin: 2 weapon slots; Formicid: 2 glove slots; Poltergeist: 6 aux slots |
| `BRC.you.size_penalty` | `you.lua:60–69` | Spriggan: LITTLE (−2); Kobold: SMALL (−1); Naga/Troll/Oni/Armataur: LARGE (+1) |
| `BRC.you.miasma_immune` | `you.lua:41–44` | All UNDEAD_RACES + NONLIVING_RACES |
| `BRC.eq.is_useless_ego` | `equipment.lua:427–429` | `holy` useless for UNDEAD_RACES; `rPois` useless for POIS_RES_RACES |

**Note on BRC race tables:** `BRC.UNDEAD_RACES` is BRC-defined, not a direct mirror of DCSS
`US_UNDEAD`. Demonspawn is in `BRC.UNDEAD_RACES` even though it is US_ALIVE in DCSS —
intentional BRC design. Tests verify BRC table membership, not DCSS undead status.

---

## Test plan

### Tier 1 — Named exceptions (high-risk, untested code paths)

#### `test_pickup_alert_gnoll_falchion.lua`
- `-- @species Gn` / `-- @background Be` / `-- @weapon falchion`
- **What it tests:** Gnoll bypasses `UPGRADE_SKILL_FACTOR` in `is_upgradable_weapon()` (line 65),
  allowing a cross-skill weapon with 0 trained skill to reach `get_upgrade_alert`. Non-Gnoll with
  0 Maces skill would fail `skill(Maces=0) >= 0.5 * skill(LongBlades=3)` and never reach the alert.
- **Phase "give" (turn 0):** `T.wizard_give("mace ego:flaming")`, `T.wizard_identify_all()`,
  `crawl.do_commands({"CMD_WAIT"})` → advance to turn 1
- **Phase "verify" (turn 1):**
  - Retrieve floor mace via `you.floor_items()`
  - Disable force_more: `M.weap_ego = false`, suppress early-weapon XL, inflate high-score
  - Set `W.Alert.gain_ego = 0` so any ratio fires "Gain ego" (makes assertion config-independent)
  - `local result = f_pa_weapons.alert_weapon(floor_mace)`
  - `T.true_(result ~= nil and result ~= false, "gnoll-cross-skill-upgrade-fires")`
  - Restore all config values

#### `test_pickup_alert_octopode_ring.lua`
- `-- @species Op` / `-- @background Be` / `-- @weapon handaxe`
- **What it tests:** `f_pa_misc.is_unneeded_ring()` returns false for Octopode even with 2
  same-type rings in inventory (line 108 short-circuits on `you.race() == "Octopode"`).
- **Phases:** Follow the same multi-phase pattern as `test_pickup_alert_unneeded_ring.lua`:
  - give1 / pickup1 / give2 / pickup2 to put 2 rings of slaying in inventory
  - verify: wizard-give a 3rd ring of slaying; find on floor via `you.floor_items()`
  - `T.false_(f_pa_misc.is_unneeded_ring(floor_ring), "octopode-ring-not-unneeded")`
  - Also verify a non-ring item returns false (sanity check)

#### `test_dynamic_options_race_gargoyle.lua`
- `-- @species Gr` / `-- @background Be` / `-- @weapon mace`
- Gargoyle is NONLIVING (not UNDEAD) and POIS_RES. Exercises the nonliving miasma path
  and the pois_res useless-ego path, without triggering the undead holy-wrath path.
- `T.true_(util.contains(BRC.NONLIVING_RACES, race), "gargoyle-nonliving")`
- `T.true_(util.contains(BRC.POIS_RES_RACES, race), "gargoyle-pois-res")`
- `T.false_(util.contains(BRC.UNDEAD_RACES, race), "gargoyle-not-undead")`
- `T.false_(BRC.eq.is_useless_ego("holy"), "holy-not-useless-for-gargoyle")`
- `T.true_(BRC.eq.is_useless_ego("rPois"), "rpois-useless-for-gargoyle")`

#### `test_pickup_alert_formicid_gloves.lua`
- `-- @species Fo` / `-- @background Fi` / `-- @weapon waraxe`
- Wizard-give a pair of gloves and a helmet. Find both via `you.floor_items()`.
- `T.eq(BRC.you.num_eq_slots(gloves), 2, "formicid-glove-slots")`
- `T.eq(BRC.you.num_eq_slots(helmet), 1, "formicid-helmet-slots")`
- `T.eq(BRC.you.num_eq_slots(weapon), 1, "formicid-weapon-slots-not-coglin")`
  where `weapon` is the starting waraxe from `items.equipped_at("weapon")`

### Tier 2 — Race table membership (medium risk)

#### `test_dynamic_options_race_naga.lua`
- `-- @species Na` / `-- @background Be` / `-- @weapon falchion`
- `T.true_(BRC.eq.is_useless_ego("rPois"), "naga-rpois-useless")`
- `T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.LARGE, "naga-large-size")`
- `T.false_(util.contains(BRC.UNDEAD_RACES, race), "naga-not-undead")`
- `T.false_(util.contains(BRC.NONLIVING_RACES, race), "naga-not-nonliving")`

#### `test_announce_hp_mp_djinni.lua`
- `-- @species Dj` / `-- @background Be` / `-- @weapon handaxe`
- Regression guard: `f_announce_hp_mp` must not crash with mmp=0 (MUT_HP_CASTING).
- `local mp, mmp = you.mp()`
- `T.eq(mp, 0, "djinni-mp-zero")` and `T.eq(mmp, 0, "djinni-mmp-zero")`
- `T.true_(util.contains(BRC.NONLIVING_RACES, race), "djinni-nonliving")`
- `T.true_(util.contains(BRC.POIS_RES_RACES, race), "djinni-pois-res")`
- `T.false_(util.contains(BRC.UNDEAD_RACES, race), "djinni-not-undead")`
- `crawl.do_commands({"CMD_WAIT"})` then `T.pass()` — verifies no crash on first announce turn

#### `test_dynamic_options_race_spriggan.lua`
- `-- @species Sp` / `-- @background Mo` / `-- @weapon unarmed`
- `T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.LITTLE, "spriggan-little-size")`
- Assert Spriggan NOT in POIS_RES_RACES, UNDEAD_RACES, NONLIVING_RACES, SMALL_RACES, LARGE_RACES

#### `test_dynamic_options_race_kobold.lua`
- `-- @species Ko` / `-- @background Be` / `-- @weapon shortsword`
- `T.eq(BRC.you.size_penalty(), BRC.SIZE_PENALTY.SMALL, "kobold-small-size")`
- Assert Kobold NOT in LITTLE_RACES, LARGE_RACES

### Tier 3 — Full table coverage (completeness)

#### `test_dynamic_options_race_poltergeist.lua`
- `-- @species Po` / `-- @background Be` / `-- @weapon mace`
- `T.true_(BRC.you.mutation_immune(), "poltergeist-mutation-immune")`
- `T.true_(BRC.you.miasma_immune(), "poltergeist-miasma-immune")`
- `T.true_(BRC.eq.is_useless_ego("rPois"), "poltergeist-rpois-useless")`
- `T.true_(BRC.eq.is_useless_ego("holy"), "poltergeist-holy-useless")`
- For `num_eq_slots`: `T.wizard_give("helmet")`, then find the helmet via `you.floor_items()`
  (`BRC.it.is_aux_armour` returns true for helmets — armour, not body, not shield).
  `T.eq(BRC.you.num_eq_slots(floor_helmet), 6, "poltergeist-6-aux-slots")`

#### `test_dynamic_options_race_revenant.lua`
- `-- @species Re` / `-- @background Gl` / `-- @weapon quarterstaff`
- `T.true_(util.contains(BRC.UNDEAD_RACES, race), "revenant-undead")`
- `T.true_(util.contains(BRC.POIS_RES_RACES, race), "revenant-pois-res")`
- `T.true_(BRC.eq.is_useless_ego("holy"), "revenant-holy-useless")`
- `T.true_(BRC.eq.is_useless_ego("rPois"), "revenant-rpois-useless")`
- `T.false_(util.contains(BRC.NONLIVING_RACES, race), "revenant-not-nonliving")`

#### `test_dynamic_options_race_demonspawn.lua`
- `-- @species Ds` / `-- @background Be` / `-- @weapon handaxe`
- `T.true_(util.contains(BRC.UNDEAD_RACES, race), "demonspawn-in-brc-undead-races")`
  (BRC-specific — Demonspawn is US_ALIVE in DCSS)
- `T.true_(BRC.eq.is_useless_ego("holy"), "demonspawn-holy-useless")`
- `T.false_(util.contains(BRC.NONLIVING_RACES, race), "demonspawn-not-nonliving")`
- `T.false_(util.contains(BRC.POIS_RES_RACES, race), "demonspawn-not-pois-res")`

#### `test_pickup_alert_coglin_dual_weapon.lua`
- `-- @species Co` / `-- @background Fi` / `-- @weapon flail`
- `T.wizard_give("hand axe")`, find on floor via `you.floor_items()`
- `T.eq(BRC.you.num_eq_slots(floor_axe), 2, "coglin-2-weapon-slots")`
- `T.wizard_give("helmet")`, find on floor
- `T.eq(BRC.you.num_eq_slots(floor_helmet), 1, "coglin-non-weapon-slots-unaffected")`

### Future (backlog)

- `test_startup_gnoll_no_skill_targets.lua` — Gnoll skips skill target saving/loading
- `test_dynamic_options_race_mountain_dwarf.lua` — ignore_magic exception
- `test_runrest_features_demigod.lua` — Demigod always feels safe
- `test_exclude_dropped_mountain_dwarf.lua` — artefact exception

---

## run.sh changes

Insert the per-test override block between the `TEMP_RC` build and the crawl launch.
Replace `$CRAWL_FLAGS` with `$TEST_FLAGS` in the launch command (run.sh line 108).

```bash
# --- INSERT after TEMP_RC is built, before the launch ---
SPECIES_OVERRIDE=$(grep -m1 "^-- @species "    "$TEST_FILE" | sed 's/^-- @species //')
BG_OVERRIDE=$(grep -m1     "^-- @background " "$TEST_FILE" | sed 's/^-- @background //')
WEAPON_OVERRIDE=$(grep -m1 "^-- @weapon "     "$TEST_FILE" | sed 's/^-- @weapon //')

TEST_FLAGS="$CRAWL_FLAGS"
[[ -n "$SPECIES_OVERRIDE" ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/-species [^ ]*/-species $SPECIES_OVERRIDE/")
[[ -n "$BG_OVERRIDE"      ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/-background [^ ]*/-background $BG_OVERRIDE/")
[[ -n "$WEAPON_OVERRIDE"  ]] && TEST_FLAGS=$(echo "$TEST_FLAGS" | sed "s/weapon=[^ ]*/weapon=$WEAPON_OVERRIDE/")

# --- CHANGE line 108: $CRAWL_FLAGS -> $TEST_FLAGS ---
$TIMEOUT_CMD "${TIMEOUT_SEC}" \
  "${FAKE_PTY_BIN_RESOLVED}" "${CRAWL_BIN_RESOLVED}" $TEST_FLAGS -rc "${TEMP_RC}" \
  > "${TMPDIR_BRC}/${TEST_NAME}.stdout" 2> "${STDERR_LOG}"
```

---

## Success criteria

1. All existing 94 tests continue to pass (no regression from run.sh change).
2. Each new test passes with a meaningful assertion — not a smoke test that the character loads.
3. At least one new test exposes a real difference in BRC behaviour between species.
4. Background and weapon are varied across new tests — no two Tier 1/2 tests share the same
   `(background, weapon)` pair unless required by the scenario.
