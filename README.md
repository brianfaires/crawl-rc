# crawl-rc
Settings files for use in [Dungeon Crawl Stone Soup](https://github.com/crawl/crawl).

## Basics
- All features are enabled and included via [init.txt](init.txt). If you want a single file, [allRC.txt](allRC.txt) contains [init.txt](init.txt) and all the files it references.
- To merge [init.txt](init.txt) into an existing RC file, make sure any Lua hook functions are only defined once (at the bottom of the RC file). If duplicate functions exist, combine them.
- Features can be cherry-picked pretty easily. The simplest way is:
    1. In [init.txt](init.txt), comment out `include` statements to toggle off features. (You don't need to edit the lua hook functions if you remove features.)
    
        e.g. `include = xxxx.rc` -> `#include = xxxx.rc`

    1. Run `python concat_rc.py` to regenerate [allRC.txt](allRC.txt).    

- You can generally include or copy-paste individual files into another RC, as long as [init.txt](init.txt) is also included. If you copy-paste a file with a dependency included (`include = xxxxx.rc`), you'll want to replace that include statement with a copy-paste of the file contents.


## Standard(-ish) Settings

#### [init.txt](init.txt)
A handful of my preferred main and explore options. Contains include statements to all required files, followed by a lua code block for the hook functions.

### [slot-defaults.rc](slot-defaults.rc)
item_slot and spell_slot assignments. One-click spells are put on capital letters.

### [macros.rc](macros.rc)
Default macros and keybinds for a US keyboard:
* The first macro automatically activates the drop filter when you go to drop items.
* Numperpad has a handful of common actions
* Number keys perform spellcasting, and confirm targeting (so you can double-tap the key to fire a targeted spell)

### [autoinscribe.rc](autoinscribe.rc)
Automatically inscribe items, mostly to add warnings to consumables

### [runrest.rc](runrest.rc)
Settings to add or ignore exploration/resting stop messages

### [fm-messages.rc](fm-messages.rc)
Settings to add or remove force_more messages

### [fm-monsters.rc](fm-monsters.rc)
Generates force_more prompts when monsters come into view. Includes all uniques/pan lords, a list of monsters, and a section for dynamic force_mores. Dynamic force_mores only trigger in certain scenarios, based on:
- Current or max HP
- Experience level
- Willpower
- Current intelligence
- Resistances: Fire/Cold/Drain/Elec/Pois/Mut

Currently this section is configured to trigger force_more when a monster threatens to take ~half of your current hp.

### [startup.rc](startup.rc)
One-time actions on startup: Opens skills menu and sets travel speed to slowest ally

## Features

### [inscribe-stats.rc](features/inscribe-stats.rc)
Weapons in inventory are inscribed with DPS (ie damage output per 10 aut) and accuracy - updates in real time with skill/stats/etc.
Armour is inscribed with its AC (or SH) and EV.

### [remind-id.rc](features/remind-id.rc)
When you pick up a scroll of ID or an unidentified item, it'll stop travel and alert if you can ID something.

### [weapon-slots.rc](features/weapon-slots.rc)
Keeps weapons in slots a/b/w. Reassignments happen whenever you drop an item, and it will only kick non-weapons out of these slots.  It'll favor putting ranged and polearms in w.

### [exclude-dropped.rc](features/exclude-dropped.rc)
It'll stop picking up items after you drop one of them... No more picking up every ring of ice you come across.
If you pick up an item again it'll resume picking up more.
This feature is why stones are auto-picked up (if you don't start ranged). Just drop those stones when you're done with them and move on.

### [drop-inferior.rc](features/drop-inferior.rc)
Marks items with `~~DROP_ME` when you pick up a strictly better one.
These items are added to the `drop_list`, so press `,` in the drop menu to select them all.

### [runrest-features.rc](features/runrest-features.rc)
Fancy runrest settings:
* Fully rest off duration/recovery effects when resting/waiting. Attached to rest before exploration.
* No altar stops if you have a god
* Don't stop exploration on portals leading out of gauntlets/baileys/etc

### [mute-swaps.rc](features/mute-swaps.rc)
Minimizes spam when swapping/ID'ing items. When multiple messages with " - " show up in a single turn, it mutes all except those for the first item.  e.g. You read an unidentified scroll, and it's scroll of identify. You identify a potion of curing. The scroll and potion are both moved to their assigned item_slot. Output will be: "x - potion of curing; c - a potion of curing". Without this feature, another 3-4 messages would be displayed, showing the scroll of ID moving to slot i, and whatever items were previously in slots c/i. I find that irrelevant and confusing.

### [after-shaft.rc](features/after-shaft.rc)
Stops on stairs until you get back to the level you were shafted from.

### [safe-stairs.rc](safe-stairs.rc)
Protects against fat-fingering `<>` or `><`, by prompting before immediately returning to the previous floor.

## Pickup and Alert system
Intelligent autopickup based on your character and items in your inventory. Pickup tries to only grab items you *definitely* want, so there is also an alert system to flag items that seem noteworthy. You can enable/disable this for any combination of armour/weapons/misc. There are 3 support files (util/data/main) that are needed by any of the 3 main files.

To prevent spamming, item alerts are not generated for items that are covered by previous alerts/pickups.  e.g. If you're alerted to a +1 chain mail as a potential upgrade to your scale mail, no more alerts will be generated for +1 or +0 chain mails, unless they are branded. Alerts are one-line messages that stop travel and are formatted to stand out.

### [pa-armour.rc](pickup-alert/pa-armour.rc) (Armour)
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
- Heavier/lighter body armour that passes some additional checks. In general, 1 AC is valued ~1.2EV, and alerts are generated when it seems like an armour might be an overall improvement, factoring in brands/AC/EV.

###  [pa-weapons.rc](pickup-alert/pa-weapons.rc) (Weapons)
Picking up pure-upgrades is straightforward enough, but this file does a lot more. 
It inscribes weapons with useful stats:
- An idealized DPS value (damage / speed), factoring in your stats, skills, slaying, and any brands. 
- This is an over-simplification of weapons, but still convenient IMO.
- Inscription also shows (`dmg`/`delay`), and Accuracy bonus

Alerts are generated for:
* Strong weapons early on, with little regard for what skills are trained
* The first one-handed ranged weapon (and two-handed if not wearing a shield)
* High scores: items that set a new record for: Overall damage, Damage w/o brand, and if using allies: Strongest polearm/1-handed polearm
* DPS upgrades and new egos, with various heuristics based off brands/handedness/weapon skill

### [pa-misc.rc](pickup-alert/pa-misc.rc) (Misc)
Picks up staves when you are training the relevant spell school. Alerts generated for:
* Staves that provide you a needed resistance
* The first instance of anything in the "rare_items" list. Each shield type is included, so "rare" is a bit of a misnomer.
* First orb of each type


## Dev todo list
### runrest-features
1. Wait for allies to heal
1. Disable all auto explore stop in gauntlets
    - c_message_ignore_gauntlet_msgs() attempts to do this, but is still stopping for some events. Goal is one autoexplore for everything.
