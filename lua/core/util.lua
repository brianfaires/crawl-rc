local delayed_mpr_queue

function init_util()
  if CONFIG.debug_init then crawl.mpr("Initializing util") end

  delayed_mpr_queue = {}
end


---- Text Formatting ----
-- Removes tags from text, and optionally escapes special characters --
local CLEANUP_TEXT_CHARS = "([%^%$%(%)%%%.%[%]%*%+%-%?])"
function cleanup_text(text, escape_chars)
  -- Fast path: if no tags, just handle newlines and escaping
  if not text:find("<", 1, true) then
    local one_line = text:gsub("\n", "")
    if escape_chars then return one_line:gsub(CLEANUP_TEXT_CHARS, "%%%1") end
    return one_line
  end

  local tokens = {}
  local pos = 1
  local len = #text

  while pos <= len do
      local tag_start = text:find("<", pos, true)
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
      local tag_end = text:find(">", tag_start, true)
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
      return cleaned:gsub(CLEANUP_TEXT_CHARS, "%%%1")
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
function mpr_yesno(text, capital_only)
  local suffix = capital_only and " (Y/n)" or " (y/n)"
  crawl.formatted_mpr(text .. suffix, "prompt")
  local res = crawl.getch()
  if string.char(res) == "Y" or string.char(res) == "y" and not capital_only then
    return true
  end
  crawl.mpr("Okay, then.")
  return false
end

-- Sends a message that is displayed at end of turn
function enqueue_mpr(text, channel)
  for _, msg in ipairs(delayed_mpr_queue) do
    if msg.text == text and msg.channel == channel then
      return
    end
  end
  delayed_mpr_queue[#delayed_mpr_queue+1] = { text = text, channel = channel, show_more = false }
end

function enqueue_mpr_opt_more(show_more, text, channel)
  for _, msg in ipairs(delayed_mpr_queue) do
    if msg.text == text and msg.channel == channel and msg.show_more == show_more then
      return
    end
  end
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
    crawl.redraw_screen()
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
function get_mut(mutation, include_all)
  return you.get_base_mutation_level(mutation, true, include_all, include_all)
end

function get_talisman_min_level(it)
  local tokens = crawl.split(it.description, "\n")
  for _,v in ipairs(tokens) do
    if v:sub(1, 4) == "Min " then
      local start_pos = v:find("%d", 4)
      if start_pos then
        local end_pos = v:find("[^%d]", start_pos)
        return tonumber(v:sub(start_pos, end_pos - 1))
      end
    end
  end

  return 0 -- Fallback to 0, to surface any errors. Applies to Protean Talisman.
end

function have_shield()
  return is_shield(items.equipped_at("offhand"))
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

function has_risky_ego(it)
  local text = it.artefact and it.name() or it.ego()
  if not text then return false end
  for _, v in ipairs(RISKY_EGOS) do
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
  return it and it.is_shield()
end

function is_magic_staff(it)
  return it and it.class(true) == "magical staff"
end

function is_talisman(it)
  return it and it.name("qual"):find("talisman", 1, true)
end

function is_orb(it)
  return it and it.name("qual") == "orb"
end

function is_polearm(it)
  return it and it.weap_skill:find("Polearms", 1, true)
end

function offhand_is_free()
  if get_mut(MUTS.missing_hand, true) > 0 then return true end
  return not items.equipped_at("offhand")
end


--- Debugging utils for in-game lua interpreter ---
function debug_dump(verbose, skip_char_dump)
  local char_dump = not skip_char_dump
  if dump_persistent_data then dump_persistent_data(char_dump) end
  if dump_cache then dump_cache(char_dump) end
  if verbose then
    dump_inventory(char_dump)
    dump_chk_lua_save(char_dump)
  end
end

function dump_chk_lua_save(char_dump)
  dump_text(serialize_chk_lua_save(), char_dump)
end

function dump_inventory(char_dump, include_item_info)
  dump_text(serialize_inventory(include_item_info), char_dump)
end

function dump_text(msg, char_dump)
  crawl.mpr(with_color("white", msg))

  if char_dump then
    crawl.take_note(msg)
    crawl.dump_char()
  end
end

function serialize_chk_lua_save()
  local tokens = { "\n---CHK_LUA_SAVE---" }
  for _, func in ipairs(chk_lua_save) do
    tokens[#tokens+1] = util.trim(func())
  end
  return table.concat(tokens, "\n")
end

function serialize_inventory(include_item_info)
  local tokens = { "\n---INVENTORY---\n" }
  for inv in iter.invent_iterator:new(items.inventory()) do
    tokens[#tokens+1] = string.format("%s: (%s) Qual: %s", inv.slot, inv.quantity, inv.name("qual"))
    if include_item_info then
      local base = inv.name("base") or "N/A"
      local cls = inv.class(true) or "N/A"
      local st = inv.subtype() or "N/A"
      tokens[#tokens+1] = string.format("    Base: %s Class: %s, Subtype: %s", base, cls, st)
    end
    tokens[#tokens+1] = "\n"
  end
  return table.concat(tokens, "")
end
