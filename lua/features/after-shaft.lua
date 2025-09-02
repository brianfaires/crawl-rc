--[[
Feature: after-shaft
Description: Automatically stops exploration on stairs after falling into a shaft
Author: buehler
Dependencies: CONFIG, create_persistent_data, in_hell
--]]

f_after_shaft = {}
f_after_shaft.BRC_FEATURE_NAME = "after-shaft"

-- Hook functions
function f_after_shaft.init()
    if not CONFIG.stop_on_stairs_after_shaft then return end
    if CONFIG.debug_init then crawl.mpr("Initializing after-shaft") end

    create_persistent_data("as_shaft_depth", 0)
    create_persistent_data("as_shaft_branch", "NA")

    if you.turns() == 0 and you.class() == "Delver" then
        as_shaft_depth = 1
        as_shaft_branch = you.branch()
    end

    if as_shaft_depth ~= 0 then
        crawl.setopt("explore_stop += stairs")
    else
        crawl.setopt("explore_stop -= stairs")
    end
end

function f_after_shaft.c_message(text, channel)
    if not CONFIG.stop_on_stairs_after_shaft then return end
    if channel ~= "plain" or in_hell() then return end
    if as_shaft_depth ~= 0 and you.branch() == as_shaft_branch then return end

    local text_fall = "ou fall into a shaft"
    local text_sucked = "ou are sucked into a shaft"
    if text:find(text_fall, 1, true) or text:find(text_sucked, 1, true) then
        as_shaft_depth = you.depth()
        as_shaft_branch = you.branch()
        crawl.setopt("explore_stop += stairs")
    end
end

function f_after_shaft.ready()
    if not CONFIG.stop_on_stairs_after_shaft then return end
    if you.depth() == as_shaft_depth and you.branch() == as_shaft_branch then
        crawl.setopt("explore_stop -= stairs")
        as_shaft_depth = 0
        as_shaft_branch = "NA"
    end
end
