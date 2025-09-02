--[[
Feature: drop-inferior
Description: Auto-tags inferior items and adds them to the drop list for quick dropping with ","
Author: buehler
Dependencies: CONFIG, COLORS, with_color, has_risky_ego, has_ego, get_ego, get_armour_ac, iter.invent_iterator
--]]

f_drop_inferior = {}
f_drop_inferior.BRC_FEATURE_NAME = "drop-inferior"

-- Local constants
local DROP_KEY = "~~DROP_ME"

-- Local functions
local function inscribe_drop(it)
    local new_inscr = it.inscription:gsub(DROP_KEY, "") .. DROP_KEY
    it.inscribe(new_inscr, false)
    if CONFIG.msg_on_inscribe then
        local msg = "(You can drop " .. it.slot .. " - " ..it.name() .. ")"
        crawl.mpr(with_color(COLORS.cyan, msg))
    end
end

-- Hook functions
function f_drop_inferior.init()
    if not CONFIG.drop_inferior then return end
    crawl.setopt("drop_filter += " .. DROP_KEY)
end

function f_drop_inferior.c_assign_invletter(it)
    if not CONFIG.drop_inferior then return end
    -- Remove any previous DROP_KEY inscriptions
    it.inscribe(it.inscription:gsub(DROP_KEY, ""), false)

    if not (it.is_weapon or is_armour(it)) then return end
    if has_risky_ego(it) then return end

    for inv in iter.invent_iterator:new(items.inventory()) do
        if not inv.artefact and inv.subtype() == it.subtype() and
            (not has_ego(inv) or get_ego(inv) == get_ego(it)) then
                if it.is_weapon then
                    if you.race() == "Coglin" then return end -- More trouble than it's worth
                    if inv.plus <= it.plus then inscribe_drop(inv) end
                else
                    if get_armour_ac(inv) <= get_armour_ac(it) and inv.encumbrance >= it.encumbrance then
                        if you.race() == "Poltergeist" then return end -- More trouble than it's worth 
                        inscribe_drop(inv)
                    end
                end
        end
    end
end
