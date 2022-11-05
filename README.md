# crawl-rc
Settings files for use in dcss.
All files are loaded through init.txt via include statements. Files dependencies are handled more-or-less automatically, so features can be easily cherry-picked. There are 2 ways to do this:
1) Start with the included init.txt, and remove the lines "include = xxxx.rc", to remove unwanted features.
2) Use your own init.txt and add "include = xxxxx.rc" to add each feature. If you do this, you must also add the lua hook functions to your init.txt. You can copy the entire section straight over from the included init.txt, and if you are already using hook functions such as ready(), you will need to merge the two functions since you can only have one of each hook defined.

You are not required to edit the lua hook functions as you remove features - removing the include statements is enough and won't cause errors.

The included python script concat_rc.py will build a single RC file from all of these components. Just put it in the same folder as init.txt and run. If you don't want to run the script, a copy of the single init file will be on branch "single-init-file", though I can't guarantee it'll always be up to date. If you build the single file manually (by copy/pasting), just make sure each file that starts with "include = xxx.rc" comes after xxx.rc. And remove the include commands.

Here's an overview of all files, starting with the simplest:
## Standard RC options

### init.txt
A handful of my preferred main and explore options. Contains include statements to all required files, followed by a lua code block for the hook functions.

### slots.rc
item_slot and spell_slot assignments. All one-click spells are put on capital letters.

### macros.rc
Default macros and keybinds for a US keyboard:
* The first macro automatically activates the drop filter when you go to drop items.
* Numperpad has a handful of common actions
* Number keys perform spellcasting, and confirm targeting (so you can double-tap the key to fire a targeted spell)

### runrest.rc
Settings to add or ignore exploration/resting stop messages

### fm-messages.rc
Settings to add or remove force_more messages

### fm-monsters.rc
Generates force_more prompts when monsters come into view. Includes all uniques/pan lords, a list of monsters, and a section for dynamic force_mores. Dynamic force_mores will only trigger in certain scenarios, based on:
- Current or max HP
- Experience level
- Willpower
- Current intelligence
- Resistances: Fire/Cold/Drain/Elec/Pois/Mut

Currently this section is configured to trigger force_more when a monster threatens to take ~half of your current hp.

### startup.rc
One-time actions on startup: Opens skills menu and sets travel speed to slowest ally


## Standalone Features

### inscribe-dps.rc
Weapons in inventory are inscribed with DPS (ie damage output per 10 aut) and accuracy - updates in real time with skill/stats/etc.

### remind-id.rc
When you pick up a scroll of ID or an unidentified item, it'll stop travel and alert if you can ID something.

### weapon-slots.rc
Keeps weapons in slots a/b/w. Reassignments happen whenever you drop an item, and it will only kick non-weapons out of these slots.  It'll favor putting ranged and polearms in w.

### exclude-dropped.rc
It'll stop picking up jewellery and missiles by name when you drop them... No more picking up every ring of ice you come across. By default it will pick up everything at first - just drop those stones when you're done with them and move on. If you pick up the item again it will resume picking up more.

### safe-consumables.rc
Makes sure there's a confirmation prompt on all 1-click consumables. The standard autoinscribe command doesn't update when items are ID'd so I wrote this.

### drop-inferior.rc
Adds items to the drop list when you pick up a strictly better one.

### runrest-stop.rc
Fancy runrest settings:
* No altar stops if you have a god or are in the temple (and auto search for altars after exploring the temple)
* Don't stop exploration on portals leading out of gauntlets/baileys/etc
* Ignores actions that can't be done the normal way: Allies disappearing, shop mimics, sensing nearby monsters.
* Don't stop on recovery/duration messages when resting. If you're waiting from full hp, then it will.

### mute-swaps.rc
Minimizes spam when swapping/ID'ing items. When multiple messages with " - " show up in a single turn, it mutes all except those for the first item.  e.g. You read an unidentified scroll, and it's scroll of identify. You identify a potion of curing. The scroll and potion are both moved to their assigned item_slot. Output will be: "x - potion of curing; c - a potion of curing". Without this feature, another 3-4 messages would be displayed, showing the scroll of ID moving to slot i, and whatever items were previously in slots c/i. I find that irrelevant and confusing.

### after-shaft.rc
Stops on stairs until you get back to the level you were shafted from.




## Pickup and Alert system
Intelligent autopickup based on your character and items in your inventory. Pickup tries to only grab items you *definitely* want, so there is also an alert system to flag items that seem noteworthy. You can enable this for any combination of armour/weapons/misc. There are 3 support files (util/data/main) that do not need include statements, but must be present for the others to work.

To prevent spamming, item alerts are not generated for items that are covered by previous alerts/pickups.  e.g. If you're alerted to a +1 chain mail as a potential upgrade to your scale mail, no more alerts will be generated for +1 or +0 chain mails, unless they are branded. Alerts are one-line messages that stop travel and are formatted to gently stand out from other text.

### Armour (pa-armour.rc)
Picks up usable armour that is a pure upgrade to what you currently have. e.g. It will pick up any usable cloak if you don't have one. It will then pick up a +1 cloak, and then a +1 cloak of resistance. It will also pick up new brands and artefacts for aux armour (boots/gloves/cloak/helmet/barding).

Alerts are generated for:
* The highest AC body armour seen so far (only if training armour and through xl 12)
* Aux armour that is good but conflicts with non-innate mutations
* Items that gain AC but lose a brand
* New body armour egos
* Heavier/lighter body armour that passes some additional checks. In general, 1 AC is valued ~1.2EV, and alerts are generated when it seems like an armour might be an overall improvement, factoring in brands/AC/EV.

### Weapons (pa-weapons.rc)
Picking up pure-upgrades is straightforward enough, but this file does a lot more. It generates a DPS value for each weapon (damage / speed), that factors in your stats, skills, and slaying bonuses. It considers accuracy, weapon type, skill levels, and other factors. It's not straightforward to describe everything but here are some features:
* Alerts strong weapons early on, with little regard for what skills are trained
* Alerts on the first one-handed ranged weapon (and two-handed if not wearing a shield)
* High scores: Alerts items that set a new record for: Overall damage, Damage w/o brand, Strongest polearm (if using allies)
* Alerts DPS upgrades and new egos, with complex logic around brands/handedness/weapon skill

### Misc (pa-misc.rc)
Picks up staves when you are training the relevant spell school. Alerts generated for:
* Staves that provide you a needed resistance
* Keeps a list of "rare_items" that will always generate an alert when the first one is found. Each shield type is included, so "rare" is a bit of a misnomer.
* First orb of each type


