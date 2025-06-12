loadfile("lua/cache.lua")
loadfile("crawl-rc/lua/config.lua")

----- Prevent accidental stairs usage -----
local prev_location, temp_location = you.branch()..you.depth(), you.branch()..you.depth()
local last_stair_turn = 0

crawl.setopt("macros += M > ===macro_do_safe_downstairs")
crawl.setopt("macros += M < ===macro_do_safe_upstairs")

local function check_new_location(key)
  local cur_location = you.branch()..you.depth()
  local turn_diff = CACHE.turn - last_stair_turn
  local question = nil
  if prev_location ~= cur_location and turn_diff > 0 and turn_diff < CONFIG.warn_stairs_threshold then
    question = "Really go right back? (y/n)"
  elseif CONFIG.warn_v5 and cur_location == "Vaults4" and key == ">" then
    -- V5 warning idea by rypofalem --
    question = "Really go to Vaults:5? (y/n)"
    CONFIG.warn_v5 = false
  end

  if question then
    crawl.formatted_mpr(question, "prompt")
    local res = crawl.getch()
    if string.lower(string.char(res)) ~= "y" then
      crawl.mpr("Okay, then.")
      return
    end
  end

  crawl.sendkeys(key)
  last_stair_turn = CACHE.turn
end

function macro_do_safe_upstairs()
  check_new_location("<")
end

function macro_do_safe_downstairs()
  check_new_location(">")
end

------------------- Hook -------------------
function ready_safe_stairs()
  prev_location = temp_location
  temp_location = you.branch()..you.depth()
end
