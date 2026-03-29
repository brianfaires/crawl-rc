---------------------------------------------------------------------------------------------------
-- BRC Test Harness
-- Injected before BRC.init() so T is registered as a BRC feature automatically.
-- Provides T.* API for assertions, lifecycle, and message capture.
---------------------------------------------------------------------------------------------------

-- Override config before BRC.init() sees it (prevents interactive "ask" prompt in headless mode).
-- Must set BRC.Configs.Default.to_use, not BRC.Config.to_use, because init_config() resets
-- BRC.Config = util.copy_table(BRC.Configs.Default) before reading to_use.
BRC.Configs.Default.to_use = "Testing"

-- T is the harness feature module. BRC picks it up via T.BRC_FEATURE_NAME.
T = {}
T.BRC_FEATURE_NAME = "test-harness"
T.timeout_turns = 20
T._done = false

-- Message capture buffer (populated by T.c_message hook)
T.last_messages = {}

---------------------------------------------------------------------------------------------------
-- Output helpers — write directly to stderr so run.sh can parse them separately from stdout
---------------------------------------------------------------------------------------------------

local function stderr(line)
  crawl.stderr(line) -- crawl.stderr() adds \n automatically; io library is disabled in crawl's Lua
end

function T.pass(name)
  stderr("[PASS] " .. tostring(name))
end

function T.fail(name, reason)
  stderr("[FAIL] " .. tostring(name) .. ": " .. tostring(reason))
end

function T.error_(name, msg)
  stderr("[ERROR] " .. tostring(name) .. ": " .. tostring(msg))
end

---------------------------------------------------------------------------------------------------
-- Assertions
---------------------------------------------------------------------------------------------------

function T.eq(actual, expected, name)
  if actual == expected then
    T.pass(name)
  else
    T.fail(name, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
  end
end

function T.true_(val, name)
  if val then
    T.pass(name)
  else
    T.fail(name, "expected true, got " .. tostring(val))
  end
end

function T.false_(val, name)
  if not val then
    T.pass(name)
  else
    T.fail(name, "expected false, got " .. tostring(val))
  end
end

function T.contains(str, pattern, name)
  if string.find(tostring(str), pattern) then
    T.pass(name)
  else
    T.fail(name, string.format("pattern %q not found in %q", pattern, tostring(str)))
  end
end

---------------------------------------------------------------------------------------------------
-- T.run(name, fn): wrap test logic in pcall to prevent BRC's interactive error handler from
-- firing (which would hang in headless mode). Always call T.done() after T.run().
---------------------------------------------------------------------------------------------------

function T.run(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    T.error_(name, err)
    T.done()
  end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------

-- T.done(): signal test completion and quit crawl.
-- Uses CMD_SAVE_GAME_NOW directly to bypass macro_brc_save() which would block with yesno().
function T.done()
  T._done = true
  crawl.do_commands({"CMD_SAVE_GAME_NOW"})
end

-- Timeout guard: if T.done() not called within T.timeout_turns, fail and quit.
function T.ready()
  if T._done then return end
  if you.turns() >= T.timeout_turns then
    T.fail("timeout", string.format("test did not complete within %d turns", T.timeout_turns))
    T.done()
  end
end

-- Auto-answer save/quit prompts so T.done() exits cleanly without blocking.
function T.c_answer_prompt(prompt)
  if T._done then
    local p = prompt:lower()
    if p:find("save") or p:find("quit") or p:find("exit") or p:find("leave") then
      return true
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Message capture
---------------------------------------------------------------------------------------------------

function T.c_message(text, channel)
  table.insert(T.last_messages, {text = text, channel = channel})
end

function T.messages_contain(pattern)
  for _, msg in ipairs(T.last_messages) do
    if string.find(msg.text, pattern) then return true end
  end
  return false
end

---------------------------------------------------------------------------------------------------
-- Wizard helpers (v2 stubs — not implemented in v1)
---------------------------------------------------------------------------------------------------

function T.wizard_give(item_spec)
  -- Pre-queue '%' + item name + Enter; CMD_WIZARD reads them from macro_buf.
  -- flush_input_buffer(FLUSH_BEFORE_COMMAND) inside do_commands is a no-op by
  -- default, so the pre-queued keys survive.
  crawl.sendkeys("%" .. item_spec .. "\r")
  crawl.do_commands({"CMD_WIZARD"})
  -- Item now exists on the floor at you.pos()
end

function T.wizard_identify_all()
  -- 'y' subcommand -> wizard_identify_all_items() (wizard.cc:172).
  -- No further input needed; identifies floor + inventory items immediately.
  crawl.sendkeys("y")
  crawl.do_commands({"CMD_WIZARD"})
end

function T.wizard_set_xl(level)
  -- 'l' subcommand -> wizard_set_xl() (wiz-you.cc:870).
  -- cancellable_get_line_autohist reads the level number from macro_buf.
  crawl.sendkeys("l" .. tostring(level) .. "\r")
  crawl.do_commands({"CMD_WIZARD"})
end

function T.wizard_teleport()
  -- Not implementable via sendkeys: both wizard 'b' (wizard_blink) and 'B'
  -- (you.teleport controlled) require interactive direction/cursor input that
  -- cannot be pre-queued as key strings in headless mode.
  T.error_("wizard_teleport", "requires interactive targeting; not implemented")
  T.done()
end
