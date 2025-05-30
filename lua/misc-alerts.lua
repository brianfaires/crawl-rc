if loaded_misc_alerts then return end
loaded_misc_alerts = true
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/util.lua")

------ Max piety w/ amulet of faith reminder ----
if not alerted_max_piety or you.turns() == 0 then
  alerted_max_piety = 0
end

local function persist_alerted_max_piety()
  return "alerted_max_piety = "..alerted_max_piety..KEYS.LF
end
table.insert(chk_lua_save, persist_alerted_max_piety)


local function alert_remove_faith()
  if alerted_max_piety == 0 and you.piety_rank() == 6 then
    local am = items.equipped_at("amulet")
    if am and am.subtype() == "amulet of faith" and not am.artefact then
      if you.god() == "Uskayaw" or you.god() == "Kikubaaqudgha" then return end
      crawl.mpr("<cyan>6 star piety! Maybe ditch that amulet soon.</cyan>")
      crawl.more()
      alerted_max_piety = 1
    end
  end
end

----- Alert once at a specific HP threshold -----
local hp, mhp = you.hp()
local below_hp_threshold = hp <= CONFIG.alert_low_hp_threshold * mhp

local function alert_low_hp()
  hp, mhp = you.hp()
  if below_hp_threshold then
    below_hp_threshold = hp ~= mhp
  elseif hp <= CONFIG.alert_low_hp_threshold * mhp then
    below_hp_threshold = true
    local threshold_perc = 100 * CONFIG.alert_low_hp_threshold
    crawl.mpr("<red>!!! Dropped below "..threshold_perc.."% HP !!!</red>")
    crawl.more()
  end
end

----- Save with message -----
-- by gammafunk, edits by buehler
local function persist_save_game_msg()
  return "saved_game_msg = \""..saved_game_msg.."\""..KEYS.LF
end

function macro_save_with_message()
  crawl.formatted_mpr("Save game and exit? (y/n)", "prompt")
  local res = crawl.getch()
  if not (string.char(res) == "y" or string.char(res) == "Y") then
    crawl.formatted_mpr("Okay, then.", "prompt")
    return
  end
  crawl.formatted_mpr("Leave a message: ", "prompt")
  saved_game_msg = crawl.c_input_line()
  table.insert(chk_lua_save, persist_save_game_msg)
  crawl.sendkeys(control_key("s"))
end

if CONFIG.save_with_msg then
  crawl.setopt("macros += M S ===macro_save_with_message")
  if saved_game_msg and saved_game_msg ~= "" then
    crawl.mpr("MESSAGE: " .. saved_game_msg, message_color)
    saved_game_msg = nil
  end
end

------------------ Hook ------------------
function ready_misc_alerts()
  if CONFIG.alert_remove_faith then alert_remove_faith() end
  if CONFIG.alert_low_hp_threshold > 0 then alert_low_hp() end
end