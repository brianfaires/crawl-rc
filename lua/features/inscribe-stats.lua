----- Inscribe stats on items -----
local NUM_PATTERN = "[%+%-:]%d+%.%d*"

local function inscribe_armour_stats(it)
  -- Will add to the beginning of inscriptions, or replace it's own values
  -- This gsub's stats individually to avoid overwriting <color> tags
  -- NUM_PATTERN searches for numbers w/ decimal, to avoid artefact inscriptions
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
      new_insc = new_insc .. "; " .. it.inscription
    end
  end

  it.inscribe(new_insc, false)
end

local function inscribe_weapon_stats(it)
  local orig_inscr = it.inscription
  local dps_inscr = get_weapon_info_string(it)
  local prefix, suffix = "", ""

  local idx = orig_inscr:find("DPS:", 1, true)
  if idx then
    if idx > 1 then prefix = orig_inscr:sub(1, idx-1) .. "; " end
    if idx + #dps_inscr - 1 < #orig_inscr then
      suffix = orig_inscr:sub(idx + #dps_inscr, #orig_inscr)
    end
  elseif #orig_inscr > 0 then
    suffix = "; " .. orig_inscr
  end

  it.inscribe(table.concat({ prefix, dps_inscr, suffix }), false)
end


------------------ Hooks ------------------
function ready_inscribe_stats()
  for inv in iter.invent_iterator:new(items.inventory()) do
    if CONFIG.inscribe_weapons and inv.is_weapon then
      inscribe_weapon_stats(inv)
    elseif CONFIG.inscribe_armour and is_armour(inv) and not is_scarf(inv) then
      inscribe_armour_stats(inv)
    end
  end
end
