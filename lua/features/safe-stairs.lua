----- Prevent accidental stairs use -----
local prev_location
local cur_location
local last_stair_turn
local v5_unwarned

local function check_new_location(key)
  local new_location = CACHE.branch .. CACHE.depth
  local turn_diff = CACHE.turn - last_stair_turn
  if prev_location ~= new_location and turn_diff > 0 and turn_diff < CONFIG.warn_stairs_threshold then
    if not crawl.yesno("Really go right back? (y/n)", true) then
      crawl.mpr("Okay, then.")
      return
    end
  elseif CONFIG.warn_v5 and v5_unwarned and new_location == "Vaults4" and key == ">" then
    -- V5 warning idea by rypofalem --
    local feature = view.feature_at (0, 0)
    if feature:find("down") or feature:find("shaft") then
      if not crawl.yesno("Really go to Vaults:5? (y/n)", true) then
        crawl.mpr("Okay, then.")
        return
      end
      v5_unwarned = false
    end
  end

  crawl.sendkeys(key)
  last_stair_turn = CACHE.turn
end


function init_safe_stairs()
  if CONFIG.debug_init then crawl.mpr("Initializing safe-stairs") end
  prev_location = CACHE.branch .. CACHE.depth
  cur_location = prev_location
  last_stair_turn = 0
  v5_unwarned = true

  crawl.setopt("macros += M > ===macro_do_safe_downstairs")
  crawl.setopt("macros += M < ===macro_do_safe_upstairs")
end

function macro_do_safe_downstairs()
  check_new_location(">")
end

function macro_do_safe_upstairs()
  check_new_location("<")
end


------------------- Hook -------------------
function ready_safe_stairs()
  prev_location = cur_location
  cur_location = CACHE.branch .. CACHE.depth
end
