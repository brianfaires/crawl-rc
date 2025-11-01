---------------------------------------------------------------------------------------------------
-- BRC feature module: safe-stairs
-- @module f_safe_stairs
-- @author rypofalem (V:5 warning idea), buehler
-- Prevent accidental stairs use and warn for Vaults:5 entry.
---------------------------------------------------------------------------------------------------

f_safe_stairs = {}
f_safe_stairs.BRC_FEATURE_NAME = "safe-stairs"
f_safe_stairs.Config = {
  warn_backtracking = true, -- Warn if immediately taking stairs twice in a row
  warn_v5 = true, -- Prompt before entering Vaults:5
} -- f_safe_stairs.Config (do not remove this comment)

---- Persistent variables ----
ss_prev_location = BRC.Data.persist("ss_prev_location", you.where())
ss_v5_warned = BRC.Data.persist("ss_v5_warned", false)

---- Local config alias ----
local Config = f_safe_stairs.Config

---- Local variables ----
local ss_cur_location

---- Local functions ----
local function check_new_location(cmd)
  local feature = view.feature_at(0, 0)

  if Config.warn_backtracking and ss_prev_location ~= ss_cur_location then
    if
      cmd == "CMD_GO_DOWNSTAIRS" and (feature:contains("down") or feature:contains("shaft"))
      or cmd == "CMD_GO_UPSTAIRS" and feature:contains("up")
    then
      if not BRC.mpr.yesno("Really go right back?") then return BRC.mpr.okay() end
    end
  end

  if
    Config.warn_v5
    and not ss_v5_warned
    and ss_cur_location == "Vaults:4"
    and cmd == "CMD_GO_DOWNSTAIRS"
    and (feature:contains("down") or feature:contains("shaft"))
  then
    if not BRC.mpr.yesno("Really go to Vaults:5?") then return BRC.mpr.okay() end
    ss_v5_warned = true
  end

  BRC.util.do_cmd(cmd)
end

---- Macro functions ----
function macro_brc_downstairs()
  if BRC.active and not f_safe_stairs.Config.disabled then
    check_new_location("CMD_GO_DOWNSTAIRS")
  else
    BRC.util.do_cmd("CMD_GO_DOWNSTAIRS")
  end
end

function macro_brc_upstairs()
  if BRC.active and not f_safe_stairs.Config.disabled then
    check_new_location("CMD_GO_UPSTAIRS")
  else
    BRC.util.do_cmd("CMD_GO_UPSTAIRS")
  end
end

---- Hook functions ----
function f_safe_stairs.init()
  ss_cur_location = you.where()

  BRC.opt.macro(BRC.util.get_cmd_key("CMD_GO_DOWNSTAIRS") or ">", "macro_brc_downstairs")
  BRC.opt.macro(BRC.util.get_cmd_key("CMD_GO_UPSTAIRS") or "<", "macro_brc_upstairs")
end

function f_safe_stairs.ready()
  ss_prev_location = ss_cur_location
  ss_cur_location = you.where()
end
