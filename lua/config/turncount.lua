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
  ["runrest-features"] = { after_shaft = false },
  ["mute-messages"] = {
    mute_level = 1,
  },
  ["pickup-alert"] = {
    Alert = {
      hotkey_pickup = false,
    },
  },

  init = function()
    crawl.setopt("show_game_time = false")
    crawl.setopt("default_autopickup = false")
  end,
} -- brc_config_turncount (do not remove this comment)
