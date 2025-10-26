# BRC (Buehler RC) - DCSS RC System

A modular system for Dungeon Crawl Stone Soup RC files, designed to be easily customized and extended.

## Quick Start
- Include the contents of `bin/buehler.rc` in your RC file.
- **Merge hooks (if needed)**: Hook functions like `ready()` are defined at the very end of BRC. If your RC already contains these, remove BRC's hook function and add `BRC.ready()` at the top of your hook function.

## File Structure

```
bin/                    # Pre-built RC files
├── buehler.rc              # Core + all features (Use this for webtiles)
├── only_core.rc            # Core with no features
├── only_pickup_alert.rc    # pickup-alert feature as a single file
lua/                    # Lua files
├── core/                   # Core BRC system
│   ├── brc.lua                 # Main coordinator
│   ├── config.lua              # Config definitions
│   ├── data.lua                # Manages persistent data + backup
│   ├── util.lua                # General functions available to features
│   └── constants.lua
├── features/               # Feature modules
│   ├── _template.lua           # Template for new features
│   ├── pickup-alert/           # Pickup-Alert (multi-file feature)
│   └── ...                     # Other features
rc/                     # RC file components
build/                  # Scripts to generate bin/
```

## Feature Overview
_(See header of each feature's lua code for more detail)_

### Most Noticeable Features
- **pickup-alert** - Smart autopickup and alerts for interesting items _(Detailed description below)_
- **announce-hp-mp** - Print current HP/MP with meters (ex. ❤️❤️❤️‍🩹🤍🤍) on HP/MP changes

### Item management
- **color-inscribe** - Add color in item inscriptions (like <span style="color: red;">rF++</span>)
- **inscribe-stats** - Auto-inscribe items with appropriate stats, like +/- AC/EV, DPS, etc
- **drop-inferior** - Alert when you pick up a replacement for an item in inventory, and add the inferior one to the drop list
- **weapon-slots** - Keep weapons in slots a/b/w
- **safe-consumables** - Robustly maintain `!q` and `!r` inscriptions only where required

### Alerts
- **alert-monsters** - `flash_screen` or `force_more` on dangerous monsters, based on your HP/Will/Resistances/etc _(Huge config)_
- **remind-id** - Alert when you should read a scroll of ID. Before finding scroll of ID, stop travel on increasing un-ID'd stack sizes
- **misc-alerts** - Misc useful alerts: Low HP, spell levels, Amulet of faith + max piety
- **quiver-reminders** - Alert before (f)iring from quiver: if a consumable, or after (F)iring a different ammo

### Exploration
- **runrest-features** - Update travel stops based on location/religion/recent shaft. Auto-search when entering temple/gauntlet
- **safe-stairs** - Prevent accidental stair usage. Warn before entering V:5
- **fully-recover** - Rest until negative status effects clear

### Misc
- **dynamic-options** - Change crawl settings based on XL, religion, etc
- **startup** - Set skill targets and/or open skills menu
- **answer-prompts** - Auto-answer certain prompts
- **exclude-dropped** - Exclude dropped items from autopickup

## Pickup & Alert Feature

The `pickup-alert` feature provides smart autopickup that grabs items you definitely want,
and generates alerts for noteworthy items.
The goal is to enable confident "o-tabbing" without inspecting every dropped item or searching the entire floor to make sure you didn't overlook anything.

### How It Works
- **Alerts** are one-line messages that stop travel and stand out visually
- **No spam** - alerts won't fire for identical/inferior items
- **Smart** - adjusts behavior to your inventory and character progression
- **Configurable** - lots of config values for which alerts are active, when they fire, and when to do a force_more.
  - In `f_pickup_alert.Config.Alert`, see `armour_sensitivity` and `weapon_sensitivity` to adjust the overall frequency of alerts.
  - _(Advanced)_ See `f_pickup_alert.Config.Tuning` and `BRC.Config.BrandBonus` for several heuristics that define when alerts fire.

### Alerts
- **`pa-armour.lua`**
  - Alerts for artefacts, new egos, or anything with a plausible tradeoff of AC/encumbrance/ego
- **`pa-weapons.lua`**
  - Checks each weapon in inventory for upgrades/alerts. (inscribe `!u` or `!brc` to exclude a carried weapon)
  - Alerts for artefacts, new egos, strong early weapons, first ranged/polearm, highest flat damage, ...
- **`pa-misc.lua`**
  - A list of "one-time alerts" - the first time you encounter specific items (e.g. broad axe, eveningstar, tower shield)
  - New orbs, relevant talismans
  - Staves that provide a needed resistance.

## Configuration Guide

### 1. Disabling Features

**Method 1 (Simple): Delete the code**

- Delete the feature definition from your RC:
  - Delete everything from: `#### Begin <feature_name>` - `#### End <feature_name>`

**Method 2 (Flexible): Disable via config**

- In the config section (at the top of `buehler.rc`), set the feature's disabled flag:
  ```lua
  BRC.Config["misc-alerts"].disabled = true
  ```

### 2. Configuring Features

Each feature defines a `Config` with default values. You can change the default values there, or override them in the main BRC config (recommended).

For example, the `inscribe-stats` feature maintains each item's current stats (AC, EV, DPS, ...) in the inscription. To disable this for weapons, add the following to the config:

```lua
BRC.Config["inscribe-stats"] = {
    inscribe_weapons = false, -- Don't maintain weapon info in the inscription 
    inscribe_armour = true,  -- This line is redundant, since the default value is true
  }
```
**Note**: The main config (at the top of `buehler.rc`) overrides the default config values defined in each feature. If something is not included in `BRC.Config`, the default value is used.

### 3. Config Profiles

BRC comes with several pre-built configs, stored in `BRC.Profiles`. You can add/remove/edit any of them:
- **Default**: All default values, plus whatever you add to `BRC.Config`.
- **Custom**: Intended as the main profile for customizing BRC.
- **Testing**: Turns on debug messages, and disables any features not explicitly configured.
- _**Others**_:
  - **Speed**: For speed runs (reduced prompts + alerts)
  - **Turncount**: For low-turncount runs (disable autopickup, auto-display info for items in view)
  - **Streak**: For win streaks (extra caution)

**Use a different config** by editing `BRC.use_config` at the top of the config section:
```lua
-- Found at the start of config
BRC.use_config = "Turncount"

-- BRC.use_config = "ask" will prompt you to pick a profile at the start of each game.
-- BRC.use_config = "previous" will keep using whichever profile was used last.
```
The resulting profile is loaded into `BRC.Config`.

**Detailed behavior**
1. Values from `<Feature>.Config` are loaded.
2. Values from `BRC.Profiles.Default` are added, potentially overwriting previous values.
3. Values from `BRC.Config` are added, potentially overwriting previous values.

**Switch profiles in-game**
- TODO

**Create your own config/profile**

Follow the pattern of other configs:
```lua
BRC.use_config = "MyConfig"
BRC.Profiles.MyConfig = {
  ["feature-name"] = {
    feature_config_var = "override" -- any var in feature.Config
  },
}
```

**Character-specific configs**

If you're playing locally with multiple characters, and want different settings in each game, use `BRC.store_config`:

```lua
BRC.store_config = "name" -- Remember the profile name, and load it from the RC on each startup
BRC.store_config = "full" -- Remember all of BRC.Config, and ignore any changes to it in the RC. (Feature default values are always reloaded from RC)
BRC.store_config = "none" or "anything_else" or nil -- Always check BRC.use_config and load it from the RC
```

### 4. Add Your Own Features

BRC will find and load any global lua table that contains a `BRC_FEATURE_NAME`. Just define a table anywhere in your RC and everything else will happen automatically.

**Step 1: Define your feature**

See `features/_template.lua` for a full example

```lua
my_feature = {}
my_feature.BRC_FEATURE_NAME = "my-feature" -- This registers my_feature with BRC

my_feature.Config = {
  turn_num = 100,
  use_crawl_mpr = true,
} -- always put a comment after a lone '}' (or else crawl's RC parser breaks)

function my_feature.ready()
  if you.turns() == my_feature.Config.turn_num then
    if my_feature.Config.use_crawl_mpr then
      crawl.mpr("<blue>Turn reached!</blue>")
    else
      BRC.mpr.blue("Turn reached!") -- See core/util.lua for useful functions
    end
  end
end
```

**Step 2: Persistent variables** (optional):

Create variables that retain their value across saves like this:
```lua
already_alerted = BRC.Data.persist("already_alerted", false) -- var name and initial value
items_found = BRC.Data.persist("items_found", {}) -- tables too
```
In your code, access the variables normally:
```lua
already_alerted = true -- Remember that some alert fired

...

table.insert(items_found, "broad axe") -- Remember that you found a broad axe
items_found[#items_found+1] = "tower shield" -- Another way to append to a list
```

Persistent variables start off each game with their initial value, and remember any changes for the rest of the game. They are _**not**_ shared across different games.

**Step 3: Add hooks** (optional):

If you define `my_feature.init()`, it will be called when BRC starts up. This is similar to putting raw code in your RC file, but is more robust.

These crawl hooks are currently implemented:
- ready()
- autopickup(it)
- c_answer_prompt(prompt)
- c_assign_invletter(it)
- c_message(text, channel)
- ch_start_running(kind)

Define them in your feature and they will be automatically hooked to crawl. Example:
```lua
my_feature.c_assign_invletter(it)
  ...
end
```

**Step 4: Advanced config** (optional):

Each config can define `my_feature.Config.init`, which will execute after the config is created.
- Setting `init = function()` will execute the function
- Setting `init = [[ string ]]` will execute the string as a series of lua commands. _(This is required for `config_memory = "full"`, since functions cannot be persisted)_

This allows a Config to alter itself or do things based on earlier values in the Config. `init` executes after the Config is created, but before the main config overrides results. To execute code after the main config (`BRC.Config`) loads, use the feature's init function `my_feature.init()`.

**Example** _(From BRC.Profiles.Testing)_: Disable all features that aren't currently defined in the profile.
```lua
BRC.Profiles.Testing = {
  disable_other_features = true,
  ...,

  init = [[
    if BRC.Config.disable_other_features then
      for _, v in pairs(_G) do
        if BRC.is_feature_module(v) and not BRC.Config[v.BRC_FEATURE_NAME] then
          BRC.Config[v.BRC_FEATURE_NAME] = { disabled = true }
        end
      end
    end
  ]],
} -- BRC.Profiles.Testing
```



## Other topics
### In-Game Commands

Use the Lua interpreter (open with the `~` key) for these commands:

```lua
-- BRC management
BRC.active = false                    -- Disable entire BRC system
BRC.reset()                           -- Reset everything and re-init
BRC.Data.reset()                      -- Reset all persistent data
BRC.load_profile()                     -- Select a config from list and load it
BRC.load_profile("config-name")        -- Load a config by name
BRC.unregister("feature-name")        -- Disable a feature

-- Debugging
BRC.dump()                        -- Print all persistent data
BRC.dump(1)                       -- Print a lot more debugging info
BRC.Config.mpr.show_debug_messages = true -- Enable debug output
```

### Troubleshooting
**Bugs/Issues**: Please submit/send me any issues you find! It would help to attach:
- A copy of your RC
- **Character dump**: Press `#`, and answer `Y` to include BRC debug info.

**Pitfalls to avoid**:
- Never put `}` on a line by itself (crawl's RC parser will misinterpret it as "end of lua code"). Always add a comment after it like this:
  ```lua
  # RC code
  ...
  { -- Begin lua code
    my_lua_table = {
      ...
    } -- need this comment to avoid error
    this_is_fine = { ... }
  }
  ...
  # More RC
  ```
- If running crawl locally:
  - **Regex issues**: Some regular expression patterns require PCRE (not POSIX). If you build crawl locally, use build flag `BUILD_PCRE=y`.
  - **Emojis**: Webtiles has a good font with solid emoji support. AFAICT MacOS doesn't, so I configure `BRC.Config.emojis = false` locally.
  If you have one, define it in `rc/display.rc`, and LMK!
  - **Switching between characters** uses the same lua environment (at least on MacOS). Nothing gets reset except what's in init() Things get duplicated, including crawl's own autopickup functions.
  BRC checks for this and warns you to restart. It appears to be harmless but I usually restart anyway.

**RC syntax errors**: When editing the RC, a single character out of place can break the whole thing. 
If you edit the RC and get an error on startup: note the error and line number, and try to immediately close/fix it/try again with the same character.

**Data backup in `c_persist`**: BRC keeps a backup of persistent data in crawl's `c_persist` table. Backup data is only available for the most recent character opened. It'll automatically restore if no turns have passed since the backup was taken. Otherwise it'll ask for confirmation.

### Other Error Handling prompts
- When a feature throws an error, BRC will offer to disable the feature.
- If errors occur in the core code (rare), BRC may offer to disable a hook. This would impact all features using that hook, so it's recommended to determine the feature causing the error and disable it.
- In both cases, it's probably worth saying No once, then disabling things if the error persists. Restarting crawl will re-enable all features and hooks.

## Resources
### DCSS Documentation
- [RC Options Guide](http://crawl.akrasiac.org/docs/options_guide.txt)
- [Lua Integration Guide](https://github.com/gammafunk/dcss-rc#1-include-the-rc-or-lua-file-in-your-rc)
- [DCSS Lua API](https://doc.dcss.io/index.html)

### Cool RC files / Sources of features
- Use this syntax to lookup a player's RC file:
[http://crawl.akrasiac.org/rcfiles/crawl-0.33/buehler.rc](http://crawl.akrasiac.org/rcfiles/crawl-0.33/buehler.rc)  
- [gammafunk/dcss-rc](https://github.com/gammafunk/dcss-rc)
- [magus/dcss](https://github.com/magus/dcss)
- [linewriter1024/crawl-rc](https://github.com/linewriter1024/crawl-rc)
- [Other RC Examples](https://tavern.dcss.io/t/whats-in-your-rc-file/160/4)
