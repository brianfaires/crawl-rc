--[[
Feature: misc-alerts
Description: Provides various single-purpose alerts: low HP, faith amulet, and spell level changes
Author: buehler, gammafunk
Dependencies: CONFIG, BRC.COLORS, CONSTANTS, EMOJI, util, persistent_data
--]]

f_misc_alerts = {}
f_misc_alerts.BRC_FEATURE_NAME = "misc-alerts"

-- Persistent variables
ma_alerted_max_piety = BRC.data.persist("ma_alerted_max_piety", false)
ma_prev_spell_levels = BRC.data.persist("ma_prev_spell_levels", 0)
ma_saved_msg = BRC.data.persist("ma_saved_msg", "")

-- Local constants / configuration
local REMOVE_FAITH_MSG = "6 star piety! Maybe ditch that amulet soon."

-- Local variables
local below_hp_threshold

-- Local functions
local function alert_low_hp()
  local hp, mhp = you.hp()
  if below_hp_threshold then
    below_hp_threshold = hp ~= mhp
  elseif hp <= BRC.Config.alert_low_hp_threshold * mhp then
    below_hp_threshold = true
    local low_hp_msg = string.format(" Dropped below %s%% HP ", 100 * BRC.Config.alert_low_hp_threshold)
    BRC.mpr.que_optmore(true, BRC.Emoji.EXCLAMATION .. BRC.text.magenta(low_hp_msg) .. BRC.Emoji.EXCLAMATION)
  end
end

local function alert_remove_faith()
  if not ma_alerted_max_piety and you.piety_rank() == 6 then
    local am = items.equipped_at("amulet")
    if am and am.subtype() == "amulet of faith" and not am.artefact then
      if you.god() == "Uskayaw" then return end
      BRC.mpr.more(REMOVE_FAITH_MSG, BRC.COLORS.lightcyan)
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
    crawl.mpr(BRC.text.lightcyan(msg) .. BRC.text.cyan(avail))
  elseif new_spell_levels < ma_prev_spell_levels then
    BRC.mpr.color(string.format("%s spell levels remaining", new_spell_levels), BRC.COLORS.magenta)
  end

  ma_prev_spell_levels = new_spell_levels
end

-- Save with message functionality
-- by gammafunk, edits by buehler
function f_misc_alerts.macro_save_w_message()
  crawl.formatted_mpr("Save game and exit? (y/n)", "prompt")
  local res = crawl.getch()
  if not (string.char(res) == "y" or string.char(res) == "Y") then
    crawl.mpr("Okay, then.")
    return
  end
  crawl.formatted_mpr("Leave a message: ", "prompt")
  ma_saved_msg = crawl.c_input_line()
  crawl.sendkeys(BRC.text.letter_to_ascii("s"))
end

-- Hook functions
function f_misc_alerts.init()
  ma_prev_spell_levels = you.spell_levels()
  below_hp_threshold = false

  if BRC.Config.save_with_msg then
    crawl.setopt(string.format("macros += M %s ===f_misc_alerts.macro_save_w_message", BRC.KEYS.save_game))
    if ma_saved_msg and ma_saved_msg ~= "" then
      crawl.mpr(string.format("MESSAGE: %s", ma_saved_msg))
      ma_saved_msg = nil
    end
  end
end

function f_misc_alerts.ready()
  if BRC.Config.alert_remove_faith then alert_remove_faith() end
  if BRC.Config.alert_low_hp_threshold > 0 then alert_low_hp() end
  if BRC.Config.alert_spell_level_changes then alert_spell_level_changes() end
end
