--[[
Feature: runrest-features
Description: Simple features related to auto-explore stops: altars, gauntlets, portals, stairs, etc
Author: buehler
Dependencies: core/config.lua, core/data.lua, core/constants.lua, core/util.lua
--]]

f_runrest_features = {}
f_runrest_features.BRC_FEATURE_NAME = "runrest-features"
f_runrest_features.Config = {
  ignore_altars = true, -- when you have a god already
  ignore_portal_exits = true, -- don't stop explore on portal exits
  stop_on_hell_stairs = true, -- stop explore on hell stairs
  stop_on_pan_gates = true, -- stop explore on pan gates
  temple_search = true,  -- on enter or explore, auto-search altars
  gauntlet_search = true,  -- on enter or explore, auto-search gauntlet with filters
} -- f_runrest_features.Config (do not remove this comment)

-- Persistent variables
rr_autosearched_temple = BRC.data.persist("rr_autosearched_temple", false)
rr_autosearched_gauntlet = BRC.data.persist("rr_autosearched_gauntlet", false)

-- Local config
local Config = f_runrest_features.Config

-- Local constants / configuration
local GAUNTLET_CONCAT_STRING = " && !!"
local GAUNTLET_SEARCH_STRING = table.concat(
  { "gauntlet", "gate leading", "a transporter", "gold piece", " trap", "translucent door", "translucent gate" },
  GAUNTLET_CONCAT_STRING
)

-- Local variables
local stop_on_altars
local stop_on_portals
local stop_on_stairs

-- Local functions
local function is_explore_done_msg(text)
  local cleaned = BRC.text.clean(text)
  return cleaned == "Done exploring." or cleaned:find("Partly explored, ", 1, true) == 1
end

-- Altar and religion functions
local function religion_is_handled()
  if you.race() == "Demigod" then return true end
  if you.god() == "No God" then return false end
  if you.good_god() then return you.xl() > 9 end
  return true
end

local function ready_ignore_altars()
  if stop_on_altars and religion_is_handled() then
    stop_on_altars = false
    BRC.set.explore_stop("altars", false)
  elseif not stop_on_altars and not religion_is_handled() then
    stop_on_altars = true
    BRC.set.explore_stop("altars", true)
  end
end

-- Temple-related functions
local function search_altars()
  local cmd_key = BRC.get.command_key("CMD_SEARCH_STASHES") or BRC.util.control_key("f")
  crawl.sendkeys({ cmd_key, "altar", BRC.KEYS.CR })
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

-- Gauntlet-related functions
local function search_gauntlet()
  local cmd_key = BRC.get.command_key("CMD_SEARCH_STASHES") or BRC.util.control_key("f")
  crawl.sendkeys({ cmd_key, GAUNTLET_SEARCH_STRING, BRC.KEYS.CR })
end

local function ready_gauntlet_macro()
  if you.branch() == "Gauntlet" and not rr_autosearched_gauntlet then
    search_gauntlet()
    rr_autosearched_gauntlet = true
  end
end

local function c_message_gauntlet(text, _)
  -- Search again after explore
  if you.branch() == "Gauntlet" then
    if is_explore_done_msg(text) then search_gauntlet() end
  end
end

-- Stairs and branch-specific functions
local function ready_ignore_portals()
  if stop_on_portals and util.contains(BRC.PORTAL_NAMES, you.branch()) then
    stop_on_portals = false
    BRC.set.explore_stop("portals", false)
  elseif not stop_on_portals and not util.contains(BRC.PORTAL_NAMES, you.branch()) then
    stop_on_portals = true
    BRC.set.explore_stop("portals", true)
  end
end

local function ready_stop_on_stairs_in_pan_or_hell()
  local should_be_active = Config.stop_on_pan_gates and you.branch() == "Pan"
    or Config.stop_on_hell_stairs and BRC.you.in_hell(true)
  if stop_on_stairs and not should_be_active then
    stop_on_stairs = false
    BRC.set.explore_stop("stairs", false)
  elseif not stop_on_stairs and should_be_active then
    stop_on_stairs = true
    BRC.set.explore_stop("stairs", true)
  end
end

-- Hook functions
function f_runrest_features.init()
  stop_on_altars = true
  stop_on_portals = true
  stop_on_stairs = false
end

function f_runrest_features.c_message(text, _)
  if Config.temple_search then c_message_temple(text) end
  if Config.gauntlet_search then c_message_gauntlet(text) end
end

function f_runrest_features.ready()
  if Config.ignore_altars then ready_ignore_altars() end
  if Config.ignore_portal_exits then ready_ignore_portals() end
  if Config.temple_search then ready_temple_macro() end
  if Config.gauntlet_search then ready_gauntlet_macro() end
  ready_stop_on_stairs_in_pan_or_hell()
end
