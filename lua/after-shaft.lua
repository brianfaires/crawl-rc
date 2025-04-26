------------------------------------
---- Stop on stairs after shaft ----
------------------------------------
local shaft_depth = 0
local shaft_branch = "NA"

local function persist_shaft_values()
  local cmd = "shaft_depth = "..shaft_depth..string.char(10) .."shaft_branch = \""..shaft_branch.."\""..string.char(10)
  return cmd
end

if not added_shaft_stairs_hook then
  table.insert(chk_lua_save, persist_shaft_values)
  local added_shaft_stairs_hook = true
end


---------------------------------------------
------------------- Hooks -------------------
---------------------------------------------
function c_message_after_shaft(text, _)
  if shaft_depth ~= 0 then return end
  if text:find("fall into a shaft") then
    shaft_depth = you.depth()
    shaft_branch = you.branch()
    crawl.setopt("explore_stop += stairs")
  end
end

function ready_after_shaft()
  if shaft_depth ~= 0 then
    if you.depth() == shaft_depth and you.branch() == shaft_branch then
      crawl.setopt("explore_stop -= stairs")
      shaft_depth = 0
      shaft_branch = "NA"
    end
  end
end
