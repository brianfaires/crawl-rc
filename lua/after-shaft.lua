if loaded_after_shaft then return end
local loaded_after_shaft = true

if not as_shaft_depth or you.turns() == 0 then
  as_shaft_depth = 0
  as_shaft_branch = "NA"
end
local function persist_shaft_values()
  local cmd = "as_shaft_depth = "..as_shaft_depth..string.char(10) .."as_shaft_branch = \""..as_shaft_branch.."\""..string.char(10)
  return cmd
end
table.insert(chk_lua_save, persist_shaft_values)

------------------- Hooks -------------------
function c_message_after_shaft(text, _)
  if as_shaft_depth ~= 0 then return end
  if text:find("fall into a shaft") then
    as_shaft_depth = you.depth()
    as_shaft_branch = you.branch()
    crawl.setopt("explore_stop += stairs")
  end
end

function ready_after_shaft()
  if as_shaft_depth ~= 0 then
    if you.depth() == as_shaft_depth and you.branch() == as_shaft_branch then
      crawl.setopt("explore_stop -= stairs")
      as_shaft_depth = 0
      as_shaft_branch = "NA"
    end
  end
end
