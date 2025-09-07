--[[
Feature: runrest-features
Description: Simple features related to auto-explore stops: altars, gauntlets, portals, stairs, etc
Author: buehler
Dependencies: core/config.lua, core/data.lua, core/constants.lua, core/util.lua
--]]

f_runrest_features = {}
f_runrest_features.BRC_FEATURE_NAME = "runrest-features"

-- Persistent variables
rr_autosearched_temple = BRC.data.persist("rr_autosearched_temple", false)
rr_autosearched_gauntlet = BRC.data.persist("rr_autosearched_gauntlet", false)

-- Local variables
local stop_on_altars
local stop_on_portals
local stop_on_pan_gates
local stop_on_hell_stairs

-- Local functions
local function search_gauntlet()
  crawl.sendkeys({
    6,
    "gauntlet && !!leading && !!transporter && !!pieces && !!trap\r",
  })
end

local function ready_gauntlet_macro()
  if you.branch() == "Gauntlet" and not rr_autosearched_gauntlet then
    search_gauntlet()
    rr_autosearched_gauntlet = true
  end
end

local function c_message_gauntlet(text, _)
  -- Search again with CMD_EXPLORE
  if you.branch() == "Gauntlet" then
    if text:find("explor", 1, true) then search_gauntlet() end
  end
end

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

local function ready_ignore_exits()
  if stop_on_portals and util.contains(BRC.ALL_PORTAL_NAMES, you.branch()) then
    stop_on_portals = false
    BRC.set.explore_stop("portals", false)
  elseif not stop_on_portals and not util.contains(BRC.ALL_PORTAL_NAMES, you.branch()) then
    stop_on_portals = true
    BRC.set.explore_stop("portals", true)
  end
end

local function ready_stop_on_pan_gates()
  local branch = you.branch()
  if stop_on_pan_gates and branch ~= "Pan" then
    stop_on_pan_gates = false
    BRC.set.explore_stop("stairs", false)
  elseif not stop_on_pan_gates and branch == "Pan" then
    stop_on_pan_gates = true
    BRC.set.explore_stop("stairs", true)
  end
end

local function ready_stop_on_hell_stairs()
  if stop_on_hell_stairs and not BRC.you.in_hell() then
    stop_on_hell_stairs = false
    BRC.set.explore_stop("stairs", false)
  elseif not stop_on_hell_stairs and BRC.you.in_hell() then
    stop_on_hell_stairs = true
    BRC.set.explore_stop("stairs", true)
  end
end

local function search_altars()
  crawl.sendkeys({ 6, "altar\r" })
end

local function ready_temple_macro()
  if you.branch() == "Temple" and not rr_autosearched_temple then
    search_altars()
    rr_autosearched_temple = true
  end
end

local function c_message_temple(text, _)
  if you.branch() == "Temple" then
    -- Search again with CMD_EXPLORE
    if text:find("explor", 1, true) then
      search_altars()
    elseif text:find("welcomes you!", 1, true) then
      -- Run to staircase after worship
      BRC.mpr.que("Ran to temple exit.", BRC.COLORS.darkgrey)
      crawl.sendkeys("X<\r")
    end
  end
end

-- Hook functions
function f_runrest_features.init()
  stop_on_altars = true
  stop_on_portals = true
  stop_on_pan_gates = false
  stop_on_hell_stairs = false
end

function f_runrest_features.c_message(text, _)
  if BRC.Config.temple_macros then c_message_temple(text, _) end
  if BRC.Config.gauntlet_macros then c_message_gauntlet(text, _) end
end

function f_runrest_features.ready()
  if BRC.Config.ignore_altars then ready_ignore_altars() end
  if BRC.Config.ignore_portal_exits then ready_ignore_exits() end
  if BRC.Config.stop_on_pan_gates then ready_stop_on_pan_gates() end
  if BRC.Config.stop_on_hell_stairs then ready_stop_on_hell_stairs() end
  if BRC.Config.temple_macros then ready_temple_macro() end
  if BRC.Config.gauntlet_macros then ready_gauntlet_macro() end
end
