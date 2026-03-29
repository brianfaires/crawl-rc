---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (branded weapon)
-- Verifies that do_stat_inscription produces a valid DPS inscription for a branded weapon.
--
-- A flaming mace has ego:flaming.  The inscription path is identical to any other weapon:
--   do_stat_inscription -> inscribe_weapon_stats -> BRC.eq.wpn_stats(it, dmg_type, skip_dps)
-- The brand may affect the numeric damage value (depending on dmg_type config) but NOT the
-- inscription format.  Expected format (skip_dps=false, default):
--   DPS=N.N (N.N/N.N) A+N
--
-- Phase flow:
--   "give"   : wizard_give("mace ego:flaming") + identify -> CMD_WAIT
--   "verify" : find flaming mace on floor, call do_stat_inscription, check format
---------------------------------------------------------------------------------------------------

test_inscribe_stats_branded_weapon = {}
test_inscribe_stats_branded_weapon.BRC_FEATURE_NAME = "test-inscribe-stats-branded-weapon"

local _phase = "give"

function test_inscribe_stats_branded_weapon.ready()
  if T._done then return end

  T.run("inscribe-stats-branded-weapon", function()

    if _phase == "give" then
      T.wizard_give("mace ego:flaming")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Find the flaming mace on the floor
      local weap = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.name("base"):find("mace") then
          weap = it
          break
        end
      end

      T.true_(weap ~= nil, "flaming-mace-on-floor")
      if not weap then T.done() return end

      crawl.stderr("[INFO] flaming mace name=" .. tostring(weap.name()))

      -- Apply stat inscription
      f_inscribe_stats.do_stat_inscription(weap)

      local insc = weap.inscription or ""
      crawl.stderr("[INFO] flaming mace inscription: " .. insc)

      -- Inscription must be non-empty
      T.true_(#insc > 0, "inscription-non-empty")

      -- Must contain DPS= or Dmg= (depending on skip_dps config)
      local has_stat = insc:find("DPS=") or insc:find("Dmg=")
      T.true_(has_stat ~= nil and has_stat ~= false, "inscription-has-dps-or-dmg")

      -- Must contain accuracy in the form "A+N" or "A-N"
      local has_accuracy = insc:find("A[%+%-]%d+")
      T.true_(has_accuracy ~= nil and has_accuracy ~= false, "inscription-has-accuracy")

      -- With skip_dps=false (default), the full DPS format is: DPS=N.N (N.N/N.N) A±N
      if not f_inscribe_stats.Config.skip_dps then
        local has_ratio = insc:find("%(%d+%.%d+/%d+%.%d*%)")
        T.true_(has_ratio ~= nil and has_ratio ~= false, "inscription-has-dps-ratio")
      end

      T.pass("inscribe-stats-branded-weapon")
      T.done()
    end
  end)
end
