# BRC (Buehler RC) - DCSS RC System

A modular system for Dungeon Crawl Stone Soup RC files, designed to be easily customized and extended.

## Quick Start
- Include the contents of `bin/buehler.rc` in your RC file.
- **Merge hooks (if needed)**: Hook functions like `ready()` are defined at the very end of BRC.
If your RC already contains these, remove BRC's hook function and add `BRC.ready()` at the top of your hook function.

## Built-in Keybinds / Macros
- `Cntl-D`: Travel down one level (with the nearest stairs)
- `Cntl-E`: Travel up one level (with the nearest stairs)
- `Cntl-T`: Save current training targets, to be used in future games with the same race/class
- `Cntl-Tab`: Autofight, no movement
- `~`: Open lua interpreter
- 1,2,3,4,6,7,8,9,0: Cast spell a,b,c,d,f,g,h,i,j,k (press again to confirm targetting)
  - Press again to confirm target
- TODO: numpad keybinds

## Feature Modules

BRC is made up of feature modules that are isolated from each other. Each feature can be independently edited, enabled, and configured.
All features work out of the box with sensible config defaults. You can customize anything later if you want, but you don't need to!

While you can modify features normally, it's intended to configure them all in a config at the top of your RC.
Looking at a feature module might still be helpful to read the description, or see what config options are available.

### Most Noticeable Features

- **pickup-alert** - Smart autopickup and alerts for noteworthy items. _(See detailed description below)_
- **announce-hp-mp** - Displays current HP/MP with visual meters (ex. ❤️❤️❤️‍🩹🤍🤍) whenever HP/MP changes
- **inscribe-stats** - Auto-inscribes items with relevant stats like +/- AC/EV, DPS, etc.

### Inventory Management

- **color-inscribe** - Adds color to item inscriptions (like <span style="color: red;">rF++</span>)
- **drop-inferior** - Alerts when you pick up a replacement for an item in inventory, and adds the inferior one to the drop list
- **exclude-dropped** - Excludes dropped items from autopickup
- **safe-consumables** - Robustly maintains `!q` and `!r` inscriptions only where required
- **weapon-slots** - Keeps weapons organized in slots a/b/w

### Alerts & Warnings

- **alert-monsters** - `flash_screen` or `force_more` on dangerous monsters, based on your HP/Will/Resistances/etc. Highly configurable.
- **misc-alerts** - Various useful alerts: Low HP, spell levels, max piety w/ Amulet of faith
- **quiver-reminders** - Alerts before (f)iring from quiver: if a consumable, or after (F)iring a different ammo
- **remind-id** - Alerts when you should read a scroll of ID. Before finding scroll of ID, stops travel on increasing un-ID'd stack sizes

### Exploration & Travel

- **fully-recover** - Rests until negative status effects clear
- **go-up-macro** - Enhanced Cntl-E macro with orb run mechanics: HP-based monster ignore for fast+safe ascension
- **runrest-features** - Updates travel stops based on location/religion/recent shaft. Auto-searches when entering temple/gauntlet
- **safe-stairs** - Prevents accidental stair usage. Warns before entering V:5

### Quality of Life

- **answer-prompts** - Auto-answers certain prompts
- **dynamic-options** - Changes crawl settings based on XL, religion, race/class, etc.
- **fm-messages** - Messages rated 1-9 for importance. Configurable as force_more_message and flash_screen_message.
- **mute-messages** - Reduces message spam with configurable mute levels (light/moderate/heavy reduction)
- **startup** - Auto-sets skill targets, opens skills menu, saves/reloads skill targets by race+class

### Turncount-specific

_(disabled by default; enabled in the turncount config)_
- **announce-items** (Turncount) - Prints messages describing floor items like gold/wands/books as they come into view
- **bread-swinger** (Turncount) - Macro `5` to rest _X_ turns: Swinging your slowest weapon, or walking if that's slower
- **display-realtime** (Speedrun) - Every x seconds (default 60), display the current real time.

---

## Cherry-Picking Individual Features

Want to use just one feature without the full BRC system? The script `build/create_standalone_features.py` converts the feature modules to standalone files in `bin/standalone_features/` that can be copy-pasted into your RC. 

**Remember to merge hooks if you already have them defined!**

The generated files are always active and work independently of the full BRC system.

## Pickup & Alert Feature

BRC's largest feature. It provides smart autopickup of item upgrades, and generates alerts for noteworthy items.
The goal is to enable confident "o-tabbing" without inspecting every dropped item, or searching each floor to make sure you didn't overlook anything.

### How It Works

- **Alerts** - One-line messages that stop travel and stand out visually
- **No spam** - alerts won't fire for identical/inferior items
- **Smart** - adjusts behavior to your inventory and character progression
- **Configurable** - lots of config values for which alerts are active, when they fire, and when to do a force_more.
  - To adjust the overall frequency of alerts, configure: `Alert.armour_sensitivity` and `Alert.weapon_sensitivity`
  - _(Advanced)_ For detailed tuning of alert behavior, see heuristics in `Tuning` and `BrandBonus`.

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

---

## Configuration Guide

### 1. Disabling Features

**Method 1 (Simple): Delete the code**

- Just delete the feature module from your RC:
  - Delete everything from: `#### Begin <feature_name>` - `#### End <feature_name>`
  - No other changes needed

**Method 2 (Flexible): Disable via config**

- Add `disabled = true` to the corresponding feature section of your config.
```lua
  my_config = {

    ["alert-monsters"] = { disabled = true }

  } -- end my_config
```

### 2. Configuring Features

Each feature defines its own `Config` table, containing options and default values.

Configuration for all features is intended to live at the top of `buehler.rc`. A "Main" config can specify a feature name and any of its options to override default values.
*(See all available config options in `lua/config/explicit.lua` - it's a lot though)*

**Ex:** The `inscribe-stats` feature inscribes items with their current stats (AC, EV, DPS, ...).
To disable this for weapons, add this to your config:

```lua
  my_config = {

    ["inscribe-stats"] = {
      inscribe_weapons = false, -- Don't maintain weapon info in the inscription 
      inscribe_armour = true,  -- This line is redundant, since the default value is true
    },

} -- end my_config
```

### 3. Multiple Configs

_(Feel free to delete any configs you don't want. No other changes needed.)_

BRC includes several pre-built configs. You can edit/remove any of them or create new ones.
Any table that includes `BRC_CONFIG_NAME = <config_name>` will be available as a config.

Included configs:
- **Custom**: Intended as the main config, or maybe the only one. It includes options that seem the most likely to be configured.
- **Testing**: Turns on debug messages, and disables any features not explicitly configured.
- **Explicit**: A big config with every field defined, set to default values.
- _**Others**_:
  - **Turncount**: For low-turncount runs (disable autopickup, auto-display info for items in view)
  - **Speed**: For speed runs (reduced prompts + alerts)

### 4. Set which config to load

`BRC.Config.to_use` is at the top of `buehler.rc` (and `lua/core/_header.lua`). Set the config name there.

```lua
-- Specify a config by name, or "ask" to prompt at start of each new game
BRC.Config.use_config = "ask"
```

### 5. Add Your Own Features

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
function my_feature.c_assign_invletter(it)
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

---

## Misc

### File Structure

```
bin/                    # Pre-built RC files
├── buehler.rc            # Single-file result of all files
├── standalone_features/  # Each feature, with its dependencies, as a self-contained file
|   └── *.rc                # One RC file per feature, including crawl hooks
build/                  # Python scripts to generate bin/
rc/                     # RC file components
lua/                    # Lua files
├── core/                   # Core BRC system
│   ├── _header_.lua            # Stuff at top of buehler.rc, before config 
│   ├── brc.lua                 # Main coordinator
│   ├── config.lua              # Config definitions
│   ├── data.lua                # Manages persistent data + backup
│   ├── util.lua                # General functions available to features
│   ├── constants.lua           # Constants from crawl
│   └── ...                     # BRC Core features; don't remove
├── features/               # Feature modules
│   ├── _template.lua           # Template for new features
│   ├── pickup-alert/           # Pickup-Alert (multi-file feature)
│   └── ...                     # Other features
```

---

### In-Game Commands

Use the Lua interpreter (open with the `~` key) for these commands:

```lua
-- BRC management
BRC.active = false                    -- Disable entire BRC system
BRC.init("config-name")               -- Load a diff config (keep persistent data)
BRC.reset()                           -- Reset everything and select a config
BRC.reset("config-name")              -- Reset and load config by name
BRC.Data.reset()                      -- Reset persistent data
BRC.unregister("feature-name")        -- Disable a feature
c_persist.BRC = nil                   -- Delete any BRC cross-game data (training targets + config)

-- Debugging
BRC.dump()                        -- Print all persistent data
BRC.dump(1)                       -- Print a lot more debugging info
BRC.Config.mpr.show_debug_messages = true -- Enable debug output
```

---

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
  - **Switching between characters** does not re-execute lua files. `init()` will be called, so all locals are set to defaults in init functions.
  It's safest to use `buehler.rc` as a single file, but using `init.txt` will still work, and provides better line numbers in error messages.
  It's generally good to restart crawl when switching between characters, to ensure all lua code re-executes.
  - **Regex issues**: Some regular expression patterns require PCRE (not POSIX). If you build crawl locally, use build flag `BUILD_PCRE=y`.
  - **Emojis**: Webtiles has a good font with solid emoji support. AFAICT MacOS doesn't, so I configure `BRC.Config.emojis = false` locally.
  If you have one, define it in `rc/display.rc`, and LMK!

**RC syntax errors**: If you edit the RC and get an error on startup: note the error and line number, and try to immediately close/fix it/try again with the same character. You may be prompted to restore data from backup.

**Data backup in `c_persist`**: BRC keeps a backup of persistent data in crawl's `c_persist` table. Backup data is only available for the most recent game. It'll automatically restore if no turns have passed since the backup was taken. Otherwise it'll ask for confirmation.

### Error Handling

- When a feature throws an error, BRC will offer to disable the feature.
- If errors occur in the core code (rare), BRC may offer to disable a hook. This would impact all features using that hook,
so it's recommended to determine the feature causing the error and disable it.
- In both cases, it's probably worth answering No once, then disabling things only if the error persists. Restarting crawl will re-enable all features and hooks.

## Resources

### DCSS Documentation
- [RC Options Guide](http://crawl.akrasiac.org/docs/options_guide.txt)
- [Lua Integration Guide](https://github.com/gammafunk/dcss-rc#1-include-the-rc-or-lua-file-in-your-rc)
- [DCSS Lua API](https://doc.dcss.io/index.html)

### Cool RC files / Sources of features
- Use this syntax to lookup a player's RC file:
  - [http://crawl.akrasiac.org/rcfiles/crawl-0.33/buehler.rc](http://crawl.akrasiac.org/rcfiles/crawl-0.33/buehler.rc)
  - [http://crawl.akrasiac.org/rcfiles/crawl-0.33/buehler.rc](http://crawl.akrasiac.org/rcfiles/crawl-git/buehler.rc)
- [gammafunk/dcss-rc](https://github.com/gammafunk/dcss-rc)
- [magus/dcss](https://github.com/magus/dcss)
- [linewriter1024/crawl-rc](https://github.com/linewriter1024/crawl-rc)
- [Other RC Examples](https://tavern.dcss.io/t/whats-in-your-rc-file/160/4)
