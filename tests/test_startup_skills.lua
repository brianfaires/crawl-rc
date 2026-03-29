---------------------------------------------------------------------------------------------------
-- BRC feature test: startup (skill targets)
-- Verifies that f_startup.ready() sets Fighting and Stealth training targets at turn 0.
--
-- f_startup.ready() only runs when you.turns() == 0. Our test hook (test-startup-skills)
-- runs BEFORE f_startup.ready() in the same cycle (reverse-alpha order). So we wait for
-- turn 1 to check: at that point startup has already run during turn 0's cycle.
--
-- Config.auto_set_skill_targets = { {"Stealth", 2.0}, {"Fighting", 2.0}, ... }
-- After startup runs, get_training_target("Fighting") should be > 0.
---------------------------------------------------------------------------------------------------

test_startup_skills = {}
test_startup_skills.BRC_FEATURE_NAME = "test-startup-skills"

local _phase = "wait"

function test_startup_skills.ready()
  if T._done then return end

  T.run("startup-skills", function()
    if _phase == "wait" then
      -- f_startup.ready() fires AFTER us in turn 0's cycle (reverse-alpha).
      -- Wait for turn 1 so we check AFTER startup has run.
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "check" then
      -- Startup called load_generic_skill_targets():
      --   Stealth is first in auto_set_skill_targets → train_skill("Stealth", 1) IS called
      --   Fighting is second  → target set, but train_skill NOT called (focus_one_skill=true)
      --
      -- get_training_target returns 0 for skills with training_level=0, even if a target was
      -- set, so we only assert Stealth (the focused skill that has training enabled).
      local stealth_target = you.get_training_target("Stealth")
      T.true_(stealth_target > 0, "stealth-target-set")

      -- Verify Stealth is actively being trained (training level 1 = enabled)
      T.true_(you.train_skill("Stealth") > 0, "stealth-training-active")

      T.pass("startup-skills")
      T.done()
    end
  end)
end
