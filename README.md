# crawl-rc
Settings files for use in [Dungeon Crawl Stone Soup](https://github.com/crawl/crawl) v0.33.1

## Usage
- All features are enabled and included via [init.txt](init.txt). If you want a single file,
  [buehler.rc](buehler.rc) contains [init.txt](init.txt) and all the files it references.
- To merge with an existing RC file, make sure any Lua hook functions (such as `ready()`) are only defined
  once, at the end of the RC file. If duplicate functions exist, combine them.
- Features can be configured. See [config.lua section](#luaconfiglua) below.
- Features can also be excluded at the file-level.
  - If you have access to python:
    1. In [init.txt](init.txt), comment out `include =` or `lua_file =` statements by adding a `#` at the start of the line.
    1. Run `python concat_rc.py` to regenerate [buehler.rc](buehler.rc) without the features included.
  - Alternatively, just remove everything between the `Begin <filename>` and `<End filename>` markers in [buehler.rc](buehler.rc).
- If you copy-paste individual files into another RC, be sure to include:
  1. The hook functions from [init.txt](init.txt).
  1. Any/all files from the `lua/core/` folder.
- This RC makes heavy use of the character-specific persistent data. These essentially save values when exiting,
  and then reload it when the game starts again. Currently, if the game crashes and the data is not saved, many
  features will 'reset'. To see the values of all persistent data, press '~' to open the lua interpreter, then
  enter: `dump_persistent_data()`

## Standard(-ish) Settings
### [init.txt](init.txt)
- My preferred main, explore, and autopickup options.
- References all other files.
- Importantly, ends with all hook functions (connecting the features to crawl).

### [rc/autoinscribe.rc](rc/autoinscribe.rc)
- Automatically inscribe items, mostly to add warnings to consumables.

### [rc/autopickup.rc](rc/autopickup.rc)
- Basic autopickup settings.

### [rc/display.rc](rc/display.rc)
- Various display related settings, including customized colors for 1000's of messages.
  Some are a bit dated, but a great starting point to build on.
  *(If anyone knows who meticulously hand-wrote all of these, LMK so I can attribute.)*

### [rc/fm-messages.rc](rc/fm-messages.rc)
- Settings for force_more and flash_screen events.
- Lua code block at the end to skip force_more_messages defined in crawl (not configured).

### [rc/macros.rc](rc/macros.rc)
- Numpad has a handful of common actions
- Number keys perform spellcasting, and confirm targeting (so you can double-tap to fire a targeted spell)

### [rc/runrest.rc](rc/runrest.rc)
- Settings for exploration/resting stop messages.

### [rc/slot-defaults.rc](rc/slot-defaults.rc)
- item_slot assignments: Rings on P/p, etc.
- spell_slot assignments for one-click spells on capital letters. 


## Lua files - mostly one per feature
### [lua/features/after-shaft.lua](lua/features/after-shaft.lua)
- Stops travel on stairs until you get back to the level you were shafted from.

### [lua/features/announce-damage.lua](lua/features/announce-damage.lua)
- Writes messages for HP and MP changes.

### [lua/features/color-inscribe.lua](lua/features/color-inscribe.lua)
- Colors item inscriptions for resistances, stat modifiers, etc.

### [lua/features/drop-inferior.lua](lua/features/drop-inferior.lua)
- Marks items with `~~DROP_ME` when you pick up a strictly better one.
  These items are added to the `drop_list`, so press `,` in the drop menu to select them all.

### [lua/features/dynamic-options.lua](lua/features/dynamic-options.lua)
- Any options that change based on XL, God, Class, etc.

### [lua/features/exclude-dropped.lua](lua/features/exclude-dropped.lua)
- Excludes autopickup for items that you drop your entire stack of.
  Resumes when you pick it up again.
- Some special behavior for enchant scrolls.
- (I don't like the behavior of the built-in `drop_disables_autopickup` feature)

### [lua/features/fm-disable.lua](lua/features/fm-disable.lua)
- Disables force_more messages for crawl messages that include them.

### [lua/features/fm-monsters.lua](lua/features/fm-monsters.lua)
*(Needs a v0.33 update)*
- Generates force_more prompts when monsters come into view.
  Includes all uniques and a list of 'always alert' monsters
- Dynamic force_mores that trigger based on: HP, Resistances, XL, Willpower, Int
  *(Roughly configured to fire when a monster can take 50% HP in one hit)*
- Avoids triggering on zombies, skeleton, etc

### [lua/features/fully-recover.lua](lua/features/fully-recover.lua)
- Updates resting to fully recover from temporary negative statuses.
- Can change these statuses in STATUSES_TO_WAIT_OFF

### [lua/features/inscribe-stats.lua](lua/features/inscribe-stats.lua)
- Weapons in inventory are inscribed with their stats and a their ideal DPS (ie max damage per 10 aut, including brand).
- Armour is inscribed with stats relative to what you're wearing.
- Updates in real time with skill/stats/etc.

### [lua/features/misc-alerts.lua](lua/features/misc-alerts.lua)
- Add a warning before entering Vaults:5
- A one-time force-more when dropping below 50% HP (configurable).
- A msg when you hit 6* piety while wearing an amulet of faith

### [lua/features/remind-id.lua](lua/features/remind-id.lua)
- When you pick up a scroll of ID or an unidentified item, it'll stop travel and alert if you can ID something.
- Before finding scroll of ID, stops travel when you get a larger stack of un-ID'd scrolls/pots.

### [lua/features/runrest-features.lua](lua/features/runrest-features.lua)
- No altar stops if you have a god
- Don't stop exploration on portals leading out of baileys/sewers/etc
- Stop travel on gates in Pan
- Auto-search items when entering a gauntlet or temple. Run to temple exit after worship.

### [lua/features/safe-consumables.lua](lua/features/safe-consumables.lua)
- Adds and maintains `!r` and `!q` inscriptions on consumables.

### [lua/features/safe-stairs.lua](lua/features/safe-stairs.lua)
- Protects against fat-fingering `<>` or `><`, by prompting before immediately returning to the previous floor.

### [lua/features/startup.lua](lua/features/startup.lua)
- One-time actions on new games:
  - Open the skills menu
  - Exclusively train the first skill in CONFIG.auto_set_skill_targets below its target

### [lua/features/weapon-slots.lua](lua/features/weapon-slots.lua)
- Keeps weapons in slots a/b/w. Reassignments happen whenever you pickup or drop an item.
  It'll only kick non-weapons out of these slots. Favors putting ranged and polearms in w.

## Pickup and Alert system
Intelligent autopickup based on your character and items in your inventory.
  Tries to only pickup items you *definitely* want, so there is an alert system to flag items that seem noteworthy.

Alerts are one-line messages that stop travel and are formatted to stand out.
To avoid spam, alerts aren't generated for items previously alerted/picked up.

> e.g. If you're alerted to a +1 broad axe as a potential upgrade, no more alerts are generated
> for +1 or +0 broad axes, unless they're branded.

### [lua/pickup-alert/pa-armour.lua](lua/pickup-alert/pa-armour.lua) (Armour)
Picks up armour that is a pure upgrade to what you currently have, or has a new ego.

Alerts are generated for:
- Items with new egos, or added AC
- The highest AC body armour seen so far (only if training armour and through xl 12)
- Heavier/lighter body armour that passes some additional checks. In general, 1 AC is valued ~1.2EV,
  and alerts are generated when it seems like an armour might be an overall improvement.

###  [lua/pickup-alert/pa-weapons.lua](lua/pickup-alert/pa-weapons.lua) (Weapons)
Picking up upgrades is straightforward enough. Alerts are generated for:
- Strong weapons early on, with little regard for what skills are trained
- The first one-handed ranged weapon (and two-handed if not wearing a shield)
- DPS upgrades and new egos, with various heuristics based off brands/handedness/weapon skill
- High scores: items that set a new record for:
  - Overall damage
  - Damage w/o brand
  - If using allies, Strongest polearm/1-handed polearm


### [lua/pickup-alert/pa-misc.lua](lua/pickup-alert/pa-misc.lua) (Misc)
Picks up staves when you are training the relevant spell school. Alerts are generated for:
- The first instance of anything in the `CONFIG.alert.one_time` list.
- First orb of each type
- First talisman of each type
- Staves that provide you a needed resistance

### Other files for pickup-alert system
These are auto-included as necessary. Just listing for reference.
- [lua/pickup-alert/pa-util.lua](lua/pickup-alert/pa-util.lua):
  Like [lua/core/util.lua](lua/core/util.lua) but specific to the pickup-alert system.
- [lua/pickup-alert/pa-data.lua](lua/pickup-alert/pa-data.lua):
  Handles persistent data, saved with your character.
- [lua/pickup-alert/pa-main.lua](lua/pickup-alert/pa-main.lua):
  Controls all the features, and defines/hooks an autopickup function.

## Core files
### [lua/core/config.lua](lua/core/config.lua)
This comes first in [buehler.rc](buehler.rc), so you can toggle features on/off
  without digging into the code or rebuilding [buehler.rc](buehler.rc).
  The toggles should be obvious based on the descriptions above.

### [lua/core/constants.lua](lua/core/constants.lua)
In an attempt to future-proof, contains definitions for things like
  `ALL_WEAP_SCHOOLS` and `ALL_PORTAL_NAMES`. Update as needed.

### [lua/core/util.lua](lua/core/util.lua)
Required a lot of places. Nothing in here is necessarily specific to this repo.

### [lua/core/cache.lua](lua/core/cache.lua)
- Once per turn, the cache pulls several values from the crawl API, that would otherwise be pulled
multiple times per turn.
- This is just for speed and a little code brevity. e.g. You `CACHE.xl` and `you.xl()` are interchangeable.
- It *is* important that CACHE be updated via `ready_cache()` as the first step of ready().

### [lua/core/persistent-data.lua](lua/core/persistent-data.lua)
- Handles saving and loading of persistent data between game sessions. Data is specific to one game/character.

### [lua/core/emojis.lua](lua/core/emojis.lua)
- Define the emojis you want for announce-damage and any alerts
- Can also define text to replace the emojis.

## Notes
- Execute lua commands by opening the lua interpreter with `~`, then entering the command. A couple useful ones below.
- LMK if you find any bugs! It'd be helpful if you attach a character file after executing `debug_dump()`.
  This outputs the RC & character state, writes it as a note, and creates a character dump. 
- The RC is intended for webtiles first. It works fine locally, except switching characters doesn't seem to reload the RC.
  Executing `init_buehler()` will reinitialize everything - equivalent to restarting crawl.
- Some of the regex's use negative lookahead/lookbehind, and expect crawl built with PCRE and not POSIX.
  Building crawl locally on MacOS, I use: `make -j4 TILES=y BUILD_PCRE=YesPlease`. I couldn't get emojis to work.

## TODO dev list
1. Add macro to save skill targets & CONFIG values (by race or race+class)
1. Write persistent data to c_persist after each level (to recover from crashes)
1. cleanup/reduce # of display.rc messages

### TODO - requiring crawl PR
1. Wait for allies to heal (needs crawl PR?)
1. Better colorizing of rF+, rC+, etc (needs crawl PR? - to intercept msgs)
1. Bring back mute_swaps.lua - only show final inventory slots (needs to intercept msgs)

## TODO - won't do
1. remove "~~DROP_ME" when dropping
1. autorest starts w/autopickup (if inv not full)
1. level-specific fm ignores (eg vault warden on v:5)

# Known issues
1. Equip/Wear menu doesn't use menu_colour (needs crawl PR?)
1. DPS calcs (for non-wielded weapons) on Coglin: evaluates as if swapping out primary weap (for stat changes from artefacts)
1. Running local tiles (webtiles unaffected), initial screen sometimes needs a refresh on startup (for player stats)

## Resources
### How to learn RC file options
http://crawl.akrasiac.org/docs/options_guide.txt

### How to include Lua in your RC
https://github.com/gammafunk/dcss-rc#1-include-the-rc-or-lua-file-in-your-rc
https://doc.dcss.io/index.html

### How to lookup a players RC file?
http://crawl.akrasiac.org/rcfiles/crawl-0.25/magusnn.rc

### RC Examples & sources used in this repo
https://github.com/magus/dcss
https://github.com/gammafunk/dcss-rc
https://underhound.eu/crawl/rcfiles/crawl-0.30/Elmgren.rc
https://tavern.dcss.io/t/whats-in-your-rc-file/160/4
