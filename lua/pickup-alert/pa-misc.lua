function pa_alert_orb(it)
  if not it.is_identified then return false end
  return pa_alert_item(it, "New orb", EMOJI.ORB)
end

function pa_alert_OTA(it)
  local index = get_OTA_index(it)
  if index == -1 then return end

  local do_alert = true
  -- Don't alert if already wearing a larger shield
  if pa_OTA_items[index] == "buckler" then
    if have_shield() then do_alert = false end
  elseif pa_OTA_items[index] == "kite shield" then
    local sh = items.equipped_at("offhand")
    if sh and sh.name("qual") == "tower shield" then do_alert = false end
  end

  remove_from_OTA(it)
  if not do_alert then return false end
  return pa_alert_item(it, "Rare item:", EMOJI.RARE_ITEM)
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

function pa_alert_talisman(it)
  if it.artefact then
    if it.is_identified then
      crawl.mpr("ALERT 13")
      return pa_alert_item(it, "Artefact talisman", EMOJI.TALISMAN)
    end
    return false
  end
  return pa_alert_item(it, "New talisman", EMOJI.TALISMAN)
end

---- Smart staff pickup ----
function pa_pickup_staff(it)
  if not it.is_identified then return false end
  local school = get_staff_school(it)
  if get_skill(school) == 0 then return false end

  -- Check for previously picked staves
  for _,v in ipairs(pa_items_picked) do
    if v:find(it.name("base")) then return false end
  end

  return true
end

---- Exclude superfluous rings ----
function is_unneeded_ring(it)
  if not is_ring(it) or it.artefact or you.race() == "Octopode" then return false end
  local missing_hand = get_mut(MUTS.missing_hand, true)
  local st = it.subtype()
  local found_first = false
  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_ring(inv) and inv.subtype() == st then
      if found_first or missing_hand then return true end
      found_first = true
    end
  end
  return false
end
