f_fast_passage = {}
f_fast_passage.BRC_FEATURE_NAME = "fast_passage"

---- Local constants ----
local FEAT_NAME = "passage of golubria"

---- Local fucntions ----
local function find_closest_portal()
  for r = 0, 2 do
    for dx = -r, r do
      for dy = -r, r do
        if view.feature_at(dx, dy) == FEAT_NAME then
          return dx, dy
        end
      end
    end
  end
end

--- Find the closest portal (feature name is 'passage of golubria') and enter it
local function do_safe_passage()
  local x, y = find_closest_portal()
  if not x then
    BRC.mpr.yellow("No nearby portals.")
    return
  end

  if not you.feel_safe() then
    BRC.mpr.yellow("Hostile monster in view!")
    return
  end

  BRC.Hotkey.move_to_xy("Passage of Golubria", true, x, y)
end

function f_fast_passage.c_message(text, _)
  if text:find("you open a passage or sth") then
    do_safe_passage()
  end
end
