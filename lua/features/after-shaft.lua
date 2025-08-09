function init_after_shaft()
  if not CONFIG.stop_on_stairs_after_shaft then return end
  if CONFIG.debug_init then crawl.mpr("Initializing after-shaft") end

  create_persistent_data("as_shaft_depth", 0)
  create_persistent_data("as_shaft_branch", "NA")

  if CACHE.turn == 0 and CACHE.class == "Delver" then
    as_shaft_depth = 1
    as_shaft_branch = CACHE.branch
  end

  if as_shaft_depth ~= 0 then
    crawl.setopt("explore_stop += stairs")
  else
    crawl.setopt("explore_stop -= stairs")
  end
end

------------------- Hooks -------------------
function c_message_after_shaft(text, channel)
  if not CONFIG.stop_on_stairs_after_shaft then return end
  if as_shaft_depth ~= 0 or channel ~= "plain" then return end
  local text_fall = "ou fall into a shaft"
  local text_sucked = "ou are sucked into a shaft"
  if text:find(text_fall, 1, true) or text:find(text_sucked, 1, true) then
    as_shaft_depth = CACHE.depth
    as_shaft_branch = CACHE.branch
    crawl.setopt("explore_stop += stairs")
  end
end

function ready_after_shaft()
  if not CONFIG.stop_on_stairs_after_shaft then return end
  if CACHE.depth == as_shaft_depth and CACHE.branch == as_shaft_branch then
    crawl.setopt("explore_stop -= stairs")
    as_shaft_depth = 0
    as_shaft_branch = "NA"
  end
end
