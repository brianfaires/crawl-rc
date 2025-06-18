-- A collection of simple features related to resting and auto-explore stops
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/constants.lua")

local stop_on_altars = true
local stop_on_portals = true
local stop_on_pan_gates = false


---- Ignore exit portals ----
local function ready_ignore_exits()
  local branch = you.branch()
  if stop_on_portals and util.contains(all_portal_names, branch) then
    stop_on_portals = false
    crawl.setopt("explore_stop -= portals")
  elseif not stop_on_portals and not util.contains(all_portal_names, branch) then
    stop_on_portals = true
    crawl.setopt("explore_stop += portals")
  end
end

---- Ignore altars ----
local function religion_is_handled()
  return CACHE.god ~= "No God" or CACHE.race == "Demigod" or
    (you.good_god() and CACHE.xl > 9)
end

local function ready_ignore_altars()
  if stop_on_altars and religion_is_handled() then
    stop_on_altars = false
    crawl.setopt("explore_stop -= altars")
  elseif not stop_on_altars and not religion_is_handled() then
    stop_on_altars = true
    crawl.setopt("explore_stop += altars")
  end
end

---- Automated temple actions ----
local function c_message_search_altars_in_temple(text, _)
  if you.branch() == "Temple" then
    if text:find("explor") then
      crawl.sendkeys({ 6, "altar\r" })
    elseif text:find("welcomes you!") then
      crawl.sendkeys("X<\r")
    end
  end
end

---- Stop on Pan Gates ----
local function ready_stop_on_pan_gates()
  local branch = you.branch()
  if stop_on_pan_gates and branch ~= "Pan" then
    stop_on_pan_gates = false
    crawl.setopt("explore_stop -= stairs")
  elseif not stop_on_pan_gates and branch == "Pan" then
    stop_on_pan_gates = true
    crawl.setopt("explore_stop += stairs")
  end
end


---------------- Hooks ----------------
function ready_runrest_features()
  if CONFIG.ignore_altars then ready_ignore_altars() end
  if CONFIG.ignore_portal_exits then ready_ignore_exits() end
  if CONFIG.stop_on_pan_gates then ready_stop_on_pan_gates() end
end

function c_message_runrest_features(text, _)
  if CONFIG.search_altars_in_temple then c_message_search_altars_in_temple(text, _) end
end
