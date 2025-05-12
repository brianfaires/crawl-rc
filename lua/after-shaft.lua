loadfile("crawl-rc/lua/util.lua")

----- Add stops for stairs after being shafted -----
create_persistent_data("as_shaft_depth", 0)
create_persistent_data("as_shaft_branch", "NA")

-- Initial logic to maintain persistent state
if as_shaft_depth ~= 0 then
  crawl.setopt("explore_stop += stairs")
else
  crawl.setopt("explore_stop -= stairs")
end


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
