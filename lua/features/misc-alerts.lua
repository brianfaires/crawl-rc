---------------------------------------------------------------------------------------------------
-- BRC feature module: misc-alerts
-- @module f_misc_alerts
-- @author gammafunk (save game w/ msg), buehler
-- Various single-purpose alerts: save game w/ msg, low HP, faith amulet, spell level changes.
---------------------------------------------------------------------------------------------------

f_misc_alerts = {}
f_misc_alerts.BRC_FEATURE_NAME = "misc-alerts"
f_misc_alerts.Config = {
  save_with_msg = true, -- Shift-S to save and leave yourself a message
  alert_low_hp_threshold = 35, -- % max HP to alert; 0 to disable
  alert_spell_level_changes = true, -- Alert when you gain additional spell levels
  alert_remove_faith = true, -- Reminder to remove amulet at max piety
  remove_faith_hotkey = true, -- Hotkey remove amulet
} -- f_misc_alerts.Config (do not remove this comment)

---- Persistent variables ----
ma_alerted_max_piety = BRC.Data.persist("ma_alerted_max_piety", false)
ma_saved_msg = BRC.Data.persist("ma_saved_msg", "")

---- Local constants ----
local REMOVE_FAITH_MSG = "6 star piety! Maybe ditch that amulet soon."

---- Local variables ----
local C -- config alias
local below_hp_threshold
local prev_spell_levels

---- Initialization ----
function f_misc_alerts.init()
  C = f_misc_alerts.Config
  below_hp_threshold = false
  prev_spell_levels = you.spell_levels()

  if C.save_with_msg then
    BRC.opt.macro(BRC.util.get_cmd_key("CMD_SAVE_GAME") or "S", "macro_brc_save")
    if ma_saved_msg and ma_saved_msg ~= "" then
      BRC.mpr.white("MESSAGE: " .. ma_saved_msg)
      ma_saved_msg = nil
    end
  end
end

---- Local functions ----
local function alert_low_hp()
  local hp, mhp = you.hp()
  if below_hp_threshold then
    below_hp_threshold = hp ~= mhp
  elseif hp <= mhp * C.alert_low_hp_threshold / 100 then
    below_hp_threshold = true
    local low_hp_msg = "Dropped below " .. C.alert_low_hp_threshold .. "% HP"
    BRC.mpr.que_optmore(true, BRC.txt.wrap(BRC.txt.magenta(low_hp_msg), BRC.EMOJI.EXCLAMATION))
  end
end

local function alert_remove_faith()
  if not ma_alerted_max_piety and you.piety_rank() == 6 then
    local am = items.equipped_at("amulet")
    if am and am.subtype() == "amulet of faith" and not am.artefact then
      if you.god() == "Uskayaw" then return end
      BRC.mpr.more(REMOVE_FAITH_MSG, BRC.COL.lightcyan)
      ma_alerted_max_piety = true
      if C.remove_faith_hotkey and BRC.Hotkey then
        BRC.Hotkey.set("remove", "amulet of faith", false, function()
          items.equipped_at("amulet"):remove()
        end)
      end
    end
  end
end

local function alert_spell_level_changes()
  local new_spell_levels = you.spell_levels()
  if new_spell_levels > prev_spell_levels then
    local delta = new_spell_levels - prev_spell_levels
    local msg = string.format("Gained %s spell level%s", delta, delta > 1 and "s" or "")
    local suffix = string.format(" (%s available)", new_spell_levels)
    BRC.mpr.lightcyan(msg .. BRC.txt.cyan(suffix))
  elseif new_spell_levels < prev_spell_levels then
    BRC.mpr.magenta(new_spell_levels .. " spell levels remaining")
  end

  prev_spell_levels = new_spell_levels
end

---- Macro function: Save with message feature ----
function macro_brc_save()
  if BRC.active == false
    or f_misc_alerts.Config.disabled
    or not f_misc_alerts.Config.save_with_msg
  then
    return BRC.util.do_cmd("CMD_SAVE_GAME")
  end

  if not BRC.mpr.yesno("Save game and exit?", BRC.COL.lightcyan) then
    BRC.mpr.okay()
    return
  end

  BRC.mpr.white("Leave a message: ", "prompt")
  ma_saved_msg = crawl.c_input_line()
  BRC.util.do_cmd("CMD_SAVE_GAME_NOW")
end

---- Crawl hook functions ----
function f_misc_alerts.ready()
  if C.alert_remove_faith then alert_remove_faith() end
  if C.alert_low_hp_threshold > 0 then alert_low_hp() end
  if C.alert_spell_level_changes then alert_spell_level_changes() end
end
