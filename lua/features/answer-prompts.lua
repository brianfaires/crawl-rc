---------------------------------------------------------------------------------------------------
-- BRC feature module: answer-prompts
-- @module f_answer_prompts
-- Automatically answer crawl prompts.
---------------------------------------------------------------------------------------------------

f_answer_prompts = {}
f_answer_prompts.BRC_FEATURE_NAME = "answer_prompts"

function f_answer_prompts.c_answer_prompt(prompt)
  if prompt == "Die?" then return false end
  if prompt:contains("cheaper one?") and you.branch() ~= "Bazaar" then
    BRC.mpr.yellow("Replacing shopping list items")
    return true
  end
end
