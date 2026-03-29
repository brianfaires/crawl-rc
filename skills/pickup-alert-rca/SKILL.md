---
name: pickup-alert-rca
description: >-
  Root-cause analysis for alerts from the Buehler RC (BRC) pickup-alert feature. Traces alert strings to
  lua/features/pickup-alert, explains config and game-state factors, and may ask clarifying questions
  (config, species, XL). Use when the user questions any pickup-alert message, wants RCA for pickup-alert,
  or debugs confusing BRC floor alerts. Agents executing this skill should append durable new findings
  to this file under "Evolving notes."
---

# BRC pickup-alert RCA

## Scope

Applies to **any** alert emitted through the **pickup-alert** feature—not only weapons. Route investigation by item class and alert text:

| Area | Primary code | Notes |
|------|----------------|------|
| Weapons | `lua/features/pickup-alert/pa-weapons.lua` | DPS/score, ego, early, first-of-skill, high-score |
| Body / aux armour, shields | `lua/features/pickup-alert/pa-armour.lua` | AC/EV/SH, encumbrance, `armour_sensitivity`, ego |
| Orbs, OTA, staves, talismans, rings | `lua/features/pickup-alert/pa-misc.lua` | Config gates in `f_pickup_alert.Config.Alert` |
| Shared: message text, colors, autopickup hook | `lua/features/pickup-alert/pa-main.lua` (`do_alert`) | |
| Persistence, “already alerted”, high scores | `lua/features/pickup-alert/pa-data.lua` | |
| Defaults | `lua/features/pickup-alert/pa-config.lua` | Overridden by `lua/config/*.lua` |

Rebuild bundled RC after Lua edits: `python3 build/concat_rc.py` (see project `CLAUDE.md`).

## Clarifying questions (ask when relevant)

If context is missing and it would change the analysis, ask briefly—examples:

- **Which BRC config are you using?** (e.g. `BRC_CONFIG_NAME` / `custom.lua` / `realtime.lua` / other preset)
- **Species / background?** (race affects skills, body size, slots; some logic is species-aware)
- **XL and rough skill focus?** (early-weapon cutoffs, `top_wpn_skill`, shield use)
- **Exact alert line** (copy-paste) and **whether the item was on floor vs inventory**
- **Inscriptions** on compared items (`!u`, `!brc` exclude weapons from upgrade comparison loop)

Do not block RCA on these if the code path is clear from the message alone.

## Investigation order (general)

1. **Parse the alert** — Note the label (e.g. `DPS increase`, `Early armour`, `Found first`). Leading **`+N` on an item name** is usually **enchant** in the game name, not a computed stat delta. Formatting is built in `do_alert` (`pa-main.lua`) plus `get_keyname` / item stats.
2. **Find the branch** — Grep the alert string in `lua/features/pickup-alert/` or follow from `alert_armour` / `alert_weapon` / `alert_*` in `pa-main.lua` / `pa-misc.lua`.
3. **Config** — Read `f_pickup_alert.Config` merges: base `pa-config.lua`, then active preset in `lua/config/`. Sensitivities (`weapon_sensitivity`, `armour_sensitivity`) and disabled sub-features change behavior a lot.
4. **Explain** — Code path + thresholds + misleading wording + config levers.

---

## Weapons (detailed)

Use when the alert is weapon-related or the user pasted weapon stats.

### Weapon pipeline

`get_weapon_alert` → `get_inventory_upgrade_alert` → `get_upgrade_alert` → `check_upgrade_same_subtype` **or** cross-subtype ratio → `check_upgrade_no_hand_loss` (and related). File: `pa-weapons.lua`.

### Same subtype vs different subtype

Compare floor vs inventory with `cur.subtype() == it.subtype()`.

| Case | Function | Rough idea |
|------|----------|------------|
| Same subtype | `check_upgrade_same_subtype` | `weapon_sensitivity` acts as a **divisor** on the bar (`get_score` / DPS vs `best_*`). |
| Different subtype, same broad category | Cross-subtype in `get_upgrade_alert` | `ratio = penalty * get_score(it) / best_score * weapon_sensitivity`; `penalty` uses `BRC.you.top_wpn_skill` (`lua/util/you.lua`). |

**Common confusion:** cross-subtype melee can satisfy `ratio > pure_dps` while **listed DPS is lower**—**"DPS increase"** comes from `check_upgrade_no_hand_loss` when `ratio > W.Alert.pure_dps`, not from a literal “higher DPS” label check.

### Score vs DPS

`get_score` includes an accuracy term (`dps + acc * Tuning.Weap.Pickup.accuracy_weight`), not raw DPS alone.

### Config (weapons)

- **`weapon_sensitivity`**: in cross-subtype path it **multiplies** `ratio` (values **> 1** make alerts easier; floor can be worse in DPS and still fire).
- **`weapons_pure_upgrades_only`**, **`pure_dps`**, **`gain_ego`**, **`new_ego`**: see `pa-weapons.lua` + `pa-config.lua`.
- **`allow_upgrade`**: `!u` / `!brc` on a weapon skips it in the per-inventory loop but `max_dps` may still include it—read loop + `max_dps` together.

### Example (cross-subtype + sensitivity)

If `penalty ≈ 1` and `weapon_sensitivity = 1.2`, firing needs roughly `get_score(floor)/best_score > 1/1.2 ≈ 0.833`. ~87% of best score can alert despite lower inscribed DPS.

---

## Armour / misc

Summarize from code: `pa-armour.lua` (body armour, aux, shields; `armour_sensitivity`, encumbrance tuning), `pa-misc.lua` (orbs, OTA, staves, talismans). Grep the user’s exact alert phrase or `make_alert` / `do_alert` call path.

---

## Evolving notes (maintain this skill)

When RCA surfaces **durable** knowledge (a recurring gotcha, a new config interaction, a doc/API caveat), **add a concise bullet or short paragraph here** so the next agent does not rediscover it. Prefer:

- One line per fact; link file/function if helpful.
- No transient bug IDs or one-off saves—only patterns that help future pickup-alert RCA.

_Examples of what belongs here: misleading alert labels, species-specific branches, version-sensitive API behavior._

Canonical path in this repo: `skills/pickup-alert-rca/SKILL.md`.

<!-- Append new bullets above this comment or in a dated subsection below. -->
