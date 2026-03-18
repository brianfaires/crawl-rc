# Upcoming Work

**Status:** 129/129 tests passing as of 2026-03-17. Species/class test coverage sprint complete.

---

## Up Next

- [ ] Implement `T.wizard_set_xl` — wraps wizard `l` subcommand (`wizard_set_xl()` at wiz-you.cc:870). v2 stub already in harness.
- [ ] Implement `T.wizard_teleport` — v2 stub already in harness.
- [ ] Test `alert-monsters.lua` — complex species/equipment/will/resist logic, high-risk, currently untested.
- [ ] Test `dynamic-options.lua` at XL thresholds.
- [ ] Test `pickup-alert` OTA artefact path.
- [ ] More feature tests: color-inscribe, autopickup, etc.

## Later

- [ ] CI integration — GitHub Actions running `npm test` on push.
- [ ] v0.35 compatibility audit — verify all features work with 0.35-a0.

## Ideas

- Property-based tests: random seeds, verify no Lua errors over N turns.
- Luacheck integration in tests (already in pre-commit; add to `npm test`?).
