if loaded_misc_alerts then return end
loaded_misc_alerts = true
print("Loaded misc-alerts.lua")
------------------------------------------
------ Max piety w/ amulet of faith ------
------------------------------------------
if not alerted_max_piety then
  local alerted_max_piety = 0
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

-------------------------------------------------
----- Alert once at a specific HP threshold -----
-------------------------------------------------
-- Throw a force_more() at ~50% hp; don't throw again until fully healed
local HP_THRESHOLD = 0.5
local hp, mhp = you.hp()
local below_hp_threshold = hp <= HP_THRESHOLD * mhp

local function alert_low_hp()
  hp, mhp = you.hp()
  if below_hp_threshold then
    below_hp_threshold = hp ~= mhp
  elseif hp <= HP_THRESHOLD * mhp then
    below_hp_threshold = true
    local threshold_perc = 100 * HP_THRESHOLD
    crawl.mpr("<red>!!! Dropped below "..threshold_perc.."% HP !!!</red>")
    crawl.more()
  end
end

------------------------------------------
------------------ Hook ------------------
------------------------------------------
function ready_misc_alerts()
  alert_remove_faith()
  alert_low_hp()
end
