if loaded_util_lua then return end
local loaded_util_lua = true
loadfile("crawl-rc/lua/constants.lua")

---- Text Formatting ----
function colorize_itext(color, str)
  return string.format("<%s>%s</%s>", color, str, color)
end

-- Removes tags from text, and optionally escapes special characters --
function cleanup_text(text, escape_chars)
  local keep_going = true
  while keep_going do
    local opening = text:find("<")
    local closing = text:find(">")

    if opening and closing and opening < closing then
      local new_text = ""
      if opening > 1 then new_text = text:sub(1, opening-1) end
      if closing < #text then new_text = new_text..text:sub(closing+1, #text) end
      text = new_text
    else
      keep_going = false
    end
  end

  text = text:gsub("\n", "")
  if escape_chars then
    local special_characters = "([%^%$%(%)%%%.%[%]%*%+%-%?])"
    text = text:gsub(special_characters, "%%%1")
  end

  return text
end

--- Modify keypress ---
function control_key(c)
  return string.char(string.byte(c) - string.byte('a') + 1)
end

--- Code readability ---
function if_el(cond, a, b)
  if cond then
    return a
  else
    return b
  end
end

--- Helper ---
function you_have_allies()
  return you.skill("Summonings") + you.skill("Necromancy") > 0 or
      util.contains(gods_with_allies, you.god())
end

function you_are_undead()
  return util.contains(all_undead_races, you.race())
end

function you_are_pois_immune()
  return you.res_poison() >= 3
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
  return it and it.name("base"):find("orb of ")
end

function is_talisman(it)
  return it and it.name("base"):find("talisman")
end

function get_mut(mutation, include_temp)
  return you.get_base_mutation_level(mutation, include_temp)
end

function have_shield()
  return items.equipped_at("shield") ~= nil
end

function get_body_armour()
  return items.equipped_at("armour")
end