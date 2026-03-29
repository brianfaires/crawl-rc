# crawl-rc

## Compatibility

BRC targets multiple DCSS versions simultaneously. When updating game-content lists (species, items, monsters, spells, etc.):

- **Append** new entries to lists rather than replacing old ones
- Only remove entries when they are confirmed unused across ALL supported versions
- Test against both the oldest and newest supported crawl binaries

## Environment

- Working dir: `~/dev/dcss/crawl/crawl-ref/settings/crawl-rc`
- Crawl binary: `crawl-ref/source/crawl-console` (v0.35-a0)
- fake_pty: `crawl-ref/source/util/fake_pty`
- Test command: `npm test` (or `./tests/run.sh`)
- Test character: Mummy Berserker, seed 1, -no-save, -wizard
- Tests run automatically on `git push` via pre-push hook

## Project Layout

- `lua/core/` — BRC core module, constants, utilities
- `lua/features/` — individual BRC features (alert-monsters, pickup-alert, etc.)
- `lua/config/` — user configuration files
- `lua/util/` — shared utility modules
- `tests/` — test suite (run via `tests/run.sh`)

## Key Facts

- Shapeshifter background code is `Sh` (replaced `Tm` = Transmuter in 0.35-a0)
- `weapon_choice::none` — default `weapon=mace` option is silently ignored
- Hook order is reverse-alpha by Lua VARIABLE NAME (not BRC_FEATURE_NAME)
- `BRC.eq.get_ego()` returns short form: `"freeze"` not `"freezing"`, `"flame"` not `"flaming"`
- `weapon_sensitivity=0.5` in Testing config — restore to 1.0 for ratio-threshold tests
- `weapons_pure_upgrades_only=true` short-circuits upgrade path — disable for cross-subtype tests
- Wizard `y` subcommand = `wizard_identify_all_items()` (wizard.cc:172)
- Wizard `%` subcommand = `wizard_create_spec_object_by_name()` (reads name from macro_buf)
- Wizard `l` subcommand = `wizard_set_xl()` (wiz-you.cc:870) — wrapped as `T.wizard_set_xl(level)`
- run.sh only shows stderr on [FAIL]/[ERROR], not on [TIMEOUT] — debug via raw stderr capture
- Mummy Berserker has only 1 MP (mmp=1). MP delta tests: `ad_prev.mp = mp - 3` gives `mp_delta = +3`

## Crawl Source

The upstream crawl repo is at `~/dev/dcss/crawl`. The built binary is at `crawl-ref/source/crawl`.

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

### items.get_items_at vs you.floor_items
`items.get_items_at(x, y)` reads `env.map_knowledge` cache (updated at turn boundaries), NOT live floor data. `you.floor_items()` reads the live item grid. If you `wizard_give` an item and call a function that uses `get_items_at` in the same turn, it won't see the new item. Always add a `CMD_WAIT` between `wizard_give` and any code path that uses `get_items_at` (includes `f_announce_items.ready()`).

### CMD_PICKUP ends the turn
`CMD_PICKUP` is a real turn-ending action. Do NOT follow it with `CMD_WAIT` in the same ready() phase — that causes "Cannot currently process new keys (turn is over)". Set `_phase` before calling `CMD_PICKUP` and let it end the turn naturally.

### Scrolls not autopicked up in tests
The test character does not autopick scrolls. Use `CMD_PICKUP` explicitly if you need a floor scroll in inventory.

### Tests use bin/buehler.rc (bundled), not lua/ source directly
Tests run against `bin/buehler.rc`, which is a compiled bundle of all Lua source files. After modifying any file under `lua/`, you MUST rebuild: `python3 build/concat_rc.py`. Without rebuilding, tests silently run against the OLD bundled code, giving mysterious failures where debug output doesn't appear and changes have no effect. Also rebuild `bin/standalone_features/` with `python3 build/create_standalone_features.py` when modifying feature files.
