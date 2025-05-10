if loaded_pa_misc then return end
loaded_pa_misc = true
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

  if do_alert then
    pa_show_alert_msg("It's your first ", pa_single_alert_items[index].."!")
    crawl.more()
  end

  remove_from_pa_single_alert_items(it)
end

---- Alert orbs ----
function pa_alert_orb(it)
  if it.is_identified and not have_shield() then
    pa_alert_item(it, "New orb")
  end
end

---- Alert talismans ----
function pa_alert_talisman(it)
  if it.is_identified then
    pa_alert_item(it, "New talisman")
  end
end

---- Alert for needed resists ----
function pa_alert_staff(it)
  if not it.is_identified then return false end
  local needRes = false
  local basename = it.name("base")

  if basename == "staff of fire" then needRes = you.res_fire() == 0
  elseif basename == "staff of cold" then needRes = you.res_cold() == 0
  elseif basename == "staff of air" then needRes = you.res_shock() == 0
  elseif basename == "staff of poison" then needRes = you.res_poison() == 0
  elseif basename == "staff of death" then needRes = you.res_draining() == 0
  end

  if needRes then
    pa_alert_item(it, "Staff resistance")
  end
end


---- Smart staff pickup ----
function pa_pickup_staff(it)
  if it.is_useless or not it.is_identified then return false end
  local school = get_staff_school(it)
  if get_skill(school) == 0 then return false end

  -- Check for previously picked staves
  for v in iter.invent_iterator:new(pa_items_picked) do
    if v:find(it.name("base")) then return false end
  end

  return true
end
