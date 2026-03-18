# crawl-rc

## Environment

- Working dir: `/Users/brian/dev/dcss/crawl/crawl-ref/settings/crawl-rc`
- Crawl binary: `crawl-ref/source/crawl-console` (v0.35-a0)
- fake_pty: `crawl-ref/source/util/fake_pty`
- Test command: `npm test` (or `./tests/run.sh`)
- Test character: Mummy Berserker, seed 1, -no-save, -wizard
- Tests run automatically on `git push` via pre-push hook

## Key Facts

- Shapeshifter background code is `Sh` (replaced `Tm` = Transmuter in 0.35-a0)
- `weapon_choice::none` — default `weapon=mace` option is silently ignored
- Hook order is reverse-alpha by Lua VARIABLE NAME (not BRC_FEATURE_NAME)
- `BRC.eq.get_ego()` returns short form: `"freeze"` not `"freezing"`, `"flame"` not `"flaming"`
- `weapon_sensitivity=0.5` in Testing config — restore to 1.0 for ratio-threshold tests
- `weapons_pure_upgrades_only=true` short-circuits upgrade path — disable for cross-subtype tests
- Wizard `y` subcommand = `wizard_identify_all_items()` (wizard.cc:172)
- Wizard `%` subcommand = `wizard_create_spec_object_by_name()` (reads name from macro_buf)
- Wizard `l` subcommand = `wizard_set_xl()` (wiz-you.cc:870) — NOT YET wrapped as `T.wizard_set_xl`
- run.sh only shows stderr on [FAIL]/[ERROR], not on [TIMEOUT] — debug via raw stderr capture
- Mummy Berserker has only 1 MP (mmp=1). MP delta tests: `ad_prev.mp = mp - 3` gives `mp_delta = +3`

## Gotchas

### DCSS RC block-terminator rule
Any line where `}` is the sole non-whitespace character terminates the outer Lua block — not just bare `}` at column 0. Leading spaces (`  }`) also trigger it. Always add an inline comment after table/block closers in test files: `  } -- table name`.

### T.last_messages timing
Do NOT clear `T.last_messages` before `CMD_WAIT` when testing primary meter messages. Clearing before `CMD_WAIT` creates a timing hazard — messages from turn-0 handlers are gone before verify runs. Only safe to clear for secondary messages (e.g. BIG DAMAGE) queued AFTER the meter.

### force_more suppression for armour egos
When suppressing `force_more` for armour items with egos, must set `M.armour_ego=false`. `has_configured_force_more()` checks `M.armour_ego` last; if true + item has ego, queues with `more=true` even if `M.artefact/M.body_armour/M.aux_armour` are all false. This causes `consume_queue` to call `crawl.more()` which consumes the pending `CMD_WAIT`, preventing the verify phase from running.

### is_useless_ego rPois
`is_useless_ego` must check all three forms: `ego == "rPois" or ego == "rpois" or ego == "poison resistance"`. `get_ego()` lowercases before calling it, and `it.ego(true)` returns the full name.

### alert_low_hp hysteresis
`below_hp_threshold` resets only at full HP (not at "above threshold"). Intentional design.
