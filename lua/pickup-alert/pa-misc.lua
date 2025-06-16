if loaded_pa_misc then return end
loaded_pa_misc = true
loadfile("crawl-rc/lua/emojis.lua")
loadfile("crawl-rc/lua/util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-util.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-data.lua")
loadfile("crawl-rc/lua/pickup-alert/pa-main.lua")


---- Alert rare items ----
function pa_alert_rare_item(it)
  local index = get_rare_item_index(it)
  if index == -1 then return end

  local do_alert = true
  -- Don't alert if already wearing a larger shield
  if pa_single_alert_items[index] == "buckler" then
    local sh = items.equipped_at("shield")
    if sh and sh.name("base") ~= "orb" then do_alert = false end
  elseif pa_single_alert_items[index] == "kite shield" then
    local sh = items.equipped_at("shield")
    if sh and sh.name("base"):find("tower shield") then do_alert = false end
  end

  remove_from_pa_single_alert_items(it)
  if not do_alert then return false end
  return pa_alert_item(it, "Rare item", EMOJI.RARE_ITEM)
end

---- Alert orbs ----
function pa_alert_orb(it)
  if not it.is_identified then return false end
  return pa_alert_item(it, "New orb", EMOJI.ORB)
end

---- Alert talismans ----
function pa_alert_talisman(it)
  return pa_alert_item(it, "New talisman", EMOJI.TALISMAN)
end

---- Alert for needed resists ----
function pa_alert_staff(it)
  if not it.is_identified then return false end
  local needRes = false
  local basename = it.name("base")

  if basename == "staff of fire" then needRes = CACHE.rF == 0
  elseif basename == "staff of cold" then needRes = CACHE.rC == 0
  elseif basename == "staff of air" then needRes = CACHE.rElec == 0
  elseif basename == "staff of poison" then needRes = CACHE.rPois == 0
  elseif basename == "staff of death" then needRes = CACHE.rN == 0
  end

  if not needRes then return false end
  return pa_alert_item(it, "Staff resistance", EMOJI.STAFF_RESISTANCE)
end


---- Smart staff pickup ----
function pa_pickup_staff(it)
  if it.is_useless or not it.is_identified then return false end
  local school = get_staff_school(it)
  if get_skill(school) == 0 then return false end

  -- Check for previously picked staves
  for _,v in ipairs(pa_items_picked) do
    if v:find(it.name("base")) then return false end
  end

  return true
end
