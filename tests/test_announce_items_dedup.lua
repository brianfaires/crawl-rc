---------------------------------------------------------------------------------------------------
-- BRC feature test: announce-items (dedup — same item not re-announced on second ready())
-- Verifies that f_announce_items.ready() does not re-announce an item that was already
-- in LOS the previous turn. prev_item_names is set at the end of each ready() call.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "scroll of fog" → CMD_WAIT
--   "first"  (turn 1): init() + ready() — announces scroll; CMD_WAIT
--   "second" (turn 2): count "Found" messages, call ready() again; CMD_WAIT
--   "verify" (turn 3): count "Found" messages again — must be same as before second call
---------------------------------------------------------------------------------------------------

test_announce_items_dedup = {}
test_announce_items_dedup.BRC_FEATURE_NAME = "test-announce-items-dedup"

local _phase = "give"
local _found_count_before = 0

local function count_found_messages()
  local n = 0
  for _, msg in ipairs(T.last_messages) do
    if msg.text:find("Found") then n = n + 1 end
  end
  return n
end

function test_announce_items_dedup.ready()
  if T._done then return end

  T.run("announce-items-dedup", function()
    if _phase == "give" then
      T.wizard_give("scroll of fog")
      _phase = "first"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "first" then
      f_announce_items.init()
      f_announce_items.ready()
      _phase = "second"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "second" then
      -- Snapshot count after first ready(); now call ready() a second time (no init)
      _found_count_before = count_found_messages()
      f_announce_items.ready()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- First ready() must have announced something
      T.true_(_found_count_before >= 1, "first-ready-announced")
      -- Second ready() must not have added more "Found" messages
      local count_after = count_found_messages()
      T.eq(count_after, _found_count_before, "dedup-no-reannounce")

      T.pass("announce-items-dedup")
      T.done()
    end
  end)
end
