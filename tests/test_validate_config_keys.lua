---------------------------------------------------------------------------------------------------
-- BRC feature test: validate_config_keys
-- Verifies that BRC._validate_config_keys() warns about:
--   1. Unknown feature names (hyphenated keys not matching any registered feature)
--   2. Unknown sub-keys within a known feature's config
-- And does NOT warn about:
--   3. Known core keys
--   4. Known feature names with valid sub-keys
---------------------------------------------------------------------------------------------------

-- @species Mu
-- @background Be
test_validate_config_keys = {}
test_validate_config_keys.BRC_FEATURE_NAME = "test-validate-config-keys"

function test_validate_config_keys.ready()
  if T._done then return end

  T.run("validate-config-keys", function()
    -- Snapshot BRC.Config so we can inject bad keys and restore
    local saved_keys = {}

    -- 1. Inject an unknown feature name (hyphenated, looks like a feature)
    BRC.Config["pickup-alerts"] = { disabled = false }
    saved_keys["pickup-alerts"] = true

    -- 2. Inject an unknown sub-key in a known feature
    local orig_bogus = f_misc_alerts.Config.bogus_option
    f_misc_alerts.Config.bogus_option = 42
    BRC.Config["misc-alerts"] = BRC.Config["misc-alerts"] or {}
    BRC.Config["misc-alerts"].bogus_option = 42

    -- 3. Inject a non-hyphenated unknown key (should NOT warn — no hyphen)
    BRC.Config["something_else"] = { foo = 1 }
    saved_keys["something_else"] = true

    -- Clear message buffer, then run validation
    T.last_messages = {}
    BRC._validate_config_keys()

    -- Check: unknown feature warning for "pickup-alerts"
    local found_unknown_feature = false
    for _, msg in ipairs(T.last_messages) do
      if string.find(msg.text, "pickup%-alerts") and string.find(msg.text, "Unknown feature") then
        found_unknown_feature = true
      end
    end
    T.true_(found_unknown_feature, "unknown-feature-warning-fired")

    -- Check: unknown sub-key warning for misc-alerts.bogus_option
    local found_unknown_subkey = false
    for _, msg in ipairs(T.last_messages) do
      if string.find(msg.text, "bogus_option") and string.find(msg.text, "Unknown config key") then
        found_unknown_subkey = true
      end
    end
    T.true_(found_unknown_subkey, "unknown-subkey-warning-fired")

    -- Check: no warning for non-hyphenated key "something_else"
    local found_something_else = false
    for _, msg in ipairs(T.last_messages) do
      if string.find(msg.text, "something_else") then
        found_something_else = true
      end
    end
    T.false_(found_something_else, "no-warning-for-non-hyphenated-key")

    -- Check: no warning for a known feature with valid keys (e.g., misc-alerts.disabled)
    local found_valid_warning = false
    for _, msg in ipairs(T.last_messages) do
      if string.find(msg.text, "disabled") and string.find(msg.text, "Unknown") then
        found_valid_warning = true
      end
    end
    T.false_(found_valid_warning, "no-warning-for-disabled-key")

    -- Cleanup: remove injected keys
    for k in pairs(saved_keys) do
      BRC.Config[k] = nil
    end
    f_misc_alerts.Config.bogus_option = orig_bogus
    if BRC.Config["misc-alerts"] then
      BRC.Config["misc-alerts"].bogus_option = nil
    end

    T.pass("validate-config-keys")
    T.done()
  end)
end
