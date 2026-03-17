---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (format migration)
-- Verifies that update_inscription() correctly migrates the inscription when skip_dps config
-- is toggled between DPS= and Dmg= formats.
--
-- update_inscription() handles format migration at lines 77-80:
--   if not first then
--     if cur:sub(1,4) == "Dmg=" then first = orig:find("DPS=")
--     elseif cur:sub(1,4) == "DPS=" then first = orig:find("Dmg=") end
--   end
--
-- So switching skip_dps replaces the existing stat prefix in-place rather than appending.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("mace") + identify → CMD_WAIT
--   "verify" (turn 1): find mace on floor, inscribe DPS, then Dmg, then DPS again,
--                      verifying each migration
---------------------------------------------------------------------------------------------------

test_inscribe_stats_format_migration = {}
test_inscribe_stats_format_migration.BRC_FEATURE_NAME = "test-inscribe-stats-format-migration"

local _phase = "give"

function test_inscribe_stats_format_migration.ready()
  if T._done then return end

  T.run("inscribe-stats-format-migration", function()

    if _phase == "give" then
      -- Place a plain mace on the floor and identify it
      T.wizard_give("mace")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Find the mace on the floor
      local weap = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("mace") then
          weap = it
          break
        end
      end

      T.true_(weap ~= nil, "mace-on-floor")
      if not weap then T.done() return end

      crawl.stderr("[INFO] mace name=" .. tostring(weap.name("base")))

      -- Save original skip_dps setting so we can restore it
      local orig_skip = f_inscribe_stats.Config.skip_dps

      -- Step 1: Write DPS= format (skip_dps = false)
      f_inscribe_stats.Config.skip_dps = false
      f_inscribe_stats.do_stat_inscription(weap)
      local insc1 = weap.inscription or ""
      crawl.stderr("[INFO] inscription with skip_dps=false: " .. insc1)
      T.true_(insc1:find("DPS=") ~= nil, "dps-format-written")
      T.true_(insc1:find("Dmg=") == nil, "no-dmg-format-when-dps")

      -- Step 2: Switch to Dmg= format (skip_dps = true) — must migrate in-place
      f_inscribe_stats.Config.skip_dps = true
      f_inscribe_stats.do_stat_inscription(weap)
      local insc2 = weap.inscription or ""
      crawl.stderr("[INFO] inscription after migration to skip_dps=true: " .. insc2)
      T.true_(insc2:find("Dmg=") ~= nil, "dmg-format-after-migration")
      T.true_(insc2:find("DPS=") == nil, "dps-format-removed-after-migration")

      -- Step 3: Switch back to DPS= format (skip_dps = false) — reverse migration
      f_inscribe_stats.Config.skip_dps = false
      f_inscribe_stats.do_stat_inscription(weap)
      local insc3 = weap.inscription or ""
      crawl.stderr("[INFO] inscription after reverse migration to skip_dps=false: " .. insc3)
      T.true_(insc3:find("DPS=") ~= nil, "dps-restored-after-reverse-migration")
      T.true_(insc3:find("Dmg=") == nil, "dmg-removed-after-reverse-migration")

      -- All three inscriptions must contain accuracy (format is stable across migration)
      T.true_(insc1:find("A[%+%-]%d+") ~= nil, "insc1-has-accuracy")
      T.true_(insc2:find("A[%+%-]%d+") ~= nil, "insc2-has-accuracy")
      T.true_(insc3:find("A[%+%-]%d+") ~= nil, "insc3-has-accuracy")

      -- Restore original config
      f_inscribe_stats.Config.skip_dps = orig_skip

      T.pass("inscribe-stats-format-migration")
      T.done()
    end
  end)
end
