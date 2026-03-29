---------------------------------------------------------------------------------------------------
-- BRC feature test: answer-prompts
-- Verifies that c_answer_prompt returns the correct values for known prompts.
---------------------------------------------------------------------------------------------------

test_answer_prompts = {}
test_answer_prompts.BRC_FEATURE_NAME = "test-answer-prompts"

function test_answer_prompts.ready()
  if T._done then return end

  T.run("answer-prompts", function()
    -- "Die?" must always return false (never answer yes to a death prompt)
    T.false_(f_answer_prompts.c_answer_prompt("Die?"), "die-returns-false")

    -- "cheaper one?" outside the Bazaar → return true (replace shopping list items)
    -- you.branch() starts as "Dungeon", not "Bazaar"
    T.true_(f_answer_prompts.c_answer_prompt("Replace cheaper one? (yes/no)"), "shopping-returns-true")

    -- Unknown prompt → should return nil (no override)
    T.false_(f_answer_prompts.c_answer_prompt("Unrecognized prompt text") ~= nil, "unknown-returns-nil")

    T.pass("answer-prompts")
    T.done()
  end)
end
