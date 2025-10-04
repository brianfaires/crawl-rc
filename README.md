# crawl-rc
Settings files for use in [Dungeon Crawl Stone Soup](https://github.com/crawl/crawl) v0.33.1

## What is BRC?
BRC (buehler.rc) is a modular system for DCSS RC files, designed to be easily customizable and extensible. Features are defined as standalone modules, and the BRC core system handles crawl hooks, data persistence, etc.

## Quick Start
Consider simply adding `bin/buehler.rc` to your current RC file. If there are any features you don't like, just delete the module or configure it to your tastes in `BRC.Config`.

To add BRC piece-by-piece:
1. Copy `bin/core.rc` into your RC file.
1. Copy any feature modules from `lua/features/` into your RC file.
    - Wrap the copied lua code in `{` curly braces `}`.
1. Connect BRC to crawl's hooks (See "Lua Hook Functions" at the end of `rc/init.txt`)
    - In each crawl hook function, add `BRC.hook_name()`.
1. Add `BRC.init()` to the end of your RC file.

### How Features Work
See `features/_template.lua` for an example.
- Any global table containing `BRC_FEATURE_NAME` will be automatically loaded as a feature module.
- Each module's `init()` function is called when the game starts.
  (This has better error handling than just writing top-level lua code).
- Defining any of these functions in a feature module will automatically hook to crawl:
  - `ready()`
  - `autopickup(item, name)`
  - `c_answer_prompt(prompt)`
  - `c_assign_invletter(item)`
  - `c_message(text, channel)`

- `<var_name> = BRC.data.persist("<var_name>", <initial_value>)` creates vars/tables that persist across game saves.

### Modify Features
- **Add new**: Define a feature module anywhere in your RC file.
  - Or, add a file to `lua/features/`, add `lua_file = <file_name>` in `rc/init.txt`, and rebuild.
- **Remove completely**: Delete the feature module, or just comment out `BRC_FEATURE_NAME`.
  - Or, comment out the `lua_file = <file_name>` line in `rc/init.txt` and rebuild.
- **Configure**: Most features have settings in `lua/core/config.lua`, at the top of `buehler.rc`.
  - Some features with large config sections include the config with the feature module code.

## Feature Modules

### Exploration & Travel
- **`after-shaft.lua`** - Stops travel on stairs after being shafted until returning to original level
- **`fully-recover.lua`** - Rests until temporary negative statuses are removed
- **`runrest-features.lua`** - Smart exploration behavior (ignores altars when you have a god, stops on Pan gates, etc.)
- **`safe-stairs.lua`** - Prevents accidental stair usage and warns before entering Vaults:5

### Item Management
- **`color-inscribe.lua`** - Adds color to item inscriptions for resistances and stat modifiers
- **`drop-inferior.lua`** - Marks items with `~~DROP_ME` when you pick up better versions, adding them to the drop list.
  (disabled for equipment with multiple slots of the same type, like Poltergeist armour or Coglin weapon)
- **`exclude-dropped.lua`** - Disables autopickup for items you drop (resumes if picked back up)
- **`inscribe-stats.lua`** - Auto-inscribes weapon DPS and armour AC/EV stats on items
- **`safe-consumables.lua`** - Maintains `!r` and `!q` inscriptions on consumables
- **`weapon-slots.lua`** - Keeps weapons in slots a/b/w automatically

### Alerts & Notifications
- **`alert-monsters.lua`** - Dynamic force_more prompts for dangerous monsters based on your HP, resistances, will, etc
- **`announce-hp-mp.lua`** - Visual HP/MP meters and damage announcements
- **`misc-alerts.lua`** - Low HP warnings, piety reminders, spell level changes
- **`remind-id.lua`** - Stops travel and sends reminder when you can identify an item

### Quality of Life
- **`answer-prompts.lua`** - Auto-answers common prompts (refuses death, shopping list)
- **`dynamic-options.lua`** - Adjusts game options based on xl, god, class, etc.
- **`startup.lua`** - Opens skills menu and sets initial skill targets on new games

## Intelligent Pickup & Alert System

The pickup-alert system provides smart autopickup that grabs items you definitely want,
  and generates alerts for noteworthy items you might want to consider.
  The goal of this feature is to allow confident o-tabbing without inspecting every dropped item,
  or searching the entire floor to check for overlooked items.

### How It Works
- **Alerts** are one-line messages that stop travel and stand out visually
- **No spam** - alerts won't fire for identical/inferior items after you've seen them
- **Smart** - adjusts behavior to your inventory and character progression
- **Configurable** - lots of config values for which alerts are active, when they fire, and which trigger a force_more.
  (Advanced: See `f_pickup_alert.Config.Tuning` to adjust heuristics that define when alerts fire.
  These can be used to adjust the frequency of different alerts to your preferences.)

### Pickup Categories
- **`pa-armour.lua`** - Picks up armour upgrades, alerts for new egos, or anything with a plausible tradeoff of AC/encumbrance/ego
- **`pa-weapons.lua`** - Checks every weapon in inventory for upgrades/alerts. **ignores any weapon inscribed with `!u` or `!brc`.**
  i.e. inscribe `!u` if you want to carry a weapon but don't want upgrades. (This is because pickup is based on current damage.
  You may want to carry a +0 broad axe, but not pick up every enchanted war axe you find.)
  Alerts fire for artefacts, new egos, strong early weapons, first ranged/polearm, highest flat damage, ...
- **`pa-misc.lua`** - Picks up relevant staves. Alerts fire for orbs, relevant talismans, and a list of
  "one-time alerts" that fire the first time you encounter a specific item (e.g. Broad axe, or Wand of Digging)

### Core Files
- **`pa-main.lua`** - Main controller and autopickup function
- **`pa-data.lua`** - Persistent data storage per character

## Core System Files

### `lua/core/config.lua`
Main configuration file with all user settings:
- **BRC.Config** - Feature toggles and basic settings
- **BRC.Tuning** - Pickup/alert system heuristics (adjust if too many/few alerts)
- **BRC.BrandBonus** - Weapon brand damage calculations
- **BRC.AlertColor** - Alert text colors
- **BRC.Emoji** - Emojis or text substitutes for alerts

### `lua/core/brc.lua`
Core system coordinator that:
- Auto-loads any table containing `BRC_FEATURE_NAME`. (Searches global environment by default.)
- Manages feature lifecycle and hook dispatching
- Handles error recovery and feature deactivation

### `lua/core/data.lua`
Tools for easy data persistence across saves (per-character):
- Saves/loads data between game sessions
- Warns if data fails to load (usually from crashes or breaking RC changes)

### `lua/core/util.lua`
Common utility functions organized into modules:
- **BRC.log** / **BRC.mpr** - Useful wrappers for crawl.mpr()
- **BRC.text** - Text manipulation and color formatting
- **BRC.get** - Data retrieval functions (skills, mutations, equipment info)
- **BRC.is** - Boolean type checks for items (weapons, armour, jewelry, etc.)
- **BRC.you** - Character state checks (mutations, resistances, location)
- **BRC.set** - Game option setters (macros, autopickup, explore settings)
- **BRC.util** - General utilities (command execution, etc.)
- **BRC.dump** - Debugging and data export functions 

### `lua/core/constants.lua`
A bunch of constants and lists, many of which should be kept up-to-date when crawl changes roll out.

## Usage Tips

### Important Notes
- Report bugs with a character dump (`#` key by default). By default, this will write BRC debugging info to the char dump.
- Never put `}` on a line by itself in lua code - this breaks crawl's RC parser.
  (Adding a comment after `}` prevents the parser confusion)

### In-game lua commands
- Use `~` to open the Lua interpreter in-game
- `BRC.data.erase()` - Reset all persistent data
- `BRC.dump.all()` or verbose: `BRC.dump.all(1)` - Prints debugging info of the curent BRC state
- `BRC.active = false` - Disable BRC system
- `BRC.Config.<setting> = <value>` - Change settings mid-game
- `BRC.unregister_feature(<feature_name>)` - Turn off a feature

### If building crawl locally
I've run into some weird behavior+workarounds on my local MacOS crawl build. (These don't apply to webtiles.)
- **Emojis**: Webtiles has a good font with solid emoji support. AFAICT MacOS doesn't.
  Define your font in `rc/display.rc`, or edit/remove emojis in `core/config.lua`.
- **Character switching**: When switching between games, the RC reloads without unloading the previous one.
  Things get duplicated, including crawl's own autopickup functions.
  BRC checks for this and warns you to close and reopen crawl. It appears to be harmless but I usually restart anyway.
- **Stats not displaying on startup**: Sometimes happens, I think it's from inscribing a wielded weapon.
  Open/close inventory to refresh screen.
- **Regex issues**: Some regular expression patterns require PCRE (not POSIX) - build with `BUILD_PCRE=y`.


## Resources

### DCSS Documentation
- [RC Options Guide](http://crawl.akrasiac.org/docs/options_guide.txt)
- [Lua Integration Guide](https://github.com/gammafunk/dcss-rc#1-include-the-rc-or-lua-file-in-your-rc)
- [DCSS Lua API](https://doc.dcss.io/index.html)

### References and cool RC files
- Use this syntax to lookup a player's RC file:
  [http://crawl.akrasiac.org/rcfiles/crawl-0.33/buehler.rc](http://crawl.akrasiac.org/rcfiles/crawl-0.33/buehler.rc)  
- [gammafunk/dcss-rc](https://github.com/gammafunk/dcss-rc)
- [magus/dcss](https://github.com/magus/dcss)
- [linewriter1024/crawl-rc](https://github.com/linewriter1024/crawl-rc)
- [Other RC Examples](https://tavern.dcss.io/t/whats-in-your-rc-file/160/4)
