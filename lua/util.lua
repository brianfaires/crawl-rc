if loaded_util_lua then return end
local loaded_util_lua = true
loadfile("crawl-rc/lua/constants.lua")

---- Text Formatting ----
function colorize_itext(color, str)
  return string.format("<%s>%s</%s>", color, str, color)
end

-- Removes tags from text, and optionally escapes special characters --
function cleanup_text(text, escape_chars)
  local SPECIAL_CHARS = "([%^%$%(%)%%%.%[%]%*%+%-%?])"
  -- Fast path: if no tags, just handle newlines and escaping
  if not text:find("<") then
      if not escape_chars then
          return text:gsub("\n", "")
      end
      return text:gsub("\n", ""):gsub(SPECIAL_CHARS, "%%%1")
  end
  
  -- Use a table to build the result instead of string concatenation
  local result = {}
  local pos = 1
  local len = #text
  
  while pos <= len do
      local tag_start = text:find("<", pos)
      if not tag_start then
          -- No more tags, append remaining text
          result[#result + 1] = text:sub(pos)
          break
      end
      
      -- Append text before tag
      if tag_start > pos then
          result[#result + 1] = text:sub(pos, tag_start - 1)
      end
      
      -- Find end of tag
      local tag_end = text:find(">", tag_start)
      if not tag_end then
          -- Malformed tag, append remaining text
          result[#result + 1] = text:sub(pos)
          break
      end
      
      pos = tag_end + 1
  end
  
  -- Join all parts and handle newlines
  local cleaned = table.concat(result):gsub("\n", "")
  
  -- Handle escaping if needed
  if escape_chars then
      return cleaned:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  end
  
  return cleaned
end

--- Key codes & modifiers ---
KEYS = { LF = string.char(10), CR = string.char(13) }
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
