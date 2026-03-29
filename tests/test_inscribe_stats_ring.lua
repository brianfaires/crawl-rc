---------------------------------------------------------------------------------------------------
-- BRC feature test: inscribe-stats (ring / jewellery -- no inscription)
-- Verifies that do_stat_inscription is a no-op for jewellery items.
--
-- do_stat_inscription(it) only acts when:
--   (a) it.is_weapon  -> inscribe_weapon_stats
--   (b) BRC.it.is_armour(it) and not BRC.it.is_scarf(it) -> inscribe_armour_stats
-- Rings have it.class(true) == "jewellery", so neither branch fires.
-- The item inscription must remain empty after calling do_stat_inscription.
--
-- Phase flow:
--   "give"   : wizard_give("ring of slaying") + identify -> CMD_WAIT
--   "verify" : find ring on floor, call do_stat_inscription, check inscription is empty
---------------------------------------------------------------------------------------------------

test_inscribe_stats_ring = {}
test_inscribe_stats_ring.BRC_FEATURE_NAME = "test-inscribe-stats-ring"

local _phase = "give"

function test_inscribe_stats_ring.ready()
  if T._done then return end

  T.run("inscribe-stats-ring", function()

    if _phase == "give" then
      T.wizard_give("ring of slaying")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Find the ring on the floor
      local ring = nil
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_jewellery(it) then
          ring = it
          break
        end
      end

      T.true_(ring ~= nil, "ring-on-floor")
      if not ring then T.done() return end

      crawl.stderr("[INFO] ring name=" .. tostring(ring.name()))

      -- Record inscription before (should be empty or game-set)
      local insc_before = ring.inscription or ""
      crawl.stderr("[INFO] ring inscription before: '" .. insc_before .. "'")

      -- do_stat_inscription must not modify jewellery
      f_inscribe_stats.do_stat_inscription(ring)

      local insc_after = ring.inscription or ""
      crawl.stderr("[INFO] ring inscription after:  '" .. insc_after .. "'")

      -- The inscription must not have gained any stat content (DPS=, Dmg=, AC, SH)
      T.true_(not insc_after:find("DPS="), "ring-no-dps-inscription")
      T.true_(not insc_after:find("Dmg="), "ring-no-dmg-inscription")
      T.true_(not insc_after:find("AC[%+%-:]"), "ring-no-ac-inscription")
      T.true_(not insc_after:find("SH[%+%-:]"), "ring-no-sh-inscription")

      T.pass("inscribe-stats-ring")
      T.done()
    end
  end)
end
