# crawl-rc
Settings files for use in [Dungeon Crawl Stone Soup](https://github.com/crawl/crawl).

## Basics
- All features are enabled and included via [init.txt](init.txt). If you want a single file, 
    [allRC.txt](allRC.txt) contains [init.txt](init.txt) and all the files it references.
- To merge [init.txt](init.txt) into an existing RC file, make sure any Lua hook functions are only 
    defined once (at the bottom of the RC file). If duplicate functions exist, combine them.
- Features can be individually toggled off. The simplest way is:
    1. In [init.txt](init.txt), comment out `include = ` or `lua_file = ` statements to toggle off features.
    
        e.g. `lua_file = xxxx.lua` -> `#lua_file = xxxx.lua`

    2. Run `python concat_rc.py` to regenerate [allRC.txt](allRC.txt) without the features included.    

- You can copy-paste individual files into another RC, as long as you also copy any other files they reference. 
References are at the top of the file. 
You must also include the hook functions from [init.txt](init.txt). 
If you copy-paste a file with a dependency (e.g. `include = xxxxx.rc`), you'll want to replace any `include`, 
and `dofile()` statements with a copy-paste of the referenced file. Do the same for any lua files (`lua_file = `), 
and be sure to add curly braces around the file contents `{ <file_contents> }`. 
And don't manualy copy-paste the same file more than once.


## Standard(-ish) Settings

### [init.txt](init.txt)
A handful of my preferred main and explore options. Contains references to other files.
Importantly, it ends with a lua code block for all hook functions (which connect features to crawl).

### [rc/autoinscribe.rc](rc/autoinscribe.rc)
Automatically inscribe items, mostly to add warnings to consumables

### [rc/display.rc](rc/display.rc)
Various display related settings, including 1000's of colors for customized messages.
*This section needs attribution - would really like to list the original author.*

### [rc/fm-messages.rc](rc/fm-messages.rc)
Settings for force_more messages

### [rc/macros.rc](rc/macros.rc)
Default macros and keybinds for a US keyboard:
- Numperpad has a handful of common actions
- Number keys perform spellcasting, and confirm targeting (so you can double-tap the key to fire a targeted spell)

### [rc/runrest.rc](rc/runrest.rc)
Settings for exploration/resting stop messages

### [rc/slot-defaults.rc](rc/slot-defaults.rc)
item_slot and spell_slot assignments. Huge QOL boost IMO. 
One-click spells on capital letters. Rings on P/p, etc.


## Lua files: one per feature
### [lua/after-shaft.lua](lua/after-shaft.lua)
Stops travel on stairs until you get back to the level you were shafted from.

### [lua/display-damage.lua](lua/display-damage.lua)
Writes messages for HP and MP changes. I believe same author as [rc/display.rc](rc/display.rc).

### [lua/drop-inferior.lua](lua/drop-inferior.lua)
Marks items with `~~DROP_ME` when you pick up a strictly better one.
These items are added to the `drop_list`, so press `,` in the drop menu to select them all.

### [lua/dynamic-options.lua](lua/dynamic-options.lua)
Anything that changes based on XL, God, etc.

### [lua/exclude-dropped.lua](lua/exclude-dropped.lua)
It'll stop picking up items after you drop one of them... No more picking up every ring of ice you come across.
If you pick up an item again it'll resume picking up more.
This feature is why stones are auto-picked up (if you don't start ranged). 
Just drop those stones when you're done with them and move on.

### [lua/fm-monsters.lua](lua/fm-monsters.lua)
Generates force_more prompts when monsters come into view. 
Includes all uniques/pan lords, a list of monsters, and a section for dynamic force_mores. 
Dynamic force_mores only trigger in certain scenarios, based on:
- Current or max HP
- Experience level
- Willpower
- Current intelligence
- Resistances: Fire/Cold/Drain/Elec/Pois/Mut

Currently this section is configured to trigger when a monster threatens to take ~half of your current hp.

### [lua/inscribe-stats.lua](lua/inscribe-stats.lua)
Weapons in inventory are inscribed with their stats and an idealized DPS (ie damage output per 10 aut). 
Updates in real time with skill/stats/etc.
Armour is inscribed with its AC (or SH) and EV.

### [lua/misc-alerts.lua](lua/misc-alerts.lua)
2 alerts: A one-time force-more when dropping below 50% HP. And a msg when you hit 6* piety w/ amulet of faith

### [lua/mute-swaps.rc](lua/mute-swaps.lua)
Minimizes spam when swapping/ID'ing items. When multiple messages with " - " show up in a single turn, 
it mutes all except those for the first item.  e.g. You read an unidentified scroll, and it's scroll of identify. 
You identify a potion of curing. The scroll and potion are both moved to their assigned item_slot. Output will simply 
be: "x - potion of curing; c - a potion of curing". Without this feature, another 3-4 messages would be displayed, 
showing the scroll of ID moving to slot i, and whatever items were previously in slots c/i. I find that irrelevant and confusing.

### [lua/remind-id.lua](lua/remind-id.lua)
When you pick up a scroll of ID or an unidentified item, it'll stop travel and alert if you can ID something.

### [lua/runrest-features.lua](lua/runrest-features.lua)
QOL runrest settings:
- Fully rest off duration/recovery effects when resting/waiting. Attached to rest before exploration.
- No altar stops if you have a god
- Don't stop exploration on portals leading out of gauntlets/baileys/etc

### [lua/safe-stairs.rc](lua/safe-stairs.lua)
Protects against fat-fingering `<>` or `><`, by prompting before immediately returning to the previous floor.

### [lua/startup.lua](lua/startup.lua)
One-time actions on startup: Just opens skills menu now.

### [lua/weapon-slots.lua](lua/weapon-slots.lua)
Keeps weapons in slots a/b/w. Reassignments happen whenever you drop an item, and it will only kick 
non-weapons out of these slots.  It'll favor putting ranged and polearms in w.

## Pickup and Alert system
Intelligent autopickup based on your character and items in your inventory. 
Pickup tries to only grab items you *definitely* want, so there is also an alert system to flag items that seem noteworthy. 
You can enable/disable this for any combination of armour/weapons/misc. There are 3 support files 
    (util/data/main) that are included with any of the 3 main files.

To prevent spamming, item alerts are not generated for items that are covered by previous alerts/pickups.  
e.g. If you're alerted to a +1 chain mail as a potential upgrade to your scale mail, no more alerts will be generated 
for +1 or +0 chain mails, unless they are branded. Alerts are one-line messages that stop travel and are formatted to stand out.

### [pa-armour.rc](lua/pickup-alert/pa-armour.lua) (Armour)
Picks up usable armour that is a pure upgrade to what you currently have. ex:
- Picks up a usable cloak if you don't have one,
- Then picks up a +1 cloak,
- Then picks up a +1 cloak of resistance,
- Also picks up new brands and artefacts for aux armour slots.

Alerts are generated for:
- The highest AC body armour seen so far (only if training armour and through xl 12)
- Aux armour that is good but conflicts with non-innate mutations
- Items that gain AC but lose a brand
- New body armour egos
- Heavier/lighter body armour that passes some additional checks. In general, 1 AC is valued ~1.2EV, 
    and alerts are generated when it seems like an armour might be an overall improvement, factoring in brands/AC/EV.

###  [pa-weapons.rc](lua/pickup-alert/pa-weapons.lua) (Weapons)
Picking up pure-upgrades is straightforward enough, but this file does a lot more. 
It inscribes weapons with useful stats:
- An idealized DPS value (damage / speed), factoring in your stats, skills, slaying, and any brands. 
- This is an over-simplification of weapons, but still convenient IMO.
- Inscription also shows (`dmg`/`delay`), and Accuracy bonus

Alerts are generated for:
- Strong weapons early on, with little regard for what skills are trained
- The first one-handed ranged weapon (and two-handed if not wearing a shield)
- High scores: items that set a new record for: Overall damage, Damage w/o brand, and if using allies: Strongest polearm/1-handed polearm
- DPS upgrades and new egos, with various heuristics based off brands/handedness/weapon skill

### [pa-misc.rc](lua/pickup-alert/pa-misc.lua) (Misc)
Picks up staves when you are training the relevant spell school. Alerts generated for:
- Staves that provide you a needed resistance
- The first instance of anything in the "rare_items" list. Each shield type is included, so "rare" is a bit of a misnomer.
- First orb of each type

## Dev notes
- I wrote this over 2 years ago and recently refreshed it when lua inscriptions was enabled via lua.
    I've run it with several characters, but can't cover everything. 
    Please LMK if you find bugs, outdated notes, suggestions, etc.

### TODO list
1. 0.33.1 Updates: spells, runrest_status's, rare_items, misc_items(talismans)
1. Disable all auto explore stops in gauntlets until fully explored
    - c_message_ignore_gauntlet_msgs() attempts to do this, but is still stopping for some events. Goal is one autoexplore for everything.
1. Update fm-monsters lists to {name, is_mutator, max_dmg, max_fire_dmg, ... , max_elec_dmg};
1. dynamic-options.rc to use lists like {god name, [fm-prompts]}
1. Separate toggles for pickup & alert
1. Better colorizing of rF+, rC+, etc (needs crawl PR?)
1. Wait for allies to heal (needs crawl PR?)
