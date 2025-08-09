-- Cache of commonly pulled values, for better performance
CACHE = {}

function dump_cache(char_dump)
  dump_text(serialize_cache(), char_dump)
end

function init_cache()
  if CONFIG.debug_init then crawl.mpr("Initializing cache") end

  CACHE = {}

  if util.contains(ALL_LITTLE_RACES, you.race()) then CACHE.size_penalty = SIZE_PENALTY.LITTLE
  elseif util.contains(ALL_SMALL_RACES, you.race()) then CACHE.size_penalty = SIZE_PENALTY.SMALL
  elseif util.contains(ALL_LARGE_RACES, you.race()) then CACHE.size_penalty = SIZE_PENALTY.LARGE
  else CACHE.size_penalty = SIZE_PENALTY.NORMAL
  end
 
  ready_cache()
end

function serialize_cache()
  local tokens = { "\n---CACHE---" }
  for k,v in pairs(CACHE) do
    if type(v) == "table" then
      tokens[#tokens+1] = string.format("%s:", k)
      for k2,v2 in pairs(v) do
        tokens[#tokens+1] = string.format("  %s: %s", k2, v2)
      end
    else
      if v == true then v = "true" elseif v == false then v = "false" end
      tokens[#tokens+1] = string.format("%s: %s", k, v)
    end
  end

  tokens[#tokens+1] = ""
  return table.concat(tokens, "\n")
end

------------------- Hooks -------------------
function ready_cache()
  CACHE.top_weap_skill = "Unarmed Combat"
  local max_weap_skill = get_skill(CACHE.top_weap_skill)
  for _,v in ipairs(ALL_WEAP_SCHOOLS) do
    if get_skill(v) > max_weap_skill then
      max_weap_skill = get_skill(v)
      CACHE.top_weap_skill = v
    end
  end
end
