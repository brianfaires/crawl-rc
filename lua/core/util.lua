local delayed_mpr_queue

function init_util()
  if CONFIG.debug_init then crawl.mpr("Initializing util") end

  delayed_mpr_queue = {}
end


---- Text Formatting ----
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

  local tokens = {}
  local pos = 1
  local len = #text

  while pos <= len do
      local tag_start = text:find("<", pos)
      if not tag_start then
          -- No more tags, append remaining text
          tokens[#tokens+1] = text:sub(pos)
          break
      end

      -- Append text before tag
      if tag_start > pos then
          tokens[#tokens+1] = text:sub(pos, tag_start - 1)
      end

      -- Find end of tag
      local tag_end = text:find(">", tag_start)
      if not tag_end then
          -- Malformed tag, append remaining text
          tokens[#tokens+1] = text:sub(pos)
          break
      end

      pos = tag_end + 1
  end

  -- Join all parts and remove newlines
  local cleaned = table.concat(tokens):gsub("\n", "")

  -- Handle escaping if needed
  if escape_chars then
      return cleaned:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  end

  return cleaned
end

function with_color(color, text)
  return string.format("<%s>%s</%s>", color, text, color)
end


--- Key modifiers ---
function control_key(c)
  return string.char(string.byte(c) - string.byte('a') + 1)
end


--- crawl.mpr enhancements ---
-- Sends a message that is displayed at end of turn
function enqueue_mpr(text, channel)
  delayed_mpr_queue[#delayed_mpr_queue+1] = { text = text, channel = channel, show_more = false }
end

function enqueue_mpr_opt_more(show_more, text, channel)
  delayed_mpr_queue[#delayed_mpr_queue+1] = { text = text, channel = channel, show_more = show_more }
end

function mpr_consume_queue()
  do_more = false
  for _, msg in ipairs(delayed_mpr_queue) do
    crawl.mpr(msg.text, msg.channel)
    if msg.show_more then do_more = true end
  end

  if do_more then
    you.stop_activity()
    crawl.more()
    crawl.redraw_screen()
  end

  delayed_mpr_queue = {}
end

function mpr_opt_more(show_more, text, channel)
  if show_more then
    mpr_with_more(text, channel)
  else
    crawl.mpr(text, channel)
  end
end

function mpr_with_more(text, channel)
  crawl.mpr(text, channel)
  you.stop_activity()
  crawl.more()
  crawl.redraw_screen()
end

function mpr_with_stop(text, channel)
  crawl.mpr(text, channel)
  you.stop_activity()
end


--- Utility ---
function get_mut(mutation, include_temp)
  local perm = CACHE.mutations[mutation] or 0
  if not include_temp then return perm end
  local temp = CACHE.temp_mutations[mutation] or 0
  return perm + temp
end

function have_shield()
  return items.equipped_at("shield") ~= nil
end

function have_weapon()
  return items.equipped_at("weapon") ~= nil
end

function is_amulet(it)
  return it and it.name("base") == "amulet"
end

function is_armour(it)
  return it and it.class(true) == "armour"
end

function is_body_armour(it)
  return it and it.subtype() == "body"
end

function has_dangerous_brand(it)
  local text = it.artefact and it.name() or it.ego()
  if not text then return false end
  for _, v in ipairs(DANGEROUS_BRANDS) do
    if text:find(v) then return true end
  end
  return false
end

function is_jewellery(it)
  return it and it.class(true) == "jewellery"
end

function is_ring(it)
  return it and it.name("base") == "ring"
end

function is_scarf(it)
  return it and it.class(true) == "armour" and it.subtype() == "scarf"
end

function is_shield(it)
  return it and it.class(true) == "armour" and it.subtype() == "offhand" and not is_orb(it)
end

function is_staff(it)
  return it and it.class(true) == "magical staff"
end

function is_talisman(it)
  return it and it.name("qual"):find("talisman$")
end

function is_orb(it)
  return it and it.name("qual") == "orb"
end

function is_polearm(it)
  return it and it.weap_skill == "Polearms"
end

function is_weapon(it)
  return it and (it.delay ~= nil)
end

function offhand_is_free()
  if get_mut("missing a hand") > 0 then return true end
  return not items.equipped_at("offhand")
end

function you_have_allies()
  return you.skill("Summonings") + you.skill("Necromancy") > 0 or
      util.contains(GODS_WITH_ALLIES, CACHE.god)
end


--- Debugging ---
function describe_inv_slot(inv_num, full_dump)
  local inv = items.inslot(inv_num)
  tokens = {}
  tokens[#tokens+1] = string.format("  %s: (%s) Qual: %s | Base: %s", inv.slot, inv.quantity, inv.name("qual"), inv.name("base"))
  if full_dump then
    tokens[#tokens+1] = string.format("    Class: %s, Subtype: %s", inv.class(true), inv.subtype())
  end
  local msg = table.concat(tokens, "\n")  
  crawl.mpr(msg)
  return msg
end

function dump_inventory(verbose)
  local tokens = { "\n---INVENTORY---"}
  for inv in iter.invent_iterator:new(items.inventory()) do
    tokens[#tokens+1] = describe_inv_slot(inv.slot, verbose)
  end
  local msg = table.concat(tokens, "\n")
  crawl.mpr(msg)
  return msg
end

function debug_dump(verbose, skip_char_dump)
  local msg = ""
  if dump_persistent_data then msg = msg .. dump_persistent_data() end
  if dump_cache then msg = msg .. dump_cache() end
  msg = msg .. dump_inventory(verbose)
  crawl.mpr(msg)
  if not skip_char_dump then
    crawl.take_note(msg)
    crawl.dump_char()
  end
end
