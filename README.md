# crawl-rc
Settings files for use in [Dungeon Crawl Stone Soup](https://github.com/crawl/crawl) v0.33.1

## Usage
- All features are enabled and included via [init.txt](init.txt).
  [buehler.rc](buehler.rc) contains [init.txt](init.txt) and all the files it references.
- To merge with an existing RC file, make sure any Lua hook functions (such as `ready()`) are only defined
  once. If duplicate functions exist, combine them.
- Most features can be toggled on/off or configured to your tastes in [core/config.lua](core/config.lua).
  See [config.lua section](#luacoreconfiglua) for details.
- Features can also be excluded by just removing or commenting out the one line in [init.txt](init.txt) where it is included.
- If you copy-paste individual files into another RC, be sure to include:
  1. The hook functions from [init.txt](init.txt).
  1. Necessary files from the `lua/core/` folder. The files in `core` won't do anything by themselves, so it's safe to just include them all.
- You can rebuild [buehler.rc](buehler.rc) by running the python script [concat_rc.py](concat_rc.py):
    1. In [init.txt](init.txt), exclude files by commenting out `include =` and `lua_file =` statements by adding a `#` at the start of the line.
    1. Run `python concat_rc.py` to regenerate [buehler.rc](buehler.rc) without the features included.
  - Alternatively, just remove everything between the `Begin <filename>` and `<End filename>` markers in [buehler.rc](buehler.rc).


## Standard(-ish) Settings
### [init.txt](init.txt)
- My preferred main/explore options.
- References all other files.
- Ends with all hook functions, connecting features to crawl.

### [rc/autoinscribe.rc](rc/autoinscribe.rc)
- Automatically inscribe items.

### [rc/autopickup.rc](rc/autopickup.rc)
- Standard autopickup settings.

### [rc/display.rc](rc/display.rc)
- Various display related settings, including customized colors for 1000's of messages.
  Some are a bit dated, but a good starting point to build on.  
  *(If anyone knows who meticulously hand-wrote all of these, LMK so I can attribute.)*

### [rc/fm-messages.rc](rc/fm-messages.rc)
- Settings for force_more and flash_screen events.

### [rc/macros.rc](rc/macros.rc)
- Numpad has a handful of common actions.
- Number keys perform spellcasting, and also confirm targeting so you can double-tap to fire a targeted spell.

### [rc/runrest.rc](rc/runrest.rc)
- Settings for exploration/resting stop messages.

### [rc/slot-defaults.rc](rc/slot-defaults.rc)
- item_slot assignments: Rings on P/p, etc.
- spell_slot assignments for one-click spells on capital letters. 


## Lua files - usually one per feature
### [lua/features/after-shaft.lua](lua/features/after-shaft.lua)
- After being shafted, travel stops on stairs until you get back to the original level.

### [lua/features/announce-damage.lua](lua/features/announce-damage.lua)
- Writes messages for HP and MP changes.
- Includes HP and MP meters broken into 10% increments.  
  *(Meters have length 5, with each character being empty/partial/full)*

### [lua/features/color-inscribe.lua](lua/features/color-inscribe.lua)
- Adds color to item inscriptions for resistances, stat modifiers, etc.

### [lua/features/drop-inferior.lua](lua/features/drop-inferior.lua)
- Marks items with `~~DROP_ME` when you pick up a strictly better one.
- This adds items to the drop_list, so press `,` in the drop menu to select them all.

### [lua/features/dynamic-options.lua](lua/features/dynamic-options.lua)
- Any options that should change mid-game based on XL, God, Class, etc.

### [lua/features/exclude-dropped.lua](lua/features/exclude-dropped.lua)
- Excludes autopickup for items when you drop your entire stack.
  Resumes if you pick it back up.
- Doesn't apply to enchant/brand weapon scrolls, if carrying an enchantable weapon.
- *(Crawl has `drop_disables_autopickup`, but I prefer this behavior instead)*

### [lua/features/fm-disable.lua](lua/features/fm-disable.lua)
- Disables more() prompt for some crawl messages that cause a more() without using `force_more_message`.

### [lua/features/fm-monsters.lua](lua/features/fm-monsters.lua)
*(Configuration needs a cleanup for v0.33)*
- Generates force_more prompts when monsters come into view. Includes:
  - All uniques and Pan Lords
  - A list of 'always alert' monsters
  - Dynamic force_mores that trigger based on: HP, Resistances, XL, Willpower, Int
  *(Roughly configured to fire when a monster can take 50% HP in one hit)*
  - Avoids triggering on zombies, skeleton, etc.

### [lua/features/fully-recover.lua](lua/features/fully-recover.lua)
- Updates resting to fully recover from temporary negative statuses.
- Configure which statuses in `CONFIG.rest_off_statuses`.

### [lua/features/inscribe-stats.lua](lua/features/inscribe-stats.lua)
- Weapons in inventory are inscribed with their stats and an 'idealized' DPS (max damage per 10 aut, including brand).
- Unworn armour is inscribed with stats relative to what you're wearing.
- Updates in real time with skill/stats/etc.

### [lua/features/misc-alerts.lua](lua/features/misc-alerts.lua)
- A force-more when dropping below 35% HP (configurable).
- A msg when you hit 6* piety while wearing an amulet of faith

### [lua/features/remind-id.lua](lua/features/remind-id.lua)
- When you pick up a scroll of ID or an unidentified item, it'll stop travel and alert if you can ID something.
- Before finding scroll of ID, stops travel when you increase your largest stack of un-ID'd scrolls/pots.

### [lua/features/runrest-features.lua](lua/features/runrest-features.lua)
- No altar stops if you have a god
- Don't stop exploration on portals leading out of baileys/sewers/etc
- Stop travel on gates in Pan
- Auto-search items when entering a gauntlet or temple. Runs to temple exit after worship.

### [lua/features/safe-consumables.lua](lua/features/safe-consumables.lua)
- Adds and maintains `!r` and `!q` inscriptions on consumables.

### [lua/features/safe-stairs.lua](lua/features/safe-stairs.lua)
- Protects against fat-fingering `<>` or `><`, by prompting before immediately returning to the previous floor.
- Prompts before entering Vaults:5.

### [lua/features/startup.lua](lua/features/startup.lua)
- One-time actions on new games:
  - Open the skills menu
  - Exclusively train the first skill in CONFIG.auto_set_skill_targets below its target

### [lua/features/weapon-slots.lua](lua/features/weapon-slots.lua)
- Keeps weapons in slots a/b/w. Reassignments happen whenever you pickup or drop an item.
  It'll only kick non-weapons out of these slots. Favors putting ranged and polearms in w.

## Pickup and Alert system
Intelligent autopickup based on your character and items in your inventory. Tries to only pickup
  items you *definitely* want, so there is an alert system to flag noteworthy items.

Alerts are one-line messages that stop travel and are formatted to stand out.
To avoid spam, alerts won't fire on later items that are identical/inferior.
Diff alert types can be configured to cause a more() prompt.

> e.g. If you're alerted to a +1 broad axe or pick one up, no more alerts are generated
> for +1 or +0 broad axes, unless they're branded.

### [lua/pickup-alert/pa-armour.lua](lua/pickup-alert/pa-armour.lua) (Armour)
Picks up armour that is a pure upgrade to what you currently have.

Alerts generated for:
- Items with new egos or increased AC.
- Early ego armour, even if not training armour
- The highest AC body armour seen so far (if training armour).
- Other armour, depending on a number of factors and the thresholds in `TUNING.armour`  .
  In general, 1 AC is valued ~1.2EV,
- Will alert "useless" items if you have one of the same type in inventory.
  This is to avoid skipping items due to temporary mutations.

###  [lua/pickup-alert/pa-weapons.lua](lua/pickup-alert/pa-weapons.lua) (Weapons)
Picks up upgrades. Alerts generated for:
- Early strong weapons, with little regard for what skills are already trained.
- First ranged and 1-handed ranged weapons.
- First polearm and 1-handed polearm.
- Other weapons, using a score that is primarily the weapon's DPS. Tune the thresholds in `TUNING.weap`.
- High scores: items that set a new record for:
  - Overall damage
  - Damage w/o brand


### [lua/pickup-alert/pa-misc.lua](lua/pickup-alert/pa-misc.lua) (Misc)
Picks up staves when you are training the relevant spell school. Alerts are generated for:
- The first instance of anything in the `CONFIG.alert.one_time` list.
- First orb of each type.
- First talisman of each type, if the min skill is within `CONFIG.alert.talisman_lvl_diff` levels.
- Staves that provide you a needed resistance.

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
This comes first in [buehler.rc](buehler.rc), so you can adjust behavior
  without digging into the code or rebuilding [buehler.rc](buehler.rc).  
Most features are entirely configured here. The ones that aren't here typically are configured with 
  a bunch of messages. So those are set in the feature file instead.

### [lua/core/constants.lua](lua/core/constants.lua)
In an attempt to future-proof, contains definitions for things like
  `ALL_WEAP_SCHOOLS` and `ALL_PORTAL_NAMES`. Update as needed.

### [lua/core/util.lua](lua/core/util.lua)
Required a lot of places. Nothing in here is necessarily specific to this repo.

### [lua/core/persistent-data.lua](lua/core/persistent-data.lua)
- Handles saving and loading of persistent data between game sessions. Data is specific to one game/character.
- If any data from the previous save fails to load, you'll get a warning on startup.
  This can happen after a crash, or if changes to the RC cause errors.
  The impact is low - it just forgets things like which items it's already alerted.

### [lua/core/emojis.lua](lua/core/emojis.lua)
- Define the emojis you want used in announce-damage and any alerts.
- Can also define text to replace the emojis.

## Notes
- LMK if you find any bugs! It'd be helpful if you include your RC or Config, and a character dump after
  executing `debug_dump()`.
  This outputs the RC & character state, writes it as a note, and creates a character dump.
- Avoid putting  `}` on a line by itself. This breaks crawl's RC parser. Don't remove the comments that follow a `}`.
  They protect the line from confusing the parser.
- Execute lua commands by opening the lua interpreter with `~`, then entering the command.
  Some useful ones are:
    - `init_buehler()` will reinitialize everything as if crawl was closed and reopened.
    - `init_buehler(1)` will also reset all persistent data.
    - `debug_dump()` whenever something seems weird, I do this. `debug_dump(1)` for verbose export.
    - `buehler_rc_active = false` will disable everything
    - `CONFIG.<setting_name> = <value>` will work mid game if you really want to.
- The RC prioritizes webtiles. It works locally, but here are some issues I've seen previously:
  - Running locally, switching between characters does some weird things with RC/lua files and autopickup functions.
    I think all the issues are mitigated. If you get warnings when switching characters, just close+reopen crawl.
  - Sometimes player stats don't draw on game open (open/close inventory to refresh)
  - Some of the regex's use negative lookahead/lookbehind, which require crawl to be built with
  POSIX regexes. If you built crawl locally and used PCRE (defaul on MacOS), some patterns won't match.
  I used: `make -j4 TILES=y BUILD_PCRE=YesPlease`. I couldn't get emojis to work.
  
## Dev Notes
### To do list
1. Add macro to save skill targets & CONFIG values (by race or race+class)
1. Write persistent data to c_persist after each level (to recover from crashes)
1. cleanup/reduce # of display.rc messages
1. On alert, prompt/offer to pickup item
1. On pickup, if safe(), offer to wear/wield item
1. On drop_inferior inscribe, offer to drop item
1. If no god or good god, auto-visit Temple instead of force-more

### 0.34 changes needed
1. Inventory slots changed: Can no longer use l-item.inslot() to reliably get an item?

### TODO - requiring crawl PR?
1. Wait for allies to fully heal
1. Better colorizing of rF+, rC+, etc (needs to intercept msgs)
1. Bring back mute_swaps.lua - only show final inventory slots (needs to intercept msgs)
1. remove "~~DROP_ME" when dropping item (needs to inscribe items on floor)

### Won't do
1. autorest starts w/autopickup (if inv not full)
1. level-specific fm ignores (eg vault warden on v:5)

### Known issues/quirks
1. DPS calcs (for non-wielded weapons) on Coglin: evaluates as if swapping out primary weap (for stat changes from artefacts)
1. AC/EV delta inscriptions on Poltergeist: compare against the last (6th) worn item


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
