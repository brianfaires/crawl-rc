---------------------------------------------------------------------------------------------------
-- BRC feature module: runrest-features
-- @module f_runrest_features
-- Simple features related to auto-explore stops: altars, gauntlets, portals, stairs, etc.
---------------------------------------------------------------------------------------------------

f_runrest_features = {}
f_runrest_features.BRC_FEATURE_NAME = "runrest-features"
f_runrest_features.Config = {
  after_shaft = true, -- stop on stairs after being shafted, until returned to original floor
  ignore_altars = true, -- when you don't need a god
  ignore_portal_exits = true, -- don't stop explore on portal exits
  stop_on_hell_stairs = true, -- stop explore on hell stairs
  stop_on_pan_gates = true, -- stop explore on pan gates
  temple_search = true, -- on entering or exploring temple, auto-search
  gauntlet_search = true, -- on entering or exploring gauntlet, auto-search with filters
  necropolis_search = true, -- on exploring necropolis, auto-search with filters
} -- f_runrest_features.Config (do not remove this comment)

---- Persistent variables ----
rr_autosearched_temple = BRC.Data.persist("rr_autosearched_temple", false)
rr_autosearched_gauntlet = BRC.Data.persist("rr_autosearched_gauntlet", false)
rr_shaft_location = BRC.Data.persist("rr_shaft_location", nil)

---- Local constants ----
local CONCAT_STRING = " && !!"
local SEARCH_FILTERS = table.concat({
  "gate leading", "a transporter", "gold piece",
  " trap", "translucent door", "translucent gate"
  }, CONCAT_STRING)
local SEARCH_STRING = {
  Gauntlet = "gauntlet" .. CONCAT_STRING .. SEARCH_FILTERS,
  Necropolis = "necropolis" .. CONCAT_STRING .. SEARCH_FILTERS,
} -- SEARCH_STRING (do not remove this comment)

---- Local variables ----
local C -- config alias
local stop_on_altars
local stop_on_portals
local stop_on_stairs

---- Initialization ----
function f_runrest_features.init()
  C = f_runrest_features.Config
  stop_on_altars = true
  stop_on_portals = true
  stop_on_stairs = false

  if you.turns() == 0 and you.class() == "Delver" then rr_shaft_location = "D:1" end
end

---- Local functions ----
local function is_explore_done_msg(text)
  local cleaned = BRC.txt.clean(text)
  return cleaned == "Done exploring."
    or cleaned:find("Partly explored, ", 1, true) == 1
    or cleaned:find("Could not explore, unopened runed ", 1, true) == 1
end

local function set_stairs_stop_state()
  local should_be_active = C.stop_on_pan_gates and you.branch() == "Pan"
    or C.stop_on_hell_stairs and BRC.you.in_hell(true)
    or C.after_shaft and rr_shaft_location ~= nil

  if stop_on_stairs and not should_be_active then
    stop_on_stairs = false
    BRC.opt.explore_stop("stairs", false)
  elseif not stop_on_stairs and should_be_active then
    stop_on_stairs = true
    BRC.opt.explore_stop("stairs", true)
  end
end

-- Altar/Religion functions
local function religion_is_handled()
  if you.race() == "Demigod" then return true end
  if you.god() == "No God" then return false end
  if you.good_god() then return you.xl() > 9 end
  return true
end

local function ready_ignore_altars()
  if stop_on_altars and religion_is_handled() then
    stop_on_altars = false
    BRC.opt.explore_stop("altars", false)
  elseif not stop_on_altars and not religion_is_handled() then
    stop_on_altars = true
    BRC.opt.explore_stop("altars", true)
  end
end

-- Temple functions
local function search_altars()
  local cmd_key = BRC.util.get_cmd_key("CMD_SEARCH_STASHES") or BRC.util.cntl("f")
  crawl.sendkeys({ cmd_key, "altar", "\r" })
  crawl.flush_input()
end

local function ready_temple_macro()
  if you.branch() == "Temple" and not rr_autosearched_temple then
    search_altars()
    rr_autosearched_temple = true
  end
end

local function c_message_temple(text, _)
  if you.branch() == "Temple" then
    -- Search again after explore
    if is_explore_done_msg(text) then search_altars() end
  end
end

-- Filtered search functions (Gauntlet & Necropolis)
local function search_filtered(branch)
  local cmd_key = BRC.util.get_cmd_key("CMD_SEARCH_STASHES") or BRC.util.cntl("f")
  crawl.sendkeys({ cmd_key, SEARCH_STRING[branch], "\r" })
  crawl.flush_input()
end

--- Autosearch Gauntlet upon entry (not necropolis)
local function ready_gauntlet_macro()
  local branch = you.branch()
  if branch == "Gauntlet" and not rr_autosearched_gauntlet then
    search_filtered(branch)
    rr_autosearched_gauntlet = true
  end
end

local function c_message_filtered_search(text, _)
  -- Search again after explore
  local branch = you.branch()
  if is_explore_done_msg(text) and (
    C.necropolis_search and branch == "Necropolis"
    or C.gauntlet_search and branch == "Gauntlet"
  ) then
    search_filtered(branch)
  end
end

-- Portal exit functions
local function ready_ignore_portals()
  local in_portal = util.contains(BRC.PORTAL_FEATURE_NAMES, you.branch())
  if stop_on_portals and in_portal then
    stop_on_portals = false
    BRC.opt.explore_stop("portals", false)
  elseif not stop_on_portals and not in_portal then
    stop_on_portals = true
    BRC.opt.explore_stop("portals", true)
  end
end

-- After shaft functions
local function c_message_after_shaft(text, channel)
  if channel ~= "plain" or rr_shaft_location then return end
  if text:find("ou .* into a shaft") and not BRC.you.in_hell(true) then
    rr_shaft_location = you.where()
  end
end

local function ready_after_shaft()
  if you.where() == rr_shaft_location then rr_shaft_location = nil end
end

---- Crawl hook functions ----
function f_runrest_features.c_message(...)
  if C.temple_search then c_message_temple(...) end
  if C.gauntlet_search or C.necropolis_search then c_message_filtered_search(...) end
  if C.after_shaft then c_message_after_shaft(...) end
end

function f_runrest_features.ready()
  if C.ignore_altars then ready_ignore_altars() end
  if C.ignore_portal_exits then ready_ignore_portals() end
  if C.temple_search then ready_temple_macro() end
  if C.gauntlet_search then ready_gauntlet_macro() end
  if C.after_shaft then ready_after_shaft() end
  set_stairs_stop_state()
end
