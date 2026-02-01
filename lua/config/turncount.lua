--- Turncount Config Profile: For turncount runs

brc_config_turncount = {
  BRC_CONFIG_NAME = "Turncount",

  ["alert-monsters"] = {
    sensitivity = 1.25, -- 0 to disable all; at 2.0, alerts will fire at 1/2 HP
  },
  ["announce-items"] = {
    disabled = false,
  },
  ["bread-swinger"] = {
    disabled = false,
  },
  ["drop-inferior"] = {
    disabled = true,
  },
  ["fm-messages"] = {
    force_more_threshold = 5,
  },
  ["hotkey"] = {
    equip_hotkey = false,
  },
  ["inscribe-stats"] = {
    skip_dps = true,
  },
  ["mute-messages"] = {
    mute_level = 2,
  },
  ["runrest-features"] = {
    after_shaft = false
  },
  ["pickup-alert"] = {
    Pickup = {
      weapons = false,
    },
    Alert = {
      hotkey_travel = false,
      hotkey_pickup = false,
      one_time = {
        "distortion", "troll leather armour", "wand of digging",
        "Apportation", "Passage of Golubria", "Shatter", "Ignition", "Fire Storm", "Polar Vortex",
      },
      More = {
        armour_ego = false,
        shields = false,
      },
    },
  },
  ["safe-stairs"] = {
    warn_backtracking = false,
  },

  init = function()
    crawl.setopt("show_game_time = false")
    crawl.setopt("default_autopickup = false")
    crawl.setopt("explore_stop += shops") -- Adds an announcement with the shop name
    crawl.setopt("macros += M o zo") -- Disable autoexplore; cast spell 'o' instead
    crawl.setopt("autoinscribe += shield:!T")
    crawl.setopt("autopickup_exceptions ^= > stones?$") -- Don't highlight autopickup for stones

    for _, m in ipairs(f_pickup_alert.Config.Alert.More) do
      if m ~= "one_time_alerts" then
        f_pickup_alert.Config.Alert.More[m] = false
      end
    end
  end,
} -- brc_config_turncount (do not remove this comment)
