---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-hp-mp (gain scenario)
-- Verifies the HP GAIN path: when HP increased by 5 since last turn, the meter fires.
--
-- Complements test_announce_hp_mp.lua which tests the HP loss path.
-- hp_gain_limit = 4, so a delta of +5 triggers the message.
---------------------------------------------------------------------------------------------------

test_announce_hp_mp_gain = {}
test_announce_hp_mp_gain.BRC_FEATURE_NAME = "test-announce-hp-mp-gain"

local _phase = "setup"

function test_announce_hp_mp_gain.ready()
  if T._done then return end

  T.run("announce-hp-mp-gain", function()
    if _phase == "setup" then
      -- Fake a 5-HP gain: pretend HP was 5 LOWER before this turn.
      -- hp_delta = you.hp() - (you.hp() - 5) = +5
      -- hp_gain_limit = 4, so +5 >= 4 → triggers HP gain message.
      -- is_startup = false because ad_prev.hp != 0.
      local hp, mhp = you.hp()
      local mp, mmp = you.mp()
      ad_prev.hp  = math.max(1, hp - 5)  -- ensure > 0 so is_startup = false
      ad_prev.mhp = mhp
      ad_prev.mp  = mp
      ad_prev.mmp = mmp
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.true_(T.messages_contain("HP%["), "hp-gain-meter-fired")
      T.pass("announce-hp-mp-gain")
      T.done()
    end
  end)
end
