---------------------------------------------------------------------------------------------------
-- BRC feature module: inscribe-stats
-- @module f_inscribe_stats
-- Inscribes and updates weapon DPS/dmg/delay, and armour AC/EV/SH, for items in inventory.
-- For Coglin weapons, evaluates as if swapping out the primary weapon (for artefact stat changes)
---------------------------------------------------------------------------------------------------

f_inscribe_stats = {}
f_inscribe_stats.BRC_FEATURE_NAME = "inscribe-stats"
f_inscribe_stats.Config = {
  inscribe_weapons = true, -- Inscribe weapon stats on pickup
  inscribe_armour = true, -- Inscribe armour stats on pickup
  dmg_type = BRC.DMG_TYPE.unbranded, -- unbranded, plain, branded, scoring
  skip_dps = false, -- Skip DPS in weapon inscriptions
  prefix_staff_dmg = true, -- Special prefix for magical staves
} -- f_inscribe_stats.Config (do not remove this comment)

---- Local constants ----
local NUM_PATTERN = "[%+%-:]%d+%.%d*" -- Matches numbers w/ decimal

---- Local variables ----
local C -- config alias

---- Initialization ----
function f_inscribe_stats.init()
  C = f_inscribe_stats.Config
end

---- Local functions ----
local function inscribe_armour_stats(it)
  local abbr = BRC.it.is_shield(it) and "SH" or "AC"
  local ac_or_sh, ev = BRC.eq.arm_stats(it)
  local sign_change = false

  local new_insc
  if it.inscription:find(abbr .. NUM_PATTERN) then
    new_insc = it.inscription:gsub(abbr .. NUM_PATTERN, ac_or_sh)
    if not it.inscription:contains(ac_or_sh:sub(1, 3)) then sign_change = true end

    if ev and ev ~= "" then
      new_insc = new_insc:gsub("EV" .. NUM_PATTERN, ev)
      if not it.inscription:contains(ev:sub(1, 3)) then sign_change = true end
    end
  else
    new_insc = ac_or_sh
    if ev and ev ~= "" then new_insc = string.format("%s, %s", new_insc, ev) end
    if it.inscription and it.inscription ~= "" then
      new_insc = string.format("%s; %s", new_insc, it.inscription)
    end
  end

  it.inscribe(new_insc, false)

  -- If f_color_inscribe is enabled, update the color
  if
    sign_change
    and f_color_inscribe
    and f_color_inscribe.Config
    and not f_color_inscribe.Config.disabled
    and f_color_inscribe.colorize
  then
    f_color_inscribe.colorize(it)
  end
end

local function get_staff_dmg_str(it)
  local _, dmg, chance = BRC.eq.get_staff_bonus_dmg(it)
  if dmg == 0 or chance == 0 then return "(+0)" end
  if chance >= 1 then return string.format("(+%d)", math.floor(dmg)) end
  return string.format("(+%.0f|%.0f%%%%)", dmg, chance * 100)
end

--- Replace the old inscription with the current one, preserving prefix/suffix
local function update_inscription(orig, cur)
  local first = orig:find(cur:sub(1, 4))
  if not first then return cur .. "; " .. orig end

  local _, last = orig:find("A%+%d+")
  if not last then
    _, last = orig:find("A%-%d+")
  end
  if not last then
    BRC.mpr.error("Missing accuracy in inscription: " .. orig)
    return cur .. "; " .. orig
  end

  local prefix = orig:sub(1, first - 1)
  if #prefix > 0 and prefix:sub(-2) ~= "; " then prefix = prefix .. "; " end
  if prefix == "; " then prefix = "" end

  local suffix = util.trim(orig:sub(last+1))
  if #suffix > 0 and suffix:sub(1, 1) ~= ";" then suffix = "; " .. suffix end
  if suffix == ";" then suffix = "" end

  return prefix .. cur .. suffix
end

local function inscribe_weapon_stats(it)
  local orig_inscr = it.inscription
  local dmg_type = C.dmg_type
  if type(dmg_type) == "string" then
    dmg_type = BRC.DMG_TYPE[dmg_type]
  end

  local dps_inscr = BRC.eq.wpn_stats(it, dmg_type, C.skip_dps)
  if C.prefix_staff_dmg and BRC.it.is_magic_staff(it) then
    local bonus_str = get_staff_dmg_str(it)
    dps_inscr = dps_inscr:gsub("/", bonus_str .. "/")
    -- Recuce weapon damage string from #.## -> #
    local dmg_index = dps_inscr:find("=%d+%.%d%d")
    if dmg_index then
      local dmg_str = dps_inscr:sub(dmg_index + 1, dmg_index + 4)
      local dmg_int = math.floor(tonumber(dmg_str)+0.5)
      dps_inscr = dps_inscr:gsub("=" .. dmg_str, "=" .. dmg_int)
    end
  end

  it.inscribe(update_inscription(orig_inscr, dps_inscr), false)
end

---- Crawl hook functions ----
function f_inscribe_stats.do_stat_inscription(it)
  if C.inscribe_weapons and it.is_weapon then
    inscribe_weapon_stats(it)
  elseif C.inscribe_armour
    and BRC.it.is_armour(it)
    and not BRC.it.is_scarf(it)
  then
    inscribe_armour_stats(it)
  end
end

function f_inscribe_stats.ready()
  for _, inv in ipairs(items.inventory()) do
    f_inscribe_stats.do_stat_inscription(inv)
  end
end
