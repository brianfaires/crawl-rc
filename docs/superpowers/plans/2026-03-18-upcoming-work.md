# Upcoming Work

**Status:** 135/135 tests passing as of 2026-03-18.

---

## Up Next

- [x] Implement `T.wizard_set_xl` — wraps wizard `l` subcommand (`wizard_set_xl()` at wiz-you.cc:870).
- [x] Test `dynamic-options.lua` at XL thresholds — `test_dynamic_options_xl_thresholds.lua`.
- [x] Test `pickup-alert` OTA paths — weapon fires, armour fires, weapon skill gate, armour skill gate, OTA artefact (5 tests).
- [ ] `T.wizard_teleport` — **blocked**: wizard `b` (blink) and `B` (controlled teleport) both require interactive cursor targeting; cannot pre-queue via `sendkeys`. Stub updated with explanation.
- ~~Test `alert-monsters.lua`~~ — feature will be deprecated; no tests needed.
- [ ] More feature tests: color-inscribe, autopickup, etc.

## Later

- [ ] CI integration — GitHub Actions running `npm test` on push.
- [ ] v0.35 compatibility audit — verify all features work with 0.35-a0.

## Ideas

- Property-based tests: random seeds, verify no Lua errors over N turns.
- Luacheck integration in tests (already in pre-commit; add to `npm test`?).
