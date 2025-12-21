--- Explicit config: All config values from all features listed explicitly, set to defaults
-- Large feature config sections are at the end
-- @warning Since this lives at the top of the RC, it can't reference constants.lua or util/*.lua
--   So it must hardcode values like keycodes, where feature configs get to use BRC.KEYS, etc

brc_config_explicit = {
  BRC_CONFIG_NAME = "Explicit",

  ---- BRC Core values ----
  emojis = true,

  mpr = {
    show_debug_messages = false,
    logs_to_stderr = false,
  },

  dump = {
    max_lines_per_table = 200, -- Avoid huge tables (alert_monsters.Config.Alerts) in debug dumps
    omit_pointers = true, -- Don't dump functions and userdata (they only show a hex address)
  },

  unskilled_egos_usable = false, -- Does "Armour of <MagicSkill>" have an ego when skill is 0?

  --- How weapon damage is calculated for inscriptions+pickup/alert: (factor * DMG + offset)
  BrandBonus = {
    chaos = { factor = 1.15, offset = 2.0 }, -- Approximate weighted average
    distort = { factor = 1.0, offset = 6.0 },
    drain = { factor = 1.25, offset = 2.0 },
    elec = { factor = 1.0, offset = 4.5 },   -- 3.5 on avg; fudged up for AC pen
    entangle = { factor = 1.1, offset = 3 },
    flame = { factor = 1.25, offset = 0 },
    freeze = { factor = 1.25, offset = 0 },
    heavy = { factor = 1.8, offset = 0 },    -- Speed is accounted for elsewhere
    pain = { factor = 1.0, offset = you.skill("Necromancy") / 2 },
    spect = { factor = 1.7, offset = 0 },    -- Fudged down for increased incoming damage
    sunder = { factor = 1.2, offset = 0 },
    valour = { factor = 1.15, offset = 0 },
    venom = { factor = 1.0, offset = 5.0 },  -- 5 dmg per poisoning

    subtle = { -- Values to use for weapon "scores" (not damage)
      antimagic = { factor = 1.1, offset = 0 },
      concuss = { factor = 1.2, offset = 0 },
      devious = { factor = 1.1, offset = 0 },
      holy = { factor = 1.15, offset = 0 },
      penet = { factor = 1.3, offset = 0 },
      protect = { factor = 1.15, offset = 0 },
      reap = { factor = 1.3, offset = 0 },
      rebuke = { factor = 1.2, offset = 0 },
      vamp = { factor = 1.2, offset = 0 },
    },
  }, -- BrandBonus (do not remove this comment)


  hotkey = {
    key = { keycode = 13, name = "[Enter]" },
    skip_keycode = 27, -- ESC keycode
    equip_hotkey = true, -- Offer to equip after picking up equipment
    wait_for_safety = true, -- Don't expire the hotkey with monsters in view
    explore_clears_queue = true, -- Clear the hotkey queue on explore
    newline_before_hotkey = true, -- Add a newline before the hotkey message
  },

  ---- Feature configs ----
  ["announce-hp-mp"] = {
    disabled = false,
    dmg_flash_threshold = 0.20, -- Flash screen when losing this % of max HP
    dmg_fm_threshold = 0.30, -- Force more for losing this % of max HP
    always_on_bottom = false, -- Rewrite HP/MP meters after each turn with messages
    meter_length = 10, -- Number of pips in each meter

    Announce = {
      hp_loss_limit = 1, -- Announce when HP loss >= this
      hp_gain_limit = 4, -- Announce when HP gain >= this
      mp_loss_limit = 1, -- Announce when MP loss >= this
      mp_gain_limit = 2, -- Announce when MP gain >= this
      hp_first = false, -- Show HP first in the message
      same_line = true, -- Show HP/MP on the same line
      always_both = true, -- If showing one, show both
      very_low_hp = 0.10, -- At this % of max HP, show all HP changes and mute % HP alerts
    },

    HP_METER = { FULL = "❤️", PART = "❤️‍🩹", EMPTY = "🤍" },
    MP_METER = { FULL = "🟦", PART = "🔹", EMPTY = "➖" },

    init = function()
      if not BRC.Config.emojis then
        f_announce_hp_mp.Config.HP_METER = {
          BORDER = BRC.txt.white("|"),
          FULL = BRC.txt.lightgreen("+"),
          PART = BRC.txt.lightgrey("+"),
          EMPTY = BRC.txt.darkgrey("-"),
        } -- HP_METER (do not remove this comment)
        f_announce_hp_mp.Config.MP_METER = {
          BORDER = BRC.txt.white("|"),
          FULL = BRC.txt.lightblue("+"),
          PART = BRC.txt.lightgrey("+"),
          EMPTY = BRC.txt.darkgrey("-"),
        } -- MP_METER (do not remove this comment)
      end
    end,
  },

  ["answer-prompts"] = {
    disabled = false,
    -- No config; See answer-prompts.lua for Questions/Answers
  },

  ["announce-items"] = {
    disabled = true, -- Disabled by default. Intended only for turncount runs.
    announce_class = { "book", "gold", "jewellery", "misc", "missile", "potion", "scroll", "wand" },
    announce_glowing = true,
    announce_artefacts = true,
    max_gold_announcements = 3, -- Stop announcing gold after 3rd pile on screen
    announce_extra_consumables_wo_id = true, -- Announce when standing on not-id'd duplicates
  },

  ["bread-swinger"] = {
    disabled = true, -- Disable by default
    allow_plant_damage = false, -- Allow damaging plants to rest
    walk_delay = 50, -- ms delay between walk commands. Makes visuals less jarring. 0 to disable.
    alert_slow_weap_min = 1.4, -- Alert when finding the slowest weapon yet, starting at this delay.
    set_manual_slot_key = 53, -- (Cntl-5) Manually set which weapon slot to swing
    max_heal_perc = 90, -- Stop resting at this percentage of max HP/MP
    emoji = "🍞",
    init = function()
      if not BRC.Config.emojis then
        f_bread_swinger.Config.emoji = BRC.txt.cyan("---- ")
      end
    end,
  },

  ["color-inscribe"] = {
    disabled = false,
    -- No config; See color-inscribe.lua for COLORIZE_TAGS
  },

  ["display-realtime"] = {
    disabled = true, -- Disabled by default
    interval_s = 60, -- seconds between updates
    emoji = "🕒",
    init = function()
      if not BRC.Config.emojis then
        f_display_realtime.Config.emoji = BRC.txt.white("--")
      end
    end,
  },

  ["drop-inferior"] = {
    disabled = false,
    msg_on_inscribe = true, -- Show a message when an item is marked for drop
    hotkey_drop = true, -- BRC hotkey drops all items on the drop list
  },

  ["exclude-dropped"] = {
    disabled = false,
    not_weapon_scrolls = true, -- Don't exclude enchant/brand scrolls if holding enchantable weapon
  },

  ["fully-recover"] = {
    disabled = false,
  },

  ["inscribe-stats"] = {
    disabled = false,
    inscribe_weapons = true, -- Inscribe weapon stats on pickup
    inscribe_armour = true, -- Inscribe armour stats on pickup
    dmg_type = "unbranded", -- unbranded, plain, branded, scoring
  },

  ["misc-alerts"] = {
    disabled = false,
    preferred_god = "", -- Stop on first altar with this text (Ex. "Wu Jian"); nil or "" disables
    force_more_on_pref_altar = true, -- Force more message on first altar for preferred god
    save_with_msg = true, -- Shift-S to save and leave yourself a message
    alert_low_hp_threshold = 35, -- % max HP to alert; 0 to disable
    alert_spell_level_changes = true, -- Alert when you gain additional spell levels
    alert_remove_faith = true, -- Reminder to remove amulet at max piety
    remove_faith_hotkey = true, -- Hotkey remove amulet
  },

  ["go-up-macro"] = {
    disabled = false,
    go_up_macro_key = 5, -- (Cntl-E) Key for "go up closest stairs" macro
    ignore_mon_on_orb_run = true, -- Ignore monsters on orb run
    orb_ignore_hp_min = 0.30, -- HP percent to stop ignoring monsters
    orb_ignore_hp_max = 0.70, -- HP percent to ignore monsters at min distance away (2 tiles)
  },

  ["quiver-reminders"] = {
    disabled = false,
    confirm_consumables = true,
    warn_diff_missile_turns = 10,
  },

  ["remind-id"] = {
    disabled = false,
    stop_on_scrolls_count = 2, -- Stop when largest un-ID'd scroll stack increases and is >= this
    stop_on_pots_count = 3, -- Stop when largest un-ID'd potion stack increases and is >= this
    read_id_hotkey = true, -- Put read ID on hotkey
    emoji = "🎁",
    init = function()
      if not BRC.Config.emojis then
        f_remind_id.Config.emoji = BRC.txt.magenta("?")
      end
    end,
  },

  ["runrest-features"] = {
    disabled = false,
    after_shaft = true, -- stop on stairs after being shafted, until returned to original floor
    ignore_altars = true, -- when you don't need a god
    ignore_portal_exits = true, -- don't stop explore on portal exits
    stop_on_hell_stairs = true, -- stop explore on hell stairs
    stop_on_pan_gates = true, -- stop explore on pan gates
    temple_search = true, -- on entering or exploring temple, auto-search
    gauntlet_search = true, -- on entering or exploring gauntlet, auto-search with filters
    necropolis_search = true, -- on exploring necropolis, auto-search with filters
  },

  ["safe-consumables"] = {
    disabled = false,
    -- No config;See safe-consumables.lua for NO_INSCRIPTION_NEEDED scrolls/potions
  },

  ["safe-stairs"] = {
    disabled = false,
    warn_backtracking = true, -- Warn if immediately taking stairs twice in a row
    warn_v5 = true, -- Prompt before entering Vaults:5
  },

  ["startup"] = {
    disabled = false,
    -- Save current training targets and config, for race/class
    macro_save_key = 20, -- (Cntl-T) Keycode to save training targets and config
    save_training = true, -- Allow save/load of race/class training targets
    save_config = true, -- Allow save/load of BRC config
    prompt_before_load = false, -- Prompt before loading in a new game with same race+class
    allow_race_only_saves = false, -- Also save for race only (always prompts before loading)
    allow_class_only_saves = false, -- Also save for class only (always prompts before loading)

    -- Remaining values only used if no training targets were loaded by race/class
    show_skills_menu = false, -- Show skills menu on startup

    -- Settings to set skill targets, regardless of race/class
    set_all_targets = true, -- Set all targets, even if only focusing one
    focus_one_skill = true, -- Focus one skill at a time, even if setting all targets
    auto_set_skill_targets = {
      { "Stealth", 2.0 }, -- First, focus stealth to 2.0
      { "Fighting", 2.0 }, -- If already have stealth, focus fighting to 2.0
    },

    -- For non-spellcasters, add preferred weapon type as 3rd skill target
    init = function()
      if you.skill("Spellcasting") == 0 then
        local wpn_skill = BRC.you.top_wpn_skill()
        if wpn_skill then
          local t = f_startup.Config.auto_set_skill_targets
          t[#t + 1] = { wpn_skill, 6.0 }
        end
      end
    end,
  },

  ["weapon-slots"] = {
    disabled = false,
    -- No config
  },

  ---- Large config sections ----
  ["dynamic-options"] = {
    disabled = false,
    meaningful_spellcasting_skill = 5, -- Skill level to switch on "spellcaster-specific" options

    -- XL-based force more messages: active when XL <= specified level
    xl_force_mores = {
      { pattern = "monster_warning:wielding.*of electrocution", xl = 5 },
      { pattern = "You.*re more poisoned", xl = 7 },
      { pattern = "^(?!.*Your?).*speeds? up", xl = 10 },
      { pattern = "danger:goes berserk", xl = 18 },
      { pattern = "monster_warning:carrying a wand of", xl = 15 },
    },

    race_options = {
      Gnoll = function()
        BRC.opt.message_mute("intrinsic_gain:skill increases to level", true)
      end,
    },

    class_options = {
      Hunter = function()
        crawl.setopt("view_delay = 30")
      end,
      Shapeshifter = function()
        BRC.opt.autopickup_exceptions("<flux bauble", true)
      end,
    },

    god_options = {
      ["No God"] = function(joined)
        BRC.opt.force_more_message("Found.*the Ecumenical Temple", not joined)
        BRC.opt.flash_screen_message("Found.*the Ecumenical Temple", joined)
        BRC.opt.runrest_stop_message("Found.*the Ecumenical Temple", joined)
      end,
      Beogh = function(joined)
        BRC.opt.runrest_ignore_message("no longer looks.*", joined)
      end,
      Cheibriados = function(joined)
        BRC.util.add_or_remove(BRC.RISKY_EGOS, "Ponderous", not joined)
      end,
      Jiyva = function(joined)
        BRC.opt.flash_screen_message("god:splits in two", joined)
        BRC.opt.message_mute("You hear a.*(slurping|squelching) noise", joined)
      end,
      Lugonu = function(joined)
        BRC.util.add_or_remove(BRC.RISKY_EGOS, "distort", not joined)
      end,
      Trog = function(joined)
        BRC.util.add_or_remove(BRC.ARTPROPS_BAD, "-Cast", not joined)
        BRC.util.add_or_remove(BRC.RISKY_EGOS, "antimagic", not joined)
      end,
      Xom = function(joined)
        BRC.opt.flash_screen_message("god:", joined)
      end,
    },
  },

  ["fm-messages"] = {
    disabled = false,
    force_more_threshold = 6, -- How many force_more_messages; 1=many; 10=none
    flash_screen_threshold = 1,

    --- A list of all messages to respond to. The first value is the message importance.
    -- Use the above thresholds to adjust how the messages are responded to.
    -- General guidance on values:
    -- 8-9: Prevent accidental button press
    -- 5-7: Make sure you see it
    -- 3-4: Important to notice
    -- 1-2: Good to know
    messages = {
      -- Significant spells/effects ending
      {9, "life is in your own"}, -- Death's Door
      {7, "time is.*running out"}, -- Death's Door
      {7, "is no longer charmed"},
      {7, "You.*re starting to lose your buoyancy"},
      {5, "unholy channel is weakening"}, -- Death channel
      {2, "You feel stable"}, -- Cancelled tele

      -- Monsters doing things / Dangerous abilities
      {9, "you stand beside yourself"}, -- Mara
      {9, "sudden wrenching feeling in your soul"}, -- Mara
      {8, "monster_warning:wielding.*of distortion"},
      {8, "begins to recite a word of recall"},
      {7, "The air around.*erupts in flames"},
      {7, "The air twists around and violently strikes you in flight"},
      {7, "You feel.*(?<!less)( haunted| rot| vulnerable)"},
      {6, "wretched star pulses"},
      {6, "Strange energies course through your body"},
      {5, "Deactivating autopickup"},
      {4, "You feel your power leaking away"},
      {4, "The.*offers itself to Yredelemnul"},
      {3, "doors? slams? shut"},
      {3, "blows.*on a signal horn"},
      {3, "Your?.*suddenly stops? moving"},
      {3, "danger:corrodes you"},
      {3, "Your damage is reflected back at you"},
      {3, "^(?!Your? ).*reflects"},
      {2, "The forest starts to sway and rumble"},
      {1, "Its appearance distorts for a moment"},

      -- Crowd control
      {9, "You.*(?<!( too|less)) confused"},
      {9, "You .*(slow.*down|lose consciousness)"},
      {9, "infuriates you"},
      {8, "hits you .* distortion"},
      {8, "Space .* around you"},
      {8, "surroundings become eerily quiet"},
      {9, "Your limbs are stiffening"},
      {4, "You .* (blown|knocked back|mesmerised|trampled|stumble backwards|encased)"},
      {4, "A sentinel's mark forms upon you"},
      {3, "Your magical (effects|defenses) are (unraveling|stripped away)"},
      {3, "You stop (a|de)scending the stairs"},
      {3, "The pull of.*song draws you forward"},
      {3, "engulfs you in water"},

      -- Clouds
      {9, "danger:(calcify|mutagenic)"},
      {9, "You.*re engulfed in.*miasma"},
      {1, "Miasma billows from the"},

      -- You Screwed Up
      {7, "is no longer ready"},
      {7, "You really shouldn't be using"},
      {6, "You don't have enough magic to cast this spell"},
      {4, "Your body shudders with the violent release"},
      {4, "power of Zot"},

      -- Found something important
      {7, "Found.*the Ecumenical Temple"},
      {7, "Found.*(treasure|bazaar|ziggurat)"},
      {6, ".*resides here"},
      {6, "You have a vision of.*gates?"},
      {2, "timed_portal:.*"},
      {1, "You pick up the .* (gem|rune) and feel its "},

      -- Translocations
      {9, "danger:sense of stasis"},
      {9, "Your surroundings.*(different|flicker)"},
      {6, "You.*re suddenly pulled into a different region"},
      {5, "danger:You feel strangely .*stable"},
      {4, "You blink"},
      {3, "delaying your translocation"},

      -- Big damage
      {7, "You.*re lethally poisoned"},
      {7, "danger:You convulse"},
      {7, "you terribly"},

      -- FYI
      {6, "seems mollified"},
      {6, "You have finished your manual"},

      -- Unexpected monsters
      {8, "appears in a (shower|flash)"},
      {8, "appears out of thin air"},
      {7, "You sense the presence of something unfriendly"},
      {7, "Wisps of shadow swirl around"},

      -- Misc
      {9, "god:wrath finds you"},
      {9, "The walls disappear"},
      {7, "hell effect:.*"},

      -- Gods
      {9, "Press the corresponding letter to learn more about a god"},
      {7, "god:Ashenzari invites you to partake"},
      {7, "god:You are shrouded in an aura of darkness"},
      {7, "god:You.*bleed smoke"},
      {7, "god:Your shadow.*tangibly mimics your actions"},
      {8, "god:Fedhas invokes the elements against you"},
      {7, "god:Jiyva alters your body"},
      {7, "god:will now unseal the treasures of the Slime Pits"},
      {7, "god:Kikubaaqudgha will grant you"},
      {7, "god:Lugonu will now corrupt your weapon"},
      {9, "god:Lugonu sends minions to punish you"},
      {9, "god:Okawaru sends forces against you"},
      {7, "god:grants you (a gift|a weapon)"},
      {1, "god:You are surrounded by a storm which can block enemy attacks"},
      {1, "god:resistances upon receiving elemental damage"},
      {8, "god:Your divine shield fades away"},
      {7, "god:Your divine shield starts to fade"},
      {8, "god:You feel less resistant to hostile enchantments"},
      {7, "god:You feel the effects of Trog's Hand fading"},
      {9, "staircase.*moves"},
      {9, "Some monsters swap places"},
      {7, "god:soul is no.* ripe for the taking"},
      {7, "god:dark mirror aura disappears"},
      {7, "god:will now cure all your mutations"},
    },

    --- Remove these default force_more_message patterns
    remove_more_messages = {
      "You have reached level",
      "Marking area around .* as unsafe",
      "welcomes you( back)?!",
      "upon you is lifted",
      "You pick up the .* gem and feel its .* weight",
      "You pick up the .* rune and feel its power",
      "The lock glows eerily",
      "Heavy smoke blows from the lock",
      "The gate opens wide",
      "With a soft hiss the gate opens wide",
      "grants you (a gift|throwing weapons|a weapon)",
      "You finish merging with the rock",
      --"You bow before the missionary of Beogh",
      --"You .* the altar of",
    },
  },

  ["mute-messages"] = {
    disabled = false,
    mute_level = 2,
    messages = {
      -- Light reduction; unnecessary messages
      [1] = {

        -- Unnecessary
        "You now have .* runes",
        "to see all the runes you have collected",
        "A chill wind blows around you",
        "An electric hum fills the air",
        "You reach to attack",

        -- Interface
        "for a list of commands and other information",
        "Marking area around",
        "(Reduced|Removed|Placed new) exclusion",
        "You can access your shopping list by pressing '\\$'",

        -- Wielding weapons
        "Your .* exudes an aura of protection",
        "Your .* glows with a cold blue light",

        -- Monsters /Allies / Neutrals
        "dissolves into shadows",
        "You swap places",
        "Your spectral weapon disappears",

        -- Spells
        "Your foxfire dissipates",

        -- Religion
        "accepts your kill",
        "is honoured by your kill",
      },

      -- Moderate reduction; potentially confusing but no info lost
      [2] = {
        -- Allies / monsters
        "Ancestor HP restored",
        "The (bush|fungus|plant) (looks sick|begins to die|is engulfed|is struck)",
        "evades? a web",
        "is (lightly|moderately|heavily|severely) (damaged|wounded)",
        "is almost (dead|destroyed)",

        -- Interface
        "Use which ability\\?",
        "Evoke which item\\?$",
        "Shift\\-Dir \\- straight line",

        -- Books
        "You pick up (?!a manual).*and begin reading",
        "Unfortunately\\, you learn nothing new",

        -- Ground items / features
        "There is a.*(door|web).*here",
        "You see here .*(corpse|skeleton)",
        "You now have \\d+ gold piece",
        "You enter the shallow water",
        "Moving in this stuff is going to be slow",

        -- Religion
        "Your shadow attacks",
      },

      -- Heavily reduced messages for speed runs
      [3] = {
        "No target in view",
        "You (bite|headbutt|kick)",
        "You (burn|freeze|drain)",
        "You block",
        "but do(es)? no damage",
        "misses you",
      },
    },
  }, -- mute-messages

  ["pickup-alert"] = {
    disabled = false,
    Pickup = {
      armour = true,
      weapons = true,
      weapons_pure_upgrades_only = true, -- Only pick up better versions of same exact weapon
      staves = true,
    },

    Alert = {
      armour_sensitivity = 1.0, -- Adjust all armour alerts; 0 to disable all (range 0.5-2.0)
      weapon_sensitivity = 1.0, -- Adjust all weapon alerts; 0 to disable all (range 0.5-2.0)
      orbs = true,
      staff_resists = true,
      talismans = true,
      first_ranged = true,
      first_polearm = true,
      stacked_items = true, -- Check items hidden under stacks, to alert without visiting the stack

      -- Alert the first time each item is found. Can require training with OTA_require_skill.
      one_time = {
        "wand of digging", "buckler", "kite shield", "tower shield", "crystal plate armour",
        "gold dragon scales", "pearl dragon scales", "storm dragon scales", "shadow dragon scales",
        "quick blade", "demon blade", "eudemon blade", "double sword", "triple sword",
        "broad axe", "executioner's axe",
        "demon whip", "eveningstar", "giant spiked club", "morningstar", "sacred scourge",
        "lajatang", "bardiche", "demon trident", "partisan", "trishula",
        "hand cannon", "triple crossbow",
      },
      OTA_require_skill = { weapon = 2, armour = 2.5, shield = 0 }, -- No alert if skill < this

      hotkey_travel = true,
      hotkey_pickup = true,

      allow_arte_weap_upgrades = true, -- If false, won't alert weapons as upgrades to an artefact

      -- Only alert a plain talisman if its min_skill <= Shapeshifting + talisman_lvl_diff
      talisman_lvl_diff = you.class() == "Shapeshifter" and 27 or 6,

      -- Which alerts generate a force_more
      More = {
        early_weap = false, -- Good weapons found early
        upgrade_weap = false, -- Better DPS / weapon_score
        weap_ego = false, -- New or diff egos
        body_armour = false,
        shields = true,
        aux_armour = false,
        armour_ego = true, -- New or diff egos
        high_score_weap = false, -- Highest damage found
        high_score_armour = true, -- Highest AC found
        one_time_alerts = true,
        artefact = false, -- Any artefact
        trained_artefacts = true, -- Artefacts where you have corresponding skill > 0
        orbs = false, -- Unique orbs
        talismans = you.class() == "Shapeshifter", -- True for shapeshifter, false for everyone else
        staff_resists = false, -- When a staff gives a missing resistance
        autopickup_disabled = true, -- Alerts for autopickup items, when autopickup is disabled
      }, -- Alert.More
    }, -- Alert

    ---- Heuristics for tuning the pickup/alert system. Advanced behavior customization.
    Tuning = {
      --[[
        Tuning.Armour: Magic numbers for the armour pickup/alert system.
        For armour with different encumbrance, alert when ratio of gain/loss (AC|EV) is > value
        Lower values mean more alerts. gain/diff/same/lose refers to egos.
        min_gain/max_loss block alerts for new egos, when AC or EV delta is outside limits
        ignore_small: if abs(AC+EV) <= this, ignore ratios and alert any gain/diff ego
      --]]
      Armour = {
        Lighter = {
          gain_ego = 0.6,
          new_ego = 0.7,
          diff_ego = 0.9,
          same_ego = 1.2,
          lost_ego = 2.0,
          min_gain = 3.0,
          max_loss = 4.0,
          ignore_small = 3.5,
        }, -- Tuning.Armour.Lighter

        Heavier = {
          gain_ego = 0.4,
          new_ego = 0.5,
          diff_ego = 0.6,
          same_ego = 0.7,
          lost_ego = 2.0,
          min_gain = 3.0,
          max_loss = 8.0,
          ignore_small = 5,
        }, -- Tuning.Armour.Heavier

        encumb_penalty_weight = 0.7, -- [0-2.0] Penalty to heavy armour when training magic/ranged
        early_xl = 6, -- Alert all usable runed body armour if XL <= early_xl
        diff_body_ego_is_good = false, -- More alerts for diff armour ego (skips min_gain check)
      }, -- Tuning.Armour

      --[[
        Tuning.Weap: Magic numbers for the weapon pickup/alert system, namely:
          1. Cutoffs for pickup/alert weapons (when DPS ratio exceeds a value)
          2. Cutoffs for when alerts are active (XL, skill_level)
        Pickup/alert system will try to upgrade ANY weapon in your inventory.
        "DPS ratio" is (new_weap_score / inventory_weap_score). Score considers DPS/brand/accuracy.
      --]]
      Weap = {
        Pickup = {
          add_ego = 1.0, -- Pickup weapon that gains a brand if DPS ratio > add_ego
          same_type_melee = 1.2, -- Pickup melee weap of same school if DPS ratio > same_type_melee
          same_type_ranged = 1.1, -- Pickup ranged weap if DPS ratio > same_type_ranged
          accuracy_weight = 0.25, -- Treat +1 Accuracy as +accuracy_weight DPS
        }, -- Tuning.Weap.Pickup

        Alert = {
          -- Alerts for weapons not requiring an extra hand
          pure_dps = 1.0, -- Alert if DPS ratio > pure_dps
          gain_ego = 0.8, -- Gaining ego; Alert if DPS ratio > gain_ego
          new_ego = 0.8, -- Get ego not in inventory; Alert if DPS ratio > new_ego
          low_skill_penalty_damping = 8, -- [0-20] Reduce penalty to weap of lower-trained schools

          -- Alerts for 2-handed weapons, when carrying 1-handed
          AddHand = {
            ignore_sh_lvl = 4.0, -- Treat offhand as empty if shield_skill < ignore_sh_lvl
            add_ego_lose_sh = 0.8, -- Alert 1h -> 2h (using shield) if DPS ratio > add_ego_lose_sh
            not_using = 1.0, --  Alert 1h -> 2h (not using 2nd hand) if DPS ratio > not_using
          },

          -- Alerts for good early weapons of all types
          Early = {
            xl = 7, -- Alert early weapons if XL <= xl
            skill = { factor = 1.5, offset = 2.0 }, -- Ignore weap w skill_diff > XL*factor+offset
            branded_min_plus = 4, -- Alert branded weapons with plus >= branded_min_plus
          },

          -- Alerts for particularly strong ranged weapons
          EarlyRanged = {
            xl = 14, -- Alert strong ranged weapons if XL <= xl
            min_plus = 7, -- Alert ranged weapons with plus >= min_plus
            branded_min_plus = 4, -- Alert branded ranged weapons with plus >= branded_min_plus
            max_shields = 8.0, -- Alert 2h ranged despite  shield, if shield_skill <= max_shields
          },
        }, -- Tuning.Weap.Alert
      }, -- Tuning.Weap
    }, -- Tuning

    AlertColor = {
      weapon = { desc = "magenta", item = "yellow", stats = "lightgrey" },
      body_arm = { desc = "lightblue", item = "lightcyan", stats = "lightgrey" },
      aux_arm = { desc = "lightblue", item = "yellow" },
      orb = { desc = "green", item = "lightgreen" },
      talisman = { desc = "green", item = "lightgreen" },
      misc = { desc = "brown", item = "white" },
    }, -- AlertColor

    Emoji = {
      RARE_ITEM = "💎",
      ARTEFACT = "💠",
      ORB = "🔮",
      TALISMAN = "🧬",
      STAFF_RES = "🔥",

      WEAPON = "⚔️",
      RANGED = "🏹",
      POLEARM = "🔱",
      TWO_HAND = "✋🤚",

      EGO = "✨",
      ACCURACY = "🎯",
      STRONGER = "💪",
      STRONGEST = "💪💪",
      LIGHTER = "⏬",
      HEAVIER = "⏫",

      AUTOPICKUP_ITEM = "👍",
    }, -- Emoji (do not remove this comment)

    init = function()
      if not BRC.Config.emojis then
        f_pickup_alert.Config.Emoji = {}
      end
    end,
  }, -- pickup-alert

  ["alert-monsters"] = {
    disabled = false,
    sensitivity = 1.0, -- 0 to disable all; at 2.0, alerts will fire at 1/2 HP
    pack_timeout = 10, -- turns to wait before repeating a pack alert. 0 to disable
    disable_alert_monsters_in_zigs = true, -- Disable dynamic force_mores in Ziggurats
    debug_alert_monsters = false, -- Get a message when alerts toggle off/on

    Alerts = {
      { name = "always_fm",
        pattern = {
          -- High damage/speed
          "flayed ghost", "juggernaut", "orbs? of (entropy|fire|winter)",
          --Summoning
          "boundless tesseract", "demonspawn corrupter", "draconian stormcaller", "dryad",
          "guardian serpent", "halazid warlock", "shadow demon", "spriggan druid", "worldbinder",
          --Dangerous abilities
          "iron giant", "merfolk aquamancer", "nekomata", "shambling mangrove", "starflower",
          "torpor snail", "water nymph", "wretched star", "wyrmhole",
          --Dangerous clouds
          "apocalypse crab", "catoblepas",
        } },

      { name = "always_flash", flash_screen = true,
        pattern = {
          -- Noteworthy abilities
          "air elemental", "elemental wellspring", "ghost crab", "ironbound convoker",
          "vault guardian", "vault warden", "wendigo",
          -- Displacement
          "deep elf knight", "swamp worm",
          -- Summoning
          "deep elf elementalist",
          -- Agony
          "death knight", "imperial myrmidon", "necromancer",
        } },

      -- Early game Dungeon problems for chars with low mhp. (adder defined below)
      { name = "30hp", cond = "hp", cutoff = 30,
        pattern = { "hound", "gnoll" } },

      { name = "mid_game_packs", cutoff = 90, is_pack = true,
        pattern = { "boggart", "dream sheep" } },

      -- Monsters dangerous until a certain point
      { name = "xl_7", cond = "xl", cutoff = 7,
        pattern = { "orc wizard" } },
      { name = "xl_12", cond = "xl", cutoff = 12,
        pattern = { "hydra", "bloated husk" } },

      -- Monsters that can hit for ~50% of hp from range with unbranded attacks
      { name = "40hp", cond = "hp", cutoff = 40,
        pattern = { "orc priest" } },
      { name = "50hp", cond = "hp", cutoff = 50,
        pattern = { "manticore", "orc high priest" } },
      { name = "60hp", cond = "hp", cutoff = 60,
        pattern = { "centaur(?! warrior)", "cyclops", "orc knight", "yaktaur(?! captain)" } },
      { name = "70hp_melai", cond = "hp", cutoff = 70, is_pack = true,
        pattern = "meliai" },
      { name = "80hp", cond = "hp", cutoff = 80,
        pattern = { "gargoyle" } },
      { name = "90hp", cond = "hp", cutoff = 90,
        pattern = { "deep elf archer", "tengu conjurer" } },
      { name = "110hp", cond = "hp", cutoff = 110,
        pattern = { "cacodemon", "centaur warrior", "deep elf high priest",
                    "deep troll earth mage", "eye of devastation", "hellion", "stone giant",
                    "sun moth", "yaktaur captain" } },
      { name = "120hp", cond = "hp", cutoff = 120,
        pattern = { "magenta draconian", "thorn hunter", "quicksilver (dragon|elemental)" } },
      { name = "160hp", cond = "hp", cutoff = 160,
        pattern = { "brimstone fiend", "deep elf sorcererhell sentinal",
                    "draconian (knight|scorcher)", "war gargoyle" } },
      { name = "200hp", cond = "hp", cutoff = 200,
        pattern = { "(deep elf|draconian) annihilator", "iron (dragon|elemental)" } },

      -- Monsters that can crowd-control you without sufficient willpower
      -- Cutoff ~10% for most spells; lower for more significant spells like banish
      { name = "willpower2", cond = "will", cutoff = 2,
        pattern = { "basilisk", "naga ritualist", "vampire(?! (bat|mage|mosquito))",
                    "sphinx marauder" } },
      { name = "willpower3", cond = "will", cutoff = 3,
        pattern = { "cacodemon", "death knight", "deep elf (demonologist|sorcerer|archer)",
                    "draconian shifter", "fenstrider witch", "glowing orange brain",
                    "guardian sphinx", "imperial myrmidon", "iron elemental", "occultist",
                    "merfolk siren", "nagaraja", "ogre mage", "orc sorcerer", "satyr",
                    "vampire knight", "vault sentinel" } },
      { name = "willpower3_great_orb_of_eyes", cond = "will", cutoff = 3, is_pack = true,
        pattern = "great orb of eyes" },
      { name = "willpower3_golden_eye", cond = "will", cutoff = 3, is_pack = true,
        pattern = "golden eye" },
      { name = "willpower4", cond = "will", cutoff = 4,
        pattern = { "merfolk avatar", "tainted leviathan", "nargun" } },

      -- Brain feed with low int
      { name = "brainfeed", cond = "int", cutoff = 6,
        pattern = { "glowing orange brain", "neqoxec" } },

      -- Alert if no resist and HP below cutoff
      { name = "pois_30", cond = "pois", cutoff = 30,
        pattern = { "adder" } },
      { name = "pois_80", cond = "pois", cutoff = 80,
        pattern = { "golden dragon", "green draconian", "swamp dragon" } },
      { name = "pois_120", cond = "pois", cutoff = 120,
        pattern = { "fenstrider witch", "green death", "naga mage", "nagaraja" } },
      { name = "pois_140", cond = "pois", cutoff = 140,
        pattern = { "tengu reaver" } },

      { name = "elec_40", cond = "elec", cutoff = 40, is_pack = true,
        pattern = "electric eel" },
      { name = "elec_80", cond = "elec", cutoff = 80,
        pattern = { "raiju", "shock serpent", "spark wasp" } },
      { name = "elec_120", cond = "elec", cutoff = 120,
        pattern = { "black draconian", "blizzard demon", "deep elf zephyrmancer",
                    "storm dragon", "tengu conjurer" } },
      { name = "elec_140", cond = "elec", cutoff = 140,
        pattern = { "electric golem", "servants? of whisper", "spriggan air mage",
                    "tengu reaver", "titan" } },
      { name = "elec_140_pack", cond = "elec", cutoff = 140, is_pack = true,
        pattern = { "ball lightning" } },

      { name = "corr_60", cond = "corr", cutoff = 60,
        pattern = { "acid dragon" } },
        { name = "caustic_shrike", cond = "corr", cutoff = 120, is_pack = true,
        pattern = { "caustic shrike" } },
      { name = "corr_140", cond = "corr", cutoff = 140,
        pattern = { "demonspawn corrupter", "entropy weaver", "moon troll", "tengu reaver" } },

      { name = "fire_60", cond = "fire", cutoff = 60,
        pattern = { "fire crab", "hell hound", "lava snake", "lindwurm", "steam dragon" } },
      { name = "fire_100", cond = "fire", cutoff = 100,
        pattern = { "deep elf pyromancer", "efreet", "smoke demon", "sun moth" } },
      { name = "fire_120", cond = "fire", cutoff = 120,
        pattern = { "demonspawn blood saint", "hell hog", "hell knight", "molten gargoyle",
                    "ogre mage", "orc sorcerer", "red draconian" } },
      { name = "fire_140", cond = "fire", cutoff = 140,
        pattern = { "balrug" } },
      { name = "fire_160", cond = "fire", cutoff = 160,
        pattern = { "fire dragon", "fire giant", "golden dragon", "ophan", "salamander tyrant",
                    "tengu reaver", "will-o-the-wisp" } },
      { name = "fire_240", cond = "fire", cutoff = 240,
        pattern = { "crystal (guardian|echidna)", "draconian scorcher", "hellephant" } },

      { name = "cold_80", cond = "cold", cutoff = 80,
        pattern = { "rime drake" } },
      { name = "cold_120", cond = "cold", cutoff = 120,
        pattern = { "blizzard demon", "bog body", "demonspawn blood saint",
                   "ironbound frostheart", "white draconian" } },
      { name = "shard_shrike", cond = "cold", cutoff = 120, is_pack = true,
        pattern = { "shard shrike" } },
      { name = "cold_160", cond = "cold", cutoff = 160,
        pattern = { "draconian knight", "frost giant", "golden dragon",
                    "ice dragon", "tengu reaver" } },
      { name = "cold_180", cond = "cold", cutoff = 180,
        pattern = { "(?<!dread)(?<!ancient) lich", "lich king" } },
      { name = "cold_240", cond = "cold", cutoff = 240,
        pattern = { "crystal (guardian|echidna)" } },

      { name = "drain_100", cond = "drain", cutoff = 100,
        pattern = { "orc sorcerer" } },
      { name = "drain_120", cond = "drain", cutoff = 120,
        pattern = { "necromancer" } },
      { name = "drain_150", cond = "drain", cutoff = 150,
        pattern = { "demonspawn blood saint", "revenant" } },
      { name = "drain_190", cond = "drain", cutoff = 190,
        pattern = { "shadow dragon" } },
    }, -- fm_patterns (do not remove this comment)

    init = function()
      local alert_list = f_alert_monsters.Config.Alerts

      -- Mutators (only flash if immune)
      util.append(alert_list, {
        name = "malmutate", cond = "mut", cutoff = 1, flash_screen = BRC.you.mutation_immune(),
        pattern = { "cacodemon", "neqoxec", "shining eye" }
      })

      -- Conditionally add miasma monsters
      if not BRC.you.miasma_immune() then
        util.append(alert_list, {
          name = "miasma", cond = "always", cutoff = 0,
          pattern = { "death drake", "tainted leviathan", "putrid mouth" }
        })
      end

      -- Conditionally add tormentors
      if not you.torment_immune() then
        util.append(alert_list, {
          name = "torment", cond = "always", cutoff = 0,
          pattern = { "alderking", "curse (toe|skull)", "Fiend", "(dread|ancient) lich",
                      "lurking horror", "mummy priest", "royal mummy", "tormentor", "tzitzimi" }
        })
      end
    end,
  }, -- alert-monsters

} -- brc_config_explicit (do not remove this comment)
