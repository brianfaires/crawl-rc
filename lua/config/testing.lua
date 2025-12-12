--- Testing Config Profile: Isolate and test specific features

brc_config_testing = {
  BRC_CONFIG_NAME = "Testing",

  mpr = {
    show_debug_messages = true,
    logs_to_stderr = true,
  },

  disable_other_features = false,
  ["pickup-alert"] = {
    Alert = {
      armour_sensitivity = 0.5,
      weapon_sensitivity = 0.5,
    },
    Tuning = {
      Armour = {
        diff_body_ego_is_good = false,
      },
    },
  },
  init = [[
    if BRC.Config.disable_other_features then
      for _, v in pairs(_G) do
        if BRC.is_feature_module(v) and not BRC.Config[v.BRC_FEATURE_NAME] then
          BRC.Config[v.BRC_FEATURE_NAME] = { disabled = true }
        end
      end
    end
  ]],
} -- brc_config_testing (do not remove this comment)
