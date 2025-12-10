---------------------------------------------------------------------------------------------------
-- BRC feature module: go-up-macro
-- @module f_go_up_macro
-- Handles orb run mechanics: HP-based monster ignore for cntl-E macro
---------------------------------------------------------------------------------------------------

f_go_up_macro = {}
f_go_up_macro.BRC_FEATURE_NAME = "go-up-macro"
f_go_up_macro.Config = {
  go_up_macro_key = BRC.util.cntl("e"), -- Key for "go up closest stairs" macro

  ignore_mon_on_orb_run = true, -- Ignore monsters on orb run
  -- %HP thresholds for ignoring monsters during orb run (2-7 tiles away, depending on HP percent)
  orb_ignore_hp_min = 0.30, -- HP percent to stop ignoring monsters
  orb_ignore_hp_max = 0.70, -- HP percent to ignore monsters at min distance away (2 tiles)
} -- f_go_up_macro.Config (do not remove this comment)

---- Local variables ----
local orb_ignore_distance

---- Local functions ----
local function set_orb_ignore_distance(distance)
  if orb_ignore_distance then
    BRC.opt.runrest_ignore_monster(".*:" .. orb_ignore_distance, false)
    orb_ignore_distance = nil
  end
  if distance then
    orb_ignore_distance = distance
    BRC.opt.runrest_ignore_monster(".*:" .. orb_ignore_distance, true)
  end
end

--- Get distance (2 - 7) to ignore monsters based on HP percent
local function get_ignore_distance_from_hp()
  local hp, mhp = you.hp()
  local hp_pct = hp / mhp
  local min_pct = f_go_up_macro.Config.orb_ignore_hp_min
  local max_pct = f_go_up_macro.Config.orb_ignore_hp_max

  if hp_pct <= min_pct then return nil end
  if hp_pct >= max_pct then return 2 end

  -- Linear interpolation between min_pct and max_pct
  local ratio = (hp_pct - min_pct) / (max_pct - min_pct)
  return math.floor(2 + ratio * (you.los() - 2))
end

---- Initialization ----
function f_go_up_macro.init()
  BRC.opt.macro(f_go_up_macro.Config.go_up_macro_key, "macro_brc_go_up")
end

---- Macro function ----
--- Go up the closest stairs (Cntl-E)
function macro_brc_go_up()
  if BRC.active == false or f_go_up_macro.Config.disabled then return end

  if you.have_orb() and f_go_up_macro.Config.ignore_mon_on_orb_run then
    local distance = get_ignore_distance_from_hp()
    if distance ~= orb_ignore_distance then set_orb_ignore_distance(distance) end
  end

  -- Go up closest stairs; different macro for D:1 and portals
  local where = you.where()
  if where == "D:1" and you.have_orb()
    or where == "Temple"
    or util.contains(BRC.PORTAL_FEATURE_NAMES, you.branch())
    or BRC.you.in_hell(true)
  then
    crawl.sendkeys({ "X", "<", "\r", BRC.KEYS.ESC, "<" }) -- {ESC, <} handles standing on stairs
  else
    crawl.sendkeys({ BRC.util.cntl("g"), "<" })
  end
  crawl.flush_input()
end

