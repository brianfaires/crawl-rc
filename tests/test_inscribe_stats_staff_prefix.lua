---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (magic staff bonus prefix duplication bug)
-- Verifies that get_staff_dmg_str() bonus appears exactly ONCE in the inscription.
--
-- The potential bug:
--   dps_inscr = dps_inscr:gsub("/", bonus_str .. "/")
--
-- string.gsub() without a count limit replaces ALL occurrences of "/".
-- The DPS string has the format:  DPS=X.XX (X.XX/X.X) A+N
--                                             ^    ^
--                                             Both "/" get the bonus inserted.
-- So "(+0)" would appear TWICE if the bug is present.
--
-- Phase flow:
--   "give"   : wizard_give("staff of fire") + identify → CMD_WAIT
--   "verify" : find staff on floor, inscribe, count occurrences of "(+0)"
---------------------------------------------------------------------------------------------------

test_inscribe_stats_staff_prefix = {}
test_inscribe_stats_staff_prefix.BRC_FEATURE_NAME = "test-inscribe-stats-staff-prefix"

local _phase = "give"

function test_inscribe_stats_staff_prefix.ready()
  if T._done then return end

  T.run("inscribe-stats-staff-prefix", function()

    if _phase == "give" then
      T.wizard_give("staff of fire")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Find the staff of fire on the floor
      local staff = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_magic_staff(it) then
          staff = it
          break
        end
      end

      T.true_(staff ~= nil, "staff-found-on-floor")
      if not staff then T.done() return end

      -- Ensure prefix_staff_dmg is enabled (default true)
      T.true_(f_inscribe_stats.Config.prefix_staff_dmg, "prefix-staff-dmg-enabled")

      -- Apply the stat inscription
      f_inscribe_stats.do_stat_inscription(staff)

      -- Inscription must be non-empty
      T.true_(staff.inscription ~= nil and #staff.inscription > 0, "inscription-non-empty")

      -- Record the full inscription for diagnosis
      local insc = staff.inscription or ""
      crawl.stderr("[INFO] staff inscription: " .. insc)

      -- Inscription must contain DPS= or Dmg= stat
      local has_stat = insc:find("DPS=") or insc:find("Dmg=")
      T.true_(has_stat ~= nil and has_stat ~= false, "inscription-has-dps-or-dmg")

      -- Count how many times "(+0)" appears.
      -- For a Mummy Berserker with no magic skill, staff bonus dmg chance=0 → bonus_str="(+0)".
      -- If the gsub bug is present, "(+0)" appears at EVERY "/" in the DPS string (i.e. twice).
      -- The correct behavior is exactly once.
      local _, cnt = insc:gsub("%(%+0%)", "")
      crawl.stderr("[INFO] (+0) count: " .. tostring(cnt))

      T.eq(cnt, 1, "bonus-appears-exactly-once")

      T.pass("inscribe-stats-staff-prefix")
      T.done()
    end
  end)
end
