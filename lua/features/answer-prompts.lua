---------------------------------------------------------------------------------------------------
-- BRC feature module: answer-prompts
-- @module f_answer_prompts
-- Automatically answer crawl prompts.
---------------------------------------------------------------------------------------------------

f_answer_prompts = {}
f_answer_prompts.BRC_FEATURE_NAME = "answer-prompts"

---- Local constants ----
local BAD_FOR_TREES = { "deep_water", "lava", "open_sea", "endless_lava" }

---- Crawl hook functions ----
function f_answer_prompts.c_answer_prompt(prompt)
  if prompt == "Die?" then return false end

  if prompt:contains("cheaper one?") and you.branch() ~= "Bazaar" then
    BRC.mpr.yellow("Replacing shopping list items")
    return true
  end

  if prompt:contains("quaff the potion of lignification") then
    local feat = view.feature_at(0,0)
    if feat and util.contains(BAD_FOR_TREES, feat) then
      BRC.mpr.warning("Blocking lignification over " .. feat)
      return false
    end
  end
end
