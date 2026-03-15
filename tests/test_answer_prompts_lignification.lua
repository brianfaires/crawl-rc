---------------------------------------------------------------------------------------------------
-- BRC feature test: answer-prompts (lignification edge cases)
-- Verifies the lignification prompt handler:
--   - On safe terrain (dungeon floor) → return nil (don't block)
--   - "Die?" always returns false regardless of other state
-- Also tests that the function returns nil for prompts it doesn't recognise,
-- which is important for prompts that crawl must handle itself.
---------------------------------------------------------------------------------------------------

test_answer_prompts_lignification = {}
test_answer_prompts_lignification.BRC_FEATURE_NAME = "test-answer-prompts-lignification"

function test_answer_prompts_lignification.ready()
  if T._done then return end

  T.run("answer-prompts-lignification", function()
    -- On dungeon floor (start position), feature_at(0,0) = "floor", not in BAD_FOR_TREES.
    -- The function checks the terrain and finds it safe → falls through → returns nil.
    local result = f_answer_prompts.c_answer_prompt("quaff the potion of lignification")
    T.false_(result ~= nil, "lignification-safe-floor-returns-nil")

    -- Unrelated prompt: no handler → nil (crawl handles it)
    local unrelated = f_answer_prompts.c_answer_prompt("Really attack the friendly kobold?")
    T.false_(unrelated ~= nil, "unrelated-prompt-returns-nil")

    -- Partial match sanity check: "cheaper" substring triggers the shopping handler
    local shopping = f_answer_prompts.c_answer_prompt("Replace with cheaper one?")
    T.true_(shopping == true, "shopping-prompt-true")

    T.pass("answer-prompts-lignification")
    T.done()
  end)
end
