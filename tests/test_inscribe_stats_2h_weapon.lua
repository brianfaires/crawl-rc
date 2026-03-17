---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (2-handed weapon)
-- Verifies that f_inscribe_stats.do_stat_inscription produces a valid DPS inscription for a
-- 2-handed weapon (great mace).
--
-- Character: Mummy Berserker at XL 1 with no Maces & Flails skill.
-- The great mace is a 2-handed weapon (17 dmg, -4 accuracy, speed 17).
--
-- Expected inscription format (skip_dps=false, default):
--   DPS=N.N (N.N/N.N) A-N
-- or with skip_dps=true:
--   Dmg=N.N/N.N A-N
--
-- Phase flow:
--   "give"   : wizard_give("great mace") + identify + CMD_WAIT
--   "verify" : find great mace on floor, call do_stat_inscription, check format
---------------------------------------------------------------------------------------------------

test_inscribe_stats_2h_weapon = {}
test_inscribe_stats_2h_weapon.BRC_FEATURE_NAME = "test-inscribe-stats-2h-weapon"

local _phase = "give"

function test_inscribe_stats_2h_weapon.ready()
  if T._done then return end

  T.run("inscribe-stats-2h-weapon", function()

    if _phase == "give" then
      -- Place a plain great mace on the floor and identify it.
      T.wizard_give("great mace")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Find the great mace on the floor
      local weap = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("great mace") then
          weap = it
          break
        end
      end

      T.true_(weap ~= nil, "great-mace-on-floor")
      if not weap then T.done() return end

      -- Log weapon stats for diagnosis
      crawl.stderr("[INFO] great mace name=" .. tostring(weap.name("base")))
      crawl.stderr("[INFO] great mace hands=" .. tostring(BRC.eq.get_hands(weap)))

      -- Verify it is actually a 2-handed weapon
      T.eq(BRC.eq.get_hands(weap), 2, "great-mace-is-2h")

      -- Apply stat inscription
      f_inscribe_stats.do_stat_inscription(weap)

      -- Inscription must be non-empty
      local insc = weap.inscription or ""
      crawl.stderr("[INFO] great mace inscription: " .. insc)
      T.true_(#insc > 0, "inscription-non-empty")

      -- Inscription must start with "DPS=" (default skip_dps=false) or "Dmg=" (skip_dps=true)
      local has_stat = insc:find("^DPS=") or insc:find("^Dmg=")
      T.true_(has_stat ~= nil and has_stat ~= false, "inscription-has-dps-or-dmg-prefix")

      -- Inscription must contain accuracy in the form "A+N" or "A-N"
      local has_accuracy = insc:find("A[%+%-]%d+")
      T.true_(has_accuracy ~= nil and has_accuracy ~= false, "inscription-has-accuracy")

      -- With skip_dps=false (default), the full DPS format is: DPS=N.N (N.N/N.N) A±N
      if not f_inscribe_stats.Config.skip_dps then
        -- Must contain the speed/damage ratio in parentheses: (N.N/N.N)
        local has_ratio = insc:find("%(%d+%.%d+/%d+%.%d*%)")
        T.true_(has_ratio ~= nil and has_ratio ~= false, "inscription-has-dps-ratio")
      end

      T.pass("inscribe-stats-2h-weapon")
      T.done()
    end
  end)
end
