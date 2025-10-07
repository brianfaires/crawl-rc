--[[
Feature: misc-alerts
Description: Provides various single-purpose alerts: low HP, faith amulet, and spell level changes
Author: orig save w/msg by gammafunk, buehler
Dependencies: core/constants.lua, core/data.lua, core/util.lua
--]]

f_misc_alerts = {}
f_misc_alerts.BRC_FEATURE_NAME = "misc-alerts"
f_misc_alerts.Config = {
  alert_low_hp_threshold = 0.35, -- % max HP to alert; 0 to disable
  alert_remove_faith = true, -- Reminder to remove amulet at max piety
  alert_spell_level_changes = true, -- Alert when you gain additional spell levels
  save_with_msg = true, -- Shift-S to save and leave yourself a message
} -- f_misc_alerts.Config (do not remove this comment)

-- Persistent variables
ma_alerted_max_piety = BRC.Data.persist("ma_alerted_max_piety", false)
ma_prev_spell_levels = BRC.Data.persist("ma_prev_spell_levels", 0)
ma_saved_msg = BRC.Data.persist("ma_saved_msg", "")

-- Local config
local Config = f_misc_alerts.Config

-- Local constants / configuration
local REMOVE_FAITH_MSG = "6 star piety! Maybe ditch that amulet soon."

-- Local variables
local below_hp_threshold

-- Local functions
local function alert_low_hp()
  local hp, mhp = you.hp()
  if below_hp_threshold then
    below_hp_threshold = hp ~= mhp
  elseif hp <= Config.alert_low_hp_threshold * mhp then
    below_hp_threshold = true
    local low_hp_msg = string.format(" Dropped below %s%% HP ", 100 * Config.alert_low_hp_threshold)
    BRC.mpr.que_optmore(true, BRC.EMOJI.EXCLAMATION .. BRC.text.magenta(low_hp_msg) .. BRC.EMOJI.EXCLAMATION)
  end
end

local function alert_remove_faith()
  if not ma_alerted_max_piety and you.piety_rank() == 6 then
    local am = items.equipped_at("amulet")
    if am and am.subtype() == "amulet of faith" and not am.artefact then
      if you.god() == "Uskayaw" then return end
      BRC.mpr.more(REMOVE_FAITH_MSG, BRC.COLOR.lightcyan)
      ma_alerted_max_piety = true
    end
  end
end

local function alert_spell_level_changes()
  local new_spell_levels = you.spell_levels()
  if new_spell_levels > ma_prev_spell_levels then
    local delta = new_spell_levels - ma_prev_spell_levels
    local msg = string.format("Gained %s spell level%s", delta, delta > 1 and "s" or "")
    local avail = string.format(" (%s available)", new_spell_levels)
    BRC.mpr.lightcyan(msg .. BRC.text.cyan(avail))
  elseif new_spell_levels < ma_prev_spell_levels then
    BRC.mpr.magenta(string.format("%s spell levels remaining", new_spell_levels))
  end

  ma_prev_spell_levels = new_spell_levels
end

-- Macro function: Save with message feature
function macro_f_misc_alerts_save_with_message()
  if not BRC.active then return BRC.util.do_cmd("CMD_SAVE_GAME_NOW") end

  if not BRC.mpr.yesno("Save game and exit?", BRC.COLOR.lightcyan) then
    BRC.mpr.okay()
    return
  end

  crawl.formatted_mpr("Leave a message: ", "prompt")
  ma_saved_msg = crawl.c_input_line()
  BRC.util.do_cmd("CMD_SAVE_GAME_NOW")
end

-- Hook functions
function f_misc_alerts.init()
  ma_prev_spell_levels = you.spell_levels()
  below_hp_threshold = false

  if Config.save_with_msg then
    BRC.set.macro(BRC.get.command_key("CMD_SAVE_GAME") or "S", "macro_f_misc_alerts_save_with_message")
    if ma_saved_msg and ma_saved_msg ~= "" then
      BRC.mpr.white(string.format("MESSAGE: %s", ma_saved_msg))
      ma_saved_msg = nil
    end
  end
end

function f_misc_alerts.ready()
  if Config.alert_remove_faith then alert_remove_faith() end
  if Config.alert_low_hp_threshold > 0 then alert_low_hp() end
  if Config.alert_spell_level_changes then alert_spell_level_changes() end
end
