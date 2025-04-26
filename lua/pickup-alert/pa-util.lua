--dofile("crawl-rc/lua/config.lua")

------------------------------------
--------------- Misc ---------------
------------------------------------
function show_alert_msg(alert_text, item_name)
  crawl.mpr("<cyan>----<magenta>"..alert_text.."<yellow>"..item_name.."</yellow></magenta>----</cyan>")
  you.stop_activity()
end

local allied_gods = { "Beogh", "Hepliaklqana", "Jiyva", "Yredelemnul" }
function you_have_allies()
  return you.skill("Summonings") + you.skill("Necromancy") > 0 or util.contains(allied_gods, you.god())
end


------------------------------
--- Code readability funcs ---
------------------------------
function if_el(cond, a, b)
  if cond then
    return a
  else
    return b
  end
end

function is_body_armour(it)
  return it and it.subtype() == "body"
end

function is_armour(it)
  return it and it.class(true) == "armour"
end

function is_shield(it)
  return it and it.subtype() == "shield"
end

function is_weapon(it)
  return it and (it.delay ~= nil)
end

function is_staff(it)
  return it and it.class(true) == "magical staff"
end

function is_ring(it)
  return it and it.name("base") == "ring"
end

function is_amulet(it)
  return it and it.name("base") == "amulet"
end

function is_orb(it)
  return it and it.name("base") == "orb"
end

function get_mut(mutation, include_temp)
  return you.get_base_mutation_level(mutation, include_temp)
end

function have_shield()
  return items.equipped_at("shield") ~= nil
end

---------------------------------
--- Custom def of ego/branded ---
---------------------------------
function has_ego(it)
  if it.class(true) == "weapon" then return it.branded or it.artefact end
  if it.artefact or it.branded then return true end
  local basename = it.name("base")
  if basename:find("troll leather") then return true end
  if basename:find("dragon scales") and not basename:find("steam") then return true end
  return false
end

function get_ego(it)
  if it.artefact then return "arte" end
  local basename = it.name("base")
  if basename:find("troll leather") then return "Regen+" end
  if basename:find("dragon scales") and not basename:find("steam") then return basename end
  return it.ego()
end


-------------------------------------------------
--------- Armour (Mimicing crawl calcs) ---------
-------------------------------------------------
function get_race_size()
  local race = you.race()
  if race == "Spriggan" then return -2
  elseif race == "Kobold" then return -1
  elseif race == "Formicid" or race == "Armataur" or race == "Naga" then return 1
  elseif race == "Ogre" or race == "Troll" then return 2
  else return 0
  end
end

function get_shield_penalty(sh)
  local pen = 2/5 * sh.encumbrance * sh.encumbrance / (20 + 6 * get_race_size()) * (27 - you.skill("Shields")) / 27
  -- Round to 2 decimals, which mimics scale==100
  return math.floor(100 * pen) / 100
end

function get_armour_ac(it)
  local it_plus = if_el(it.plus, it.plus, 0)
  
  if it.artefact and it.is_identified then
    local art_ac = it.artprops["AC"]
    if art_ac then it_plus = it_plus + art_ac end
  end

  if it.artefact and it.is_identified then
    local art_ac = it.artprops["AC"]
    if art_ac then it_plus = it_plus + art_ac end
  end
  
  local deformed = get_mut("deformed body", true) > 0
  local pseudopods = get_mut("pseudopods", true) > 0
  
  local ac = it.ac * (you.skill("Armour") / 22 + 1) + it_plus
  if pseudopods or (deformed and is_body_armour(it)) then
    ac = ac - it.ac / 2

  end

  return math.max(0, ac - 0.05)
end

local function get_aevp(encumb, str)
  return 2 * encumb * encumb * (45 - you.skill("Armour")) / (5 * (str + 3) * 45)
end

function get_armour_ev(it)
  -- This function computes the armour-based component to standard EV (not paralysed, etc)
  -- Factors in stat changes from this armour and removing current one
  local str = you.strength()
  local dex = you.dexterity()
  local art_ev = 0
  
  
  -- Adjust str/dex/EV for artefact stat changes
  local worn = items.equipped_at("Armour")
  if worn and worn.artefact then
    if worn.artprops["Str"] then str = str - worn.artprops["Str"] end
    if worn.artprops["Dex"] then dex = dex - worn.artprops["Dex"] end
    if worn.artprops["EV"] then art_ev = art_ev - worn.artprops["EV"] end
  end
  
  local no_art_dex = dex
  
  if it.artefact then
    if it.artprops["Str"] then str = str + it.artprops["Str"] end
    if it.artprops["Dex"] then dex = dex + it.artprops["Dex"] end
    if it.artprops["EV"] then art_ev = art_ev + it.artprops["EV"] end
  end
  
  if str <= 0 then str = 1 end
  
  local size_factor = -2 * get_race_size()
  
  
  local dodge_bonus = 8*(10 + you.skill("Dodging") * dex) / (20 - size_factor) / 10
  local normalize_zero_to_zero = 8*(10 + you.skill("Dodging") * no_art_dex) / (20 - size_factor) / 10

  local encumb = it.encumbrance - 2* get_mut("sturdy frame", true)
  if encumb < 0 then encumb = 0 end
  
  armor_penalty = encumb - 3
  -- todo: sturdy frame mutation
  
  if armor_penalty > 0 then
    if armor_penalty >= str then dodge_bonus = dodge_bonus * (str / (armor_penalty * 2))
    else dodge_bonus = dodge_bonus * (1 - armor_penalty / (str * 2))
    end
  end

  local aevp = get_aevp(encumb, str)

  return dodge_bonus - aevp + art_ev - normalize_zero_to_zero
end


function get_shield_sh(it)
  local dex = you.dexterity()
  if it.artefact and it.is_identified then
    local art_dex = it.artprops["Dex"]
    if art_dex then dex = dex + art_dex end
  end
  
  local cur = items.equipped_at("shield")
  if cur and cur.artefact and cur.slot ~= it.slot then
    local art_dex = cur.artprops["Dex"]
    if art_dex then dex = dex - art_dex end
  end

  local it_plus = if_el(it.plus, it.plus, 0)
  
  local skill = you.skill("Shields")
  local basename = it.name("base")
  local sh_size
  if basename:find("tower shield") then sh_size = 0
  elseif basename:find("kite shield") then sh_size = -1
  else sh_size = -2
  end
  
  local base_sh = it.ac * 2 + sh_size*get_race_size()
  local shield = base_sh * (50 + skill*5/2)
  shield = shield + 200*it_plus
  
  if skill < 3 then shield = shield + 76*skill
  else shield = shield + 38*(3+skill)
  end
  
  shield = shield + dex*38*(base_sh+13)/26
  return (shield + 50) / 200
end


--------------------------------------------------
--------- Weapons (Mimicing crawl calcs) ---------
--------------------------------------------------
function get_hands(it)
  if you.race() ~= "Formicid" then return it.hands end
  st, _ = it.subtype()
  if st == "giant club" or st == "giant spiked club" then return 2 end
  return 1
end

function get_weap_min_delay(it)
  -- This is an abbreviated version of the actual calculation.
  -- Intended only to be used to prevent skill from reducing too far in get_weap_delay()
  local basename = it.name("base")
  
  adj_base_delay = it.delay / 2
  if it.ego() == "heavy" then adj_base_delay = 1.5 * adj_base_delay end
  local min_delay = math.floor(adj_base_delay)
  
  if it.weap_skill == "Short Blades" and min_delay > 5 then min_delay = 5 end
  if min_delay > 7 then min_delay = 7 end
  
  if basename:find("longbow") then min_delay = 6
  elseif (basename:find("crossbow") or basename:find("arbalest")) and min_delay < 10 then min_delay = 10 end
  
  return min_delay
end

function get_weap_delay(it)
  local delay = it.delay - you.skill(it.weap_skill)/2
  local min_delay = get_weap_min_delay(it)
  if delay < min_delay then delay = min_delay end
  
  if it.ego() == "speed" then delay = delay * 2 / 3
  elseif it.ego() == "heavy" then delay = delay * 1.5
  end
  
  if delay < 3 then delay = 3 end
  
  local sh = items.equipped_at("shield")
  if sh then delay = delay + get_shield_penalty(sh) end
  
  if it.is_ranged then
    local body = items.equipped_at("Armour")
    if body then
      local str = you.strength()
      if it.artefact then
        if it.artprops["Str"] then str = str + it.artprops["Str"] end
      end
      local cur = items.equipped_at("weapon")
      if cur and cur ~= it and cur.artefact then
        if cur.artprops["Str"] then str = str - cur.artprops["Str"] end
      end
      
      delay = delay + get_aevp(body.encumbrance, str)
    end
  end
  
  return delay / 10
end


--------------------------------------
--------- Other damage calcs ---------
--------------------------------------
-- Count all slay bonuses from weapons/armour/jewellery
function get_slay_bonuses()
  local sum = 0

  -- Slots can go as high as 18 afaik
  for i = 0,20 do
    it = items.equipped_at(i)
    if it then
      if is_ring(it) then
        if it.artefact then
          local name = it.name()
          local idx = name:find("Slay+")
          if idx then
            local slay = tonumber(name:sub(idx+5, idx+5))
            if slay == 1 then
              local next_digit = tonumber(name:sub(idx+6, idx+6))
              if next_digit then slay = 10 + next_digit end
            end
            sum = sum + slay
          end
        elseif it.ego(true) == "Slay" then 
          sum = sum + it.plus 
        end
      elseif it.artefact and (is_armour(it) or is_amulet(it)) then
          local slay = it.artprops["Slay"]
          if slay then sum = sum + slay end
      end
    end
  end
  
  if you.race() == "Demonspawn" then
    sum = sum + 3 * get_mut("augmentation", true)
    sum = sum + get_mut("sharp scales", true)
  end

  return sum
end


-- Calc extra damage for magical staves
function get_staff_bonus_dmg(it, no_brand_dmg)
  if no_brand_dmg and basename ~= "staff of earth" and basename ~= "staff of conjuration" then return 0 end
  
  local evo_skill = you.skill("Evocations")
  local basename = it.name("base")
  local school = nil
  
  for k,v in pairs(staff_schools) do
    if basename == "staff of "..k then
	  school = v
	  break
	end
  end
  if not school then return 0 end
  
  local spell_skill = you.skill(school)
  local chance = (evo_skill + spell_skill/2) / 15
  if chance > 1 then chance = 1 end
  -- 0.625 is an acceptable approximation
  -- Earth magic does more, but reduced by armour. Poison/draining bonus effects are ignored.
  local avg_dmg = 0.625 * (evo_skill/2 + spell_skill)
  return avg_dmg*chance
end


----------------------------------
--------- get_weap_dps() ---------
----------------------------------
function get_weap_dmg(it, no_brand_dmg)
  -- Returns an adjusted weapon damage = damage * speed
  -- Includes stat/slay changes between weapon and the one currently wielded
  -- Aux attacks not included
  local it_plus = if_el(it.plus, it.plus, 0)

  -- Adjust str/dex/slay from artefacts
  local str = you.strength()
  local dex = you.dexterity()
  
  -- Adjust str/dex/EV for artefact stat changes
  if not it.equipped then
    local wielded = items.equipped_at("weapon")
    if wielded and wielded.artefact then
      if wielded.artprops["Str"] then str = str - wielded.artprops["Str"] end
      if wielded.artprops["Dex"] then dex = dex - wielded.artprops["Dex"] end
      if wielded.artprops["Slay"] then it_plus = it_plus - wielded.artprops["Slay"] end
    end
    
    if it.artefact and it.is_identified then
      if it.artprops["Str"] then str = str + it.artprops["Str"] end
      if it.artprops["Dex"] then dex = dex + it.artprops["Dex"] end
      if it.artprops["Slay"] then it_plus = it_plus + it.artprops["Slay"] end
    end
  end
  
  if it.is_ranged or it.weap_skill:find("Blades") then stat = dex
  else stat = str end

  local stat_mod = 0.75 + 0.025 * stat
  local skill_mod = (1 + you.skill(it.weap_skill)/25/2) * (1 + you.skill("Fighting")/30/2)
  
  local pre_brand_dmg = it.damage * stat_mod * skill_mod + it_plus + get_slay_bonuses()
  

  if is_staff(it) then 
    return (pre_brand_dmg + get_staff_bonus_dmg(it, no_brand_dmg))
  end
  
  local ego = it.ego()
  if not ego then return pre_brand_dmg end

  if ego == "spectralizing" then return 2 * pre_brand_dmg
  elseif ego == "heavy" then return 1.8 * pre_brand_dmg
  end
  
  if not no_brand_dmg then
    if ego == "flaming" or ego == "freezing" then return 1.25 * pre_brand_dmg  end
    if ego == "draining" then return (1.25 * pre_brand_dmg + 2) end 
    if ego == "electrocution" then return (pre_brand_dmg + 3.5) end
    -- Ballparking venom as 5 dmg since it totally breaks the paradigm
    if ego == "venom" then return (pre_brand_dmg + 5) end
    if ego == "pain" then return (pre_brand_dmg + you.skill("Necromancy")/2) end
    -- Distortion does 5.025 extra dmg, + 5% chance to banish
    if ego == "distortion" then return (pre_brand_dmg + 6) end
    -- Weighted average of all the easily computed brands was ~ 1.17*dmg + 2.13
    if ego == "chaos" then return (1.25 * pre_brand_dmg + 2) end
  end
  
  return pre_brand_dmg
end

----------------------------------
--------- get_weap_dps() ---------
----------------------------------
function get_weap_dps(it, no_brand_dmg)
  return get_weap_dmg(it, no_brand_dmg) / get_weap_delay(it)
end

-----------------------------
---- Weapon info strings ----
-----------------------------
function get_weapon_info(it)
  if not it.delay then return end
  
  local dmg = get_weap_dmg(it)
  local dmg_str = string.format("%.1f", dmg)
  if dmg < 10 then dmg_str = string.format("%.2f", dmg) end
  if dmg > 99.9 then dmg_str = ">100" end

  local delay = get_weap_delay(it)
  local delay_str = string.format("%.1f", delay)
  if delay < 1 then
    delay_str = string.format("%.2f", delay)
    delay_str = delay_str:sub(2, #delay_str)
  end

  local dps = get_weap_dps(it)
  local dps_str = string.format("%.1f", dps)
  if dps < 10 then dps_str = string.format("%.2f", dps) end
  if dps > 99.9 then dps_str = ">100" end
      
  local it_plus = if_el(it.plus, it.plus, 0)
  local acc = it.accuracy + it_plus
  if acc >= 0 then acc = "+"..acc end
  
  dps_str = "DPS="..dps_str.." "
  return dps_str.."("..dmg_str.."/"..delay_str.."), Acc"..acc
end


function get_armour_info(it)
  if not is_armour(it) then return end
  
  if is_shield(it) then
    local ev = get_shield_penalty(it)
    local ev_str = string.format("%.1f", ev)
    ev_str = "-"..ev_str
  
    local sh = get_shield_sh(it)
    local sh_str = string.format("%.1f", sh)
    if sh >= 0 then sh_str = "+"..sh_str end
    sh_str = "SH"..sh_str..","
    if sh < 10 then sh_str = sh_str.." " end

    return sh_str.."EV"..ev_str
  else
    local cur = items.equipped_at(it.equip_type)
    local cur_ac = 0
    local cur_ev = 0
    if cur then 
      cur_ac = get_armour_ac(cur)
      cur_ev = get_armour_ev(cur)
    end

    local ac_delta = get_armour_ac(it) - cur_ac
    local ac_str = string.format("%.1f", ac_delta)
    if ac_delta >= 0 then ac_str = "+"..ac_str end
    if not is_body_armour(it) then return "AC"..ac_str end
    
    ac_str = "AC"..ac_str..","
    if ac_delta < 10 then ac_str = ac_str.." " end


    local ev_delta = get_armour_ev(it) - cur_ev
    local ev_str = string.format("%.1f", ev_delta)
    if ev_delta >= 0 then ev_str = "+"..ev_str end
    return ac_str.."EV"..ev_str
  end  
end
