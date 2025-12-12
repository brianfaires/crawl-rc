---------------------------------------------------------------------------------------------------
-- BRC feature module: display-realtime
-- @module f_display_realtime
-- Display the realtime periodically in the output channel.
---------------------------------------------------------------------------------------------------

f_display_realtime = {}
f_display_realtime.BRC_FEATURE_NAME = "display-realtime"
f_display_realtime.Config = {
  disabled = true, -- Disabled by default
  interval_s = 60, -- seconds between updates
  emoji = BRC.Config.emojis and "🕒" or "--",
} -- f_display_realtime.Config (do not remove this comment)

---- Persistent variables ----
dr_total_time = BRC.Data.persist("dr_total_time", 0)

---- Local variables ----
local last_time
local last_cycle

---- Initialization ----
function f_display_realtime.init()
  last_time = you.real_time()
  last_cycle = 0
end

---- Crawl hook functions ----
function f_display_realtime.ready()
  dr_total_time = dr_total_time + you.real_time() - last_time
  local cycle = dr_total_time // f_display_realtime.Config.interval_s
  if cycle > last_cycle then
    local time_str = "Game time: "
    if dr_total_time > 3600 then time_str = time_str .. (dr_total_time // 3600) .. ":" end
    local remain = dr_total_time % 3600
    time_str = time_str .. (remain // 60) .. ":" .. (remain % 60)

    BRC.mpr.white(BRC.txt.wrap(time_str, f_display_realtime.Config.emoji))
    last_cycle = cycle
  end
  last_time = you.real_time()
end
