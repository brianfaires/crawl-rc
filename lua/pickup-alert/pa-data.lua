if loaded_pa_data then return end
loaded_pa_data = true
dofile("crawl-rc/lua/util.lua")

-------------------------------------------------------------------------------
---------------------------- Begin persistant data ----------------------------
-------------------------------------------------------------------------------
if not added_persistant_data or you.turns() == 0 then
  added_persistant_data = 1

  level_alerts = { }
  items_picked = { }
  items_alerted = { }
  rare_items = {  "broad axe", "executioner's axe", "eveningstar", "demon whip", "sacred scourge",
                  "lajatang", "bardiche", "demon trident", "trishula",
                  "quick blade", "demon blade", "double sword", "triple sword", "eudemon blade",
                  "crystal plate armour", "gold dragon scales", "pearl dragon scales",
                  "storm dragon scales", "shadow dragon scales", "wand of digging",
                  "triple crossbow", "hand crossbow", "buckler", "kite shield", "tower shield" }

  armour_high_score = 0
  alerted_first_ranged_one_handed = 0
  alerted_first_ranged_two_handed = 0
  polearm_high_score = 0
  polearm_onehand_high_score = 0
  unbranded_high_score = 0
  weapon_high_score = 0
end


local function persist_table(table_name, table)
  local cmd_init = table_name.." = {"
  local cmd = cmd_init
  for v in iter.invent_iterator:new(table) do
    if cmd ~= cmd_init then cmd = cmd..", " end
    cmd = cmd.."\""..v.."\""
  end
  
  return cmd .. "}" .. string.char(10)
end

local function persist_var(var_name, var)
  return var_name .. " = " .. var .. string.char(10)
end


if not added_persistant_data_hooks then
  added_persistant_data_hooks = true
  
  table.insert(chk_lua_save, function() return persist_table("level_alerts", level_alerts) end)
  table.insert(chk_lua_save, function() return persist_table("rare_items", rare_items) end)
  table.insert(chk_lua_save, function() return persist_table("items_picked", items_picked) end)
  table.insert(chk_lua_save, function() return persist_table("items_alerted", items_alerted) end)
  table.insert(chk_lua_save, function() return persist_var("armour_high_score", armour_high_score) end)
  table.insert(chk_lua_save, function() return persist_var("alerted_first_ranged_one_handed", alerted_first_ranged_one_handed) end)
  table.insert(chk_lua_save, function() return persist_var("alerted_first_ranged_two_handed", alerted_first_ranged_two_handed) end)
  table.insert(chk_lua_save, function() return persist_var("polearm_high_score", polearm_high_score) end)
  table.insert(chk_lua_save, function() return persist_var("polearm_onehand_high_score", polearm_onehand_high_score) end)
  table.insert(chk_lua_save, function() return persist_var("unbranded_high_score", unbranded_high_score) end)
  table.insert(chk_lua_save, function() return persist_var("weapon_high_score", weapon_high_score) end)
  table.insert(chk_lua_save, function() return persist_var("added_persistant_data", 1) end)
end


----------------------------------------
---- Accessors into persistant data ----
----------------------------------------
function get_rare_item_index(it)
  local qualname = it.name("qual")
  for i,v in ipairs(rare_items) do
    if v ~= "" and qualname:find(v) then return i end
  end
  return -1
end

function remove_from_rare_items(it)
  local idx = get_rare_item_index(it)
  if idx ~= -1 then
    util.remove(rare_items, rare_items[idx])
    return true
  end
  
  return false
end

function previously_picked(it)
  local name = it.name("plain")
  if not it.is_identified then name = "+0 " .. name end
  return util.contains(items_picked, name)
end

function previously_alerted(it)
  local name = it.name("plain")
  if not it.is_identified then name = "+0 " .. name end
  return util.contains(items_alerted, name)
end


-------------------------------
--- Multi store/remove data ---
-------------------------------
local function add_remove_item_and_less_enchanted(table_ref, it, remove_item)
  -- Add (or remove) an item name to a table, along with all less enchanted versions
  -- e.g. "+3 flail" will add: "+3 flail", "+2 flail", "+1 flail", "+0 flail"
  local name = it.name("plain")
  if not it.is_identified then name = "+0 " .. name end
  if util.contains(table_ref, name) ~= remove_item then return end
  
  if remove_item then util.remove(table_ref, name)
  else table.insert(table_ref, name)
  end

  if it.artefact then return end
  
  -- Do less enchanted items too
  local plus = tonumber(name:sub(2,2))
  if not plus then return end
    
  if plus > 0 then
    if tonumber(name:sub(3,3)) then
      plus = 10 * plus + tonumber(name:sub(3,3))
    end

    for i=plus,1,-1 do
      name = name:gsub("+"..i, "+"..(i-1))
      if remove_item then util.remove(table_ref, name)
      else table.insert(table_ref, name)
      end
    end
  end
end

function insert_item_and_less_enchanted(table_ref, it)
  add_remove_item_and_less_enchanted(table_ref, it, false)
end

function remove_item_and_less_enchanted(table_ref, it)
  add_remove_item_and_less_enchanted(table_ref, it, true)
end


----------------------------------
--- Set all single high scores ---
----------------------------------
function update_high_scores(it)
  local ret_val = nil
  
  if is_armour(it) then
    local ac = get_armour_ac(it)
    if ac > armour_high_score then
      armour_high_score = ac
      if not ret_val then ret_val = "Strongest armour" end
    end
  elseif is_weapon(it) then
    local it_plus = if_el(it.plus, it.plus, 0)
    local score = get_weap_dps(it) + (it.accuracy + it_plus) / 2
    if score > weapon_high_score then
      weapon_high_score = score
      if not ret_val then ret_val = "Good weapon" end
    end
    
    local unbranded_score = get_weap_dps(it, false) + (it.accuracy + it_plus) / 2
    if unbranded_score > unbranded_high_score then
      unbranded_high_score = score
      if not ret_val then ret_val = "High pure damage" end
    end
    
    if it.weap_skill == "Polearms" and you_have_allies() then
      if score > polearm_high_score then
        polearm_high_score = score
        if not have_shield() and not ret_val then ret_val = "Good polearm" end
      end

      if get_hands(it) == 1 and score > polearm_onehand_high_score then
        polearm_onehand_high_score = score
        if not ret_val then ret_val = "Good polearm" end
      end
    end
  end

  return ret_val
end


--------------------
--- Startup code ---
--------------------
-- Starting items: Remove from rare_items, and add to items_picked
if you.turns() == 0 then  
  for inv in iter.invent_iterator:new(items.inventory()) do
    local idx = get_rare_item_index(inv)
    if idx ~= -1 then util.remove(rare_items, rare_items[idx]) end
	insert_item_and_less_enchanted(items_picked, inv)
  end
end
