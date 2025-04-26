dofile("crawl-rc/lua/pickup-alert/pa-main.lua")
dofile("crawl-rc/lua/config.lua")

loaded_pa_misc = true


--------------------------
---- Alert rare items ----
--------------------------
function alert_rare_items(it)
  local index = get_rare_item_index(it)
  if index == -1 then return end
  
  local do_alert = true
  -- Don't alert if already wearing a larger shield
  if rare_items[index] == "buckler" then
    local sh = items.equipped_at("shield")
    if sh and sh.name("base") ~= "orb" then do_alert = false end
  elseif rare_items[index] == "kite shield" then
    local sh = items.equipped_at("shield")
    if sh and sh.name("base"):find("tower shield") then do_alert = false end
  end
    
  if do_alert then
    show_alert_msg("It's your first ", rare_items[index].."!")
	crawl.more()
  end

  remove_from_rare_items(it)
end


--------------------
---- Alert orbs ----
--------------------
function alert_orb(it)
  if it.is_identified and not have_shield() then
    alert_item(it, "New orb")
  end
end


----------------------------------
---- Alert for needed resists ----
----------------------------------
function alert_staff(it)
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
    alert_item(it, "Staff resistance")
  end
end


----------------------------
---- Smart staff pickup ----
----------------------------
function pickup_staff(it)
  if it.is_useless or not it.is_identified then return false end

  local basename = it.name("base")
  local good_staff = false
  
  for k,v in pairs(staff_schools) do
    if basename == "staff of "..k then
	  good_staff = you.skill(v) > 0
	  break
	end
  end
  
  if not good_staff then return false end
  
  -- Check for previously picked staves
  for v in iter.invent_iterator:new(items_picked) do
    if v:find(basename) then return false end
  end
	
  return true
end
