-- A collection of simple features related to resting and auto-explore stops
local stop_on_altars
local stop_on_portals
local stop_on_pan_gates
local autosearched_temple
local autosearched_gauntlet


---- Gauntlet actions ----
local function ready_gauntlet_macro()
  if CACHE.branch == "Gauntlet" and not autosearched_gauntlet then
    crawl.sendkeys({ 6, ".\r" })
    autosearched_gauntlet = true
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

---- Ignore exit portals ----
local function ready_ignore_exits()
  if stop_on_portals and util.contains(ALL_PORTAL_NAMES, CACHE.branch) then
    stop_on_portals = false
    crawl.setopt("explore_stop -= portals")
  elseif not stop_on_portals and not util.contains(ALL_PORTAL_NAMES, CACHE.branch) then
    stop_on_portals = true
    crawl.setopt("explore_stop += portals")
  end
end

---- Stop on Pan Gates ----
local function ready_stop_on_pan_gates()
  local branch = CACHE.branch
  if stop_on_pan_gates and branch ~= "Pan" then
    stop_on_pan_gates = false
    crawl.setopt("explore_stop -= stairs")
  elseif not stop_on_pan_gates and branch == "Pan" then
    stop_on_pan_gates = true
    crawl.setopt("explore_stop += stairs")
  end
end

---- Temple actions ----
local function ready_temple_macro()
  if CACHE.branch == "Temple" and not autosearched_temple and CACHE.god == "No God" then
    crawl.sendkeys({ 6, "altar\r" })
    autosearched_temple = true
  end
end

local function c_message_temple_actions(text, _)
  if CACHE.branch == "Temple" then
    -- Hit explore to search all altars
    if text:find("explor") then
      crawl.sendkeys({ 6, "altar\r" })
    elseif text:find("welcomes you!") then
      -- Run to staircase after worship
      crawl.sendkeys("X<\r")
    end
  end
end


function init_runrest_features()
  if CONFIG.debug_init then crawl.mpr("Initializing runrest-features") end

  stop_on_altars = true
  stop_on_portals = true
  stop_on_pan_gates = false
  autosearched_temple = false
  autosearched_gauntlet = false
end


---------------- Hooks ----------------
function c_message_runrest_features(text, _)
  if CONFIG.temple_macros then c_message_temple_actions(text, _) end
end

function ready_runrest_features()
  if CONFIG.ignore_altars then ready_ignore_altars() end
  if CONFIG.ignore_portal_exits then ready_ignore_exits() end
  if CONFIG.stop_on_pan_gates then ready_stop_on_pan_gates() end
  if CONFIG.temple_macros then ready_temple_macro() end
  if CONFIG.gauntlet_macros then ready_gauntlet_macro() end
end
