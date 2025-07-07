local REMOVE_FAITH_MSG = "6 star piety! Maybe ditch that amulet soon."
local below_hp_threshold

local function alert_low_hp()
  if below_hp_threshold then
    below_hp_threshold = CACHE.hp ~= CACHE.mhp
  elseif CACHE.hp <= CONFIG.alert_low_hp_threshold * CACHE.mhp then
    below_hp_threshold = true
    local low_hp_msg = "Dropped below " .. (100*CONFIG.alert_low_hp_threshold) .. "% HP"
    enqueue_mpr_opt_more(true, table.concat({
      EMOJI.EXCLAMATION_2, " ", with_color(COLORS.red, low_hp_msg), " ", EMOJI.EXCLAMATION_2
    }))
  end
end

local function alert_remove_faith()
  if alerted_max_piety == 0 and you.piety_rank() == 6 then
    local am = items.equipped_at("amulet")
    if am and am.subtype() == "amulet of faith" and not am.artefact then
      if CACHE.god == "Uskayaw" or CACHE.god == "Kikubaaqudgha" then return end
      mpr_with_more(with_color(COLORS.cyan, REMOVE_FAITH_MSG))
      alerted_max_piety = 1
    end
  end
end


function init_misc_alerts()
  if CONFIG.debug_init then crawl.mpr("Initializing misc-alerts") end

  below_hp_threshold = false
  create_persistent_data("alerted_max_piety", 0)

  if CONFIG.save_with_msg then
    crawl.setopt("macros += M S ===macro_save_with_message")
    if saved_game_msg and saved_game_msg ~= "" then
      crawl.mpr("MESSAGE: " .. saved_game_msg, message_color)
      saved_game_msg = nil
    end
  end
end


----- Save with message -----
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
  create_persistent_data("saved_game_msg", saved_game_msg)
  crawl.sendkeys(control_key("s"))
end

------------------ Hooks ------------------
function ready_misc_alerts()
  if CONFIG.alert_remove_faith then alert_remove_faith() end
  if CONFIG.alert_low_hp_threshold > 0 then alert_low_hp() end
end
