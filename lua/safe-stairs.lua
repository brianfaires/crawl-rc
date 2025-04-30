local prev_location, temp_location = you.branch()..you.depth(), you.branch()..you.depth()
local last_stair_turn = 0

crawl.setopt("macros += M > ===safe_downstairs")
crawl.setopt("macros += M < ===safe_upstairs")

local function check_new_location(key)
  local cur_location = you.branch()..you.depth()
  local turn_diff = you.turns() - last_stair_turn
  if prev_location ~= cur_location and turn_diff > 0 and turn_diff < 5 then
    crawl.formatted_mpr("Really go right back? (y/n)", "prompt")
    local res = crawl.getch()
    if string.lower(string.char(res)) == "y" then
      crawl.sendkeys(key)
	  last_stair_turn = you.turns()
    end
  else
    crawl.sendkeys(key)
	last_stair_turn = you.turns()
  end
end

function safe_upstairs()
  check_new_location("<")
end

function safe_downstairs()
  check_new_location(">")
end

------------------- Hook -------------------
function ready_safe_stairs()
  prev_location = temp_location
  temp_location = you.branch()..you.depth()
end
