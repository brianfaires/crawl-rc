----- Inscribe stats on items -----
loadfile("crawl-rc/lua/config.lua")
loadfile("crawl-rc/lua/util.lua")

local skipped_first_redraw = false

local function inscribe_armour_stats(it)
  -- Will add to the beginning of inscriptions, or replace it's own values
  -- This gsub's stats individually to avoid overwriting <color> tags
  -- NUM_PATTERN searches for numbers w/ decimal, to avoid artefact inscriptions
  local NUM_PATTERN = "[%+%-:]%d+%.%d*"
  local abbr = is_shield(it) and "SH" or "AC"
  local primary, ev = get_armour_info_strings(it)

  local new_insc
  if it.inscription:find(abbr .. NUM_PATTERN) then
    new_insc = it.inscription:gsub(abbr .. NUM_PATTERN, primary)
    if ev and ev ~= "" then
      new_insc = new_insc:gsub("EV" .. NUM_PATTERN, ev)
    end
  else
    new_insc = primary
    if ev and ev ~= "" then
      new_insc = new_insc .. ", " .. ev
    end
    if it.inscription and it.inscription ~= "" then
      new_insc = new_insc .. " " .. it.inscription
    end
  end

  it.inscribe(new_insc, false)
end

local function inscribe_weapon_stats(it)
  local new_inscr = get_weapon_info_string(it)

  local idx = it.inscription:find("DPS:")
  if idx then
    if idx + #new_inscr <= #it.inscription then
      new_inscr = new_inscr .. it.inscription:sub(idx + #new_inscr, #it.inscription)
    end
    if idx > 1 then new_inscr = it.inscription:sub(1, idx-1) .. new_inscr end
  end

  it.inscribe(new_inscr, false)
  return new_inscr
end


------------------ Hook ------------------
function ready_inscribe_stats()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if is_weapon(inv) or is_staff(inv) then
      if CONFIG.inscribe_weapons then inscribe_weapon_stats(inv) end
    elseif is_armour(inv) then
      if CONFIG.inscribe_armour and not is_scarf(inv) then inscribe_armour_stats(inv) end
    end
  end

  -- This redraw can causes crashes if called during an autopickup.
  -- Be sure not to hook any of this to c_message, or anything that can trigger during an autopickup
  if skipped_first_redraw then crawl.redraw_screen()
  else skipped_first_redraw = true
  end
end
