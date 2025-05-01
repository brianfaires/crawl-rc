if loaded_misc_alerts then return end
loaded_misc_alerts = true
loadfile("crawl-rc/lua/config.lua")

------ Max piety w/ amulet of faith reminder ----
if not alerted_max_piety or you.turns() == 0 then
  alerted_max_piety = 0
end

local function persist_alerted_max_piety()
  return "alerted_max_piety = "..alerted_max_piety..string.char(10)
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

----- Annotate Vaults:5 (by rypofalem) -----
local annotated_v5 = false
function ready_annotate_v5()
  if (not annotated_v5) and (you.branch() == "Vaults") then
    crawl.sendkeys("!v5" .. string.char(13) .. "<red>!V:5 Warning!</red>" .. string.char(13))
    annotated_v5 = true
  end
end

----- Save with message -----
-- credit: gammafunk
if CONFIG.save_with_msg then
  crawl.setopt("macros += M S ===macro_save_with_message")

  if c_persist.message and c_persist.message ~= "" then
    crawl.mpr("MESSAGE: " .. c_persist.message, message_color)
    c_persist.message = nil
  end
end

function macro_save_with_message()
  if you.turns() == 0 then
    crawl.sendkeys("S")
    return
  end
  crawl.formatted_mpr("Save game and exit?", "prompt")
  local res = crawl.getch()
  if not (string.char(res) == "y" or string.char(res) == "Y") then
    crawl.formatted_mpr("Okay, then.", "prompt")
    return
  end
  crawl.formatted_mpr("Leave a message: ", "prompt")
  res = crawl.c_input_line()
  c_persist.message = res
  crawl.sendkeys(control_key("s"))
end

------------------ Hook ------------------
function ready_misc_alerts()
  if CONFIG.alert_remove_faith then alert_remove_faith() end
  if CONFIG.alert_low_hp_threshold > 0 then alert_low_hp() end
  if CONFIG.annotate_v5 then ready_annotate_v5() end
end