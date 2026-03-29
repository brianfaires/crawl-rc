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
  emoji = "🕒",
  init = function()
    if not BRC.Config.emojis then
      f_display_realtime.Config.emoji = BRC.txt.white("--")
    end
  end,
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
    local h = dr_total_time // 3600
    local remain = dr_total_time % 3600
    local m = remain // 60
    local s = remain % 60
    local time_str
    if h > 0 then
      time_str = string.format("Game time: %d:%02d:%02d", h, m, s)
    else
      time_str = string.format("Game time: %d:%02d", m, s)
    end

    BRC.mpr.white(BRC.txt.wrap(time_str, f_display_realtime.Config.emoji))
    last_cycle = cycle
  end
  last_time = you.real_time()
end
