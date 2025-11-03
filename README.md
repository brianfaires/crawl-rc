# BRC (Buehler RC) - DCSS RC System

A modular system for Dungeon Crawl Stone Soup RC files, designed to be easily customized and extended.

## Quick Start
- Include the contents of `bin/buehler.rc` in your RC file.
- **Merge hooks (if needed)**: Hook functions like `ready()` are defined at the very end of BRC. If your RC already contains these, remove BRC's hook function and add `BRC.ready()` at the top of your hook function.

## Macros / keybinds
- `Cntl-D`: Travel down one level (with the nearest stairs)
- `Cntl-E`: Travel up one level (with the nearest stairs)
- `Cntl-T`: Save current training targets, to be used in future games with same race/class
- `Cntl-Tab`: Autofight, no movement
- `~`: Open lua interpreter
- 1,2,3,4,6,7,8,9,0: Cast spell a,b,c,d,f,g,h,i,j,k
  - Press again to confirm target
- TODO: numpad keybinds

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
- **startup** - Auto-set skill targets, open skills menu, save/reload skill targets by race+class
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
  - _(Advanced)_ See `f_pickup_alert.Config.Tuning` and `BRC.Configs.Default.BrandBonus` for several heuristics that define when alerts fire.

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

- Config is at the top of `buehler.rc`.
Add `disabled = true` to the corresponding feature section of your config.
```lua
  ["alert-monsters"] = { disabled = true }
  ...
```

### 2. Configuring Features

Each feature defines a `Config` table, including default values.
The main config section at the top of `buehler.rc` is used to override those default values.
You can set any feature config value from the main config section. Otherwise the default value is used.
*(See all available config values in `config/Explicit.lua`, or in each feature definition)*

**Ex:** The `inscribe-stats` feature inscribes items with their current stats (AC, EV, DPS, ...).
To disable this for weapons, add this to your config:

```lua
  ["inscribe-stats"] = {
    inscribe_weapons = false, -- Don't maintain weapon info in the inscription 
    inscribe_armour = true,  -- This line is redundant, since the default value is true
  },
```

### 3. User-defined Configs

BRC includes several pre-built configs. You can edit/remove any of them or create new ones.
Any table that includes `BRC_CONFIG_NAME = <config_name>` will be available as a config.

Included configs:
- **Custom**: Intended as the main config for customizing BRC. Includes commonly adjusted fields.
- **Testing**: Turns on debug messages, and disables any features not explicitly configured.
- **Explicit**: A big config with every field defined, set to default values.
- _**Others**_:
  - **Streak**: For win streaks (extra caution)
  - **Speed**: For speed runs (reduced prompts + alerts)
  - **Turncount**: For low-turncount runs (disable autopickup, auto-display info for items in view)

**High-level config settings**
`BRC.Config` is at the top of `buehler.rc` (and `lua/core/_header.lua`) with 3 settings. You can't remove these settings, but you can add others.

```lua
--- All other configs start with these values
BRC.Config = {
  emojis = true, -- Include emojis in alerts

  --- Specify which config (defined below) to use, or how to choose one.
  --   "<config name>": Use the named config
  --   "ask": Prompt at start of each new game
  --   "previous": Keep using the last config
  use_config = "Speed",

  --- For local games, use store_config to use different configs across multiple characters.
  --   "none": Normal behavior: Read use_config, and load it from the RC.
  --   "name": Remember the config name and reload it from the RC. Ignore new values of use_config.
  --   "full": Remember the config and all of its values. Ignore RC changes.
  store_config = "none",
} -- BRC.Config
```

### 4. Add Your Own Features

BRC will find and load any global table that contains a `BRC_FEATURE_NAME`. Just define a table anywhere in your RC and everything else will happen automatically.

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

Each config can define an `init` field, which will execute after the config is created.
This allows a config to alter itself, conditionally add values, or define things based on earlier values in the config.
`BRC.Config.init` and `<feature>.init` both execute before BRC.Config values override feature configs.

`init` can be a function or a multi-line string:
- `init = function()` will execute the function
- `init = [[ string ]]` executes the string as a series of lua commands. _(This is required for `store_config = "full"`, since functions cannot be persisted)_

**Example** _(From BRC.Configs.Testing)_: Disable all features that aren't currently defined in the config.
```lua
BRC.Configs.Testing = {
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
} -- BRC.Configs.Testing
```



## Other topics
### In-Game Commands

Use the Lua interpreter (open with the `~` key) for these commands:

```lua
-- BRC management
BRC.active = false                    -- Disable entire BRC system
BRC.init("config-name")               -- Load config-name and re-init (keeping persistent data)
BRC.reset("config-name")              -- Reset data, load config-name, and re-init
BRC.reset()                           -- Reset everything and re-init
BRC.Data.reset()                      -- Reset persistent data
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
  - **Switching between characters** does not re-execute lua files. As long as you initialize all locals in `init()`,
  this should not cause problems. But it never hurts to restart crawl when switching between characters.

**RC syntax errors**: When editing the RC, a single character out of place can break the whole thing. 
If you edit the RC and get an error on startup: note the error and line number, and try to immediately close/fix it/try again with the same character. You may be prompted to restore data from backup.

**Data backup in `c_persist`**: BRC keeps a backup of persistent data in crawl's `c_persist` table. Backup data is only available for the most recent character opened. It'll automatically restore if no turns have passed since the backup was taken. Otherwise it'll ask for confirmation.

### Other Error Handling prompts
- When a feature throws an error, BRC will offer to disable the feature.
- If errors occur in the core code (rare), BRC may offer to disable a hook. This would impact all features using that hook,
so it's recommended to determine the feature causing the error and disable it.
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
