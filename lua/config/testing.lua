-- Testing Config Profile: Isolate and test specific features

BRC.Profiles.Testing = {
  show_debug_messages = true,
  disable_other_features = false,
  ["pickup-alert"] = {
    Alert = {
      armour_sensitivity = 0.3,
      weapon_sensitivity = 1,
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
} -- BRC.Profiles.Testing (do not remove this comment)
