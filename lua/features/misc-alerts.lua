--[[
Feature: misc-alerts
Description: Provides various single-purpose alerts: low HP, faith amulet, and spell level changes
Author: buehler, gammafunk
Dependencies: CONFIG, COLORS, CONSTANTS, EMOJI, util, persistent_data
--]]

f_misc_alerts = {}
f_misc_alerts.BRC_FEATURE_NAME = "misc-alerts"

-- Constants
local REMOVE_FAITH_MSG = "6 star piety! Maybe ditch that amulet soon."

-- Local state
local below_hp_threshold
local prev_available_spell_levels = 0

-- Local functions
local function alert_low_hp()
  local hp, mhp = you.hp()
  if below_hp_threshold then
    below_hp_threshold = hp ~= mhp
  elseif hp <= CONFIG.alert_low_hp_threshold * mhp then
    below_hp_threshold = true
    local low_hp_msg = " Dropped below " .. (100 * CONFIG.alert_low_hp_threshold) .. "% HP "
    BRC.mpr.que_optmore(
      true,
      table.concat({
        EMOJI.EXCLAMATION,
        BRC.util.color(COLORS.magenta, low_hp_msg),
        EMOJI.EXCLAMATION,
      })
    )
  end
end

local function alert_remove_faith()
  if not alerted_max_piety and you.piety_rank() == 6 then
    local am = items.equipped_at("amulet")
    if am and am.subtype() == "amulet of faith" and not am.artefact then
      if you.god() == "Uskayaw" then return end
      BRC.mpr.more(REMOVE_FAITH_MSG, COLORS.lightcyan)
      alerted_max_piety = true
    end
  end
end

local function alert_spell_level_changes()
  local new_spell_levels = you.spell_levels()
  if new_spell_levels > prev_available_spell_levels then
    local delta = new_spell_levels - prev_available_spell_levels
    local msg = "Gained " .. delta .. " spell level" .. (delta > 1 and "s" or "")
    local avail = " (" .. new_spell_levels .. " available)"
    crawl.mpr(BRC.util.color(COLORS.lightcyan, msg) .. BRC.util.color(COLORS.cyan, avail))
  elseif new_spell_levels < prev_available_spell_levels then
    BRC.mpr.col(new_spell_levels .. " spell levels remaining", COLORS.magenta)
  end

  prev_available_spell_levels = new_spell_levels
end

-- Save with message functionality
-- by gammafunk, edits by buehler
function macro_save_with_message()
  crawl.formatted_mpr("Save game and exit? (y/n)", "prompt")
  local res = crawl.getch()
  if not (string.char(res) == "y" or string.char(res) == "Y") then
    crawl.mpr("Okay, then.")
    return
  end
  crawl.formatted_mpr("Leave a message: ", "prompt")
  saved_game_msg = crawl.c_input_line()
  BRC.data.create("saved_game_msg", saved_game_msg)
  crawl.sendkeys(BRC.util.letter_to_ascii("s"))
end

-- Hook functions
function f_misc_alerts.init()
  prev_available_spell_levels = you.spell_levels()
  below_hp_threshold = false
  BRC.data.create("alerted_max_piety", false)

  if CONFIG.save_with_msg then
    crawl.setopt("macros += M " .. KEYS.save_game .. " ===macro_save_with_message")
    if saved_game_msg and saved_game_msg ~= "" then
      crawl.mpr("MESSAGE: " .. saved_game_msg, message_color)
      saved_game_msg = nil
    end
  end
end

function f_misc_alerts.ready()
  if CONFIG.alert_remove_faith then alert_remove_faith() end
  if CONFIG.alert_low_hp_threshold > 0 then alert_low_hp() end
  if CONFIG.alert_spell_level_changes then alert_spell_level_changes() end
end
