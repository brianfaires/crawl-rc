--- Turncount Config Profile: For turncount runs

brc_config_turncount = {
  BRC_CONFIG_NAME = "Turncount",

  ["alert-monsters"] = {
    sensitivity = 1.25, -- 0 to disable all; at 2.0, alerts will fire at 1/2 HP
  },
  ["runrest-features"] = { after_shaft = false },
  ["mute-messages"] = {
    mute_level = 1,
  },

  init = function()
    crawl.setopt("show_game_time = false")
    BRC.util.do_cmd("CMD_TOGGLE_AUTOPICKUP")
  end,
} -- brc_config_turncount (do not remove this comment)
