--[[
BRC Utility Functions - All utility functions organized into logical tables
--]]

-- Initialize
BRC = BRC or {}
BRC.mpr = {}
BRC.get = {}
BRC.is = {}
BRC.you = {}
BRC.text = {}
BRC.dump = {}

-- Local variables
local _mpr_queue = {}

-- Local constants
local CLEANUP_TEXT_CHARS = "([%^%$%(%)%%%.%[%]%*%+%-%?])"

---- BRC.text - Utility functions ----

-- Remove tags from text, and optionally escape special characters
function BRC.text.clean_text(text, escape_chars)
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
      tokens[#tokens + 1] = text:sub(pos)
      break
    end

    -- Append text before tag
    if tag_start > pos then tokens[#tokens + 1] = text:sub(pos, tag_start - 1) end

    -- Find end of tag
    local tag_end = text:find(">", tag_start, true)
    if not tag_end then
      -- Malformed tag, append remaining text
      tokens[#tokens + 1] = text:sub(pos)
      break
    end

    pos = tag_end + 1
  end

  -- Join all parts and remove newlines
  local cleaned = table.concat(tokens):gsub("\n", "")

  -- Handle escaping if needed
  if escape_chars then return cleaned:gsub(CLEANUP_TEXT_CHARS, "%%%1") end

  return cleaned
end

-- Wrap text in a color tag, Usage: BRC.text.blue("Hello"), or BRC.text["red"]("Hello")
for k, v in pairs(BRC.COLORS) do
  BRC.text[k] = function(text)
    return string.format("<%s>%s</%s>", v, text, v)
  end
end
function BRC.text.color(color, text)
  return color and BRC.text[color](text) or text
end

-- Get the ascii code for a key
function BRC.text.letter_to_ascii(key)
  return string.char(string.byte(key) - string.byte("a") + 1)
end

--- BRC.mpr - Wrappers around crawl.mpr ---

-- Display a message, wrapped in a single color tag
function BRC.mpr.color(text, color, channel)
  crawl.mpr(BRC.text.color(color, text), channel)
end

-- Message and stop travel/activity
function BRC.mpr.stop(text, color, channel)
  BRC.mpr.color(text, color, channel)
  you.stop_activity()
end

-- Message and a more prompt
function BRC.mpr.more(text, color, channel)
  BRC.mpr.color(text, color, channel)
  you.stop_activity()
  crawl.more()
  crawl.redraw_screen()
end

-- Conditionally display a more prompt
function BRC.mpr.optmore(show_more, text, color, channel)
  if show_more then
    BRC.mpr.more(text, color, channel)
  else
    BRC.mpr.color(text, color, channel)
  end
end

-- Queue a message, to dispay at start of next turn
function BRC.mpr.que(text, color, channel)
  for _, msg in ipairs(_mpr_queue) do
    if msg.text == text and msg.channel == channel then return end
  end
  _mpr_queue[#_mpr_queue + 1] = { text = BRC.text.color(color, text), channel = channel, show_more = false }
end

-- Queue msg w/ conditional force-more prompt
function BRC.mpr.que_optmore(show_more, text, color, channel)
  for _, msg in ipairs(_mpr_queue) do
    if msg.text == text and msg.channel == channel and msg.show_more == show_more then return end
  end
  _mpr_queue[#_mpr_queue + 1] = { text = BRC.text.color(color, text), channel = channel, show_more = show_more }
end

-- Display and consume the message queue
function BRC.mpr.consume_queue()
  local do_more = false
  for _, msg in ipairs(_mpr_queue) do
    crawl.mpr(msg.text, msg.channel)
    if msg.show_more then do_more = true end
  end

  if do_more then
    you.stop_activity()
    crawl.redraw_screen()
    crawl.more()
    crawl.redraw_screen()
  end

  _mpr_queue = {}
end

-- Get a yes/no response
function BRC.mpr.yesno(text, color, capital_only)
  local suffix = capital_only and " (Y/n)" or " (y/n)"
  crawl.formatted_mpr(BRC.text.color(color, text .. suffix), "prompt")
  local res = crawl.getch()
  if string.char(res) == "Y" or string.char(res) == "y" and not capital_only then return true end
  crawl.mpr("Okay, then.")
  return false
end

---- BRC.get - Functions to get non-boolean data ----

--[[
Returns 2 values: A list of equipped items of the type, and the num_slots (ie maximum size the list can ever be)
This is usually a list of length 1, and num_slots 1. Poltergeists will get all worn aux armours and num_slots=6.
It is possible to have a list with fewer than num_slots items in it.
--]]
function BRC.get.equipped_aux(aux_type)
  local all_aux = {}
  local num_slots = you.race() == "Poltergeist" and 6 or 1
  for i = 1, num_slots do
    local it = items.equipped_at(aux_type, i)
    all_aux[#all_aux + 1] = it
  end
  return all_aux, num_slots
end

function BRC.get.mut(mutation, include_all)
  return you.get_base_mutation_level(mutation, true, include_all, include_all)
end

function BRC.get.skill(skill)
  if not skill:find(",", 1, true) then return you.skill(skill) end

  local skills = crawl.split(skill, ",")
  local sum = 0
  local count = 0
  for _, s in ipairs(skills) do
    sum = sum + you.skill(s)
    count = count + 1
  end
  return sum / count
end

function BRC.get.skill_with(it)
  if BRC.is.magic_staff(it) then return math.max(BRC.get.skill(BRC.get.staff_school(it)), BRC.get.skill("Staves")) end
  if it.is_weapon then return BRC.get.skill(it.weap_skill) end
  if BRC.is.body_armour(it) then return BRC.get.skill("Armour") end
  if BRC.is.shield(it) then return BRC.get.skill("Shields") end
  if BRC.is.talisman(it) then return BRC.get.skill("Shapeshifting") end

  return 1 -- Fallback to 1
end

function BRC.get.staff_school(it)
  for k, v in pairs(BRC.ALL_STAFF_SCHOOLS) do
    if it.subtype() == k then return v end
  end
end

function BRC.get.talisman_min_level(it)
  -- Parse the item description
  local tokens = crawl.split(it.description, "\n")
  for _, v in ipairs(tokens) do
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

---- BRC.is - Boolean type checks of items ----

function BRC.is.amulet(it)
  return it and it.name("base") == "amulet"
end

function BRC.is.armour(it, include_orbs)
  -- exclude orbs by default
  if not it or it.class(true) ~= "armour" then return false end
  if not include_orbs and BRC.is.orb(it) then return false end
  return true
end

function BRC.is.aux_armour(it)
  return BRC.is.armour(it) and not (BRC.is.body_armour(it) or BRC.is.shield(it))
end

function BRC.is.body_armour(it)
  return it and it.subtype() == "body"
end

function BRC.is.jewellery(it)
  return it and it.class(true) == "jewellery"
end

function BRC.is.magic_staff(it)
  return it and it.class and it.class(true) == "magical staff"
end

function BRC.is.ring(it)
  return it and it.name("base") == "ring"
end

function BRC.is.scarf(it)
  return it and it.class(true) == "armour" and it.subtype() == "scarf"
end

function BRC.is.shield(it)
  return it and it.is_shield()
end

function BRC.is.talisman(it)
  if not it then return false end
  local c = it.class(true)
  return c and (c == "talisman" or c == "bauble")
end

function BRC.is.orb(it)
  return it and it.class(true) == "armour" and it.subtype() == "offhand" and not it.is_shield()
end

function BRC.is.polearm(it)
  return it and it.weap_skill:find("Polearms", 1, true)
end

---- BRC.you - Boolean attributes of the character ----

function BRC.you.free_offhand()
  if BRC.get.mut(BRC.MUTATIONS.missing_hand, true) > 0 then return true end
  return not items.equipped_at("offhand")
end

function BRC.you.have_shield()
  return BRC.is.shield(items.equipped_at("offhand"))
end

function BRC.you.in_hell()
  return util.contains(BRC.ALL_HELL_BRANCHES, you.branch())
end

function BRC.you.by_slimy_wall()
  for x = -1, 1 do
    for y = -1, 1 do
      if view.feature_at(x, y) == "slimy_wall" then return true end
    end
  end
  return false
end

function BRC.you.miasma_immune()
  if util.contains(BRC.ALL_UNDEAD_RACES, you.race()) then return true end
  if util.contains(BRC.ALL_NONLIVING_RACES, you.race()) then return true end
  return false
end

function BRC.you.mutation_immune()
  return util.contains(BRC.ALL_UNDEAD_RACES, you.race())
end

function BRC.you.zero_stat()
  return you.strength() <= 0 or you.dexterity() <= 0 or you.intelligence() <= 0
end

--- BRC.dump - Debugging utils called from in-game lua interpreter ---

function BRC.dump.all(verbose, skip_char_dump)
  local char_dump = not skip_char_dump
  BRC.data.dump(char_dump)
  if verbose then
    BRC.dump.inv(char_dump)
    BRC.dump.text(WEAP_CACHE.serialize(), char_dump)
    BRC.dump.data(char_dump)
  end
end

function BRC.dump.data(char_dump)
  local tokens = { "\n---CHK_LUA_SAVE---" }
  for _, func in ipairs(chk_lua_save) do
    tokens[#tokens + 1] = util.trim(func())
  end

  BRC.dump.text(table.concat(tokens, "\n"), char_dump)
end

function BRC.dump.inv(char_dump, include_item_info)
  local tokens = { "\n---INVENTORY---\n" }
  for inv in iter.invent_iterator:new(items.inventory()) do
    tokens[#tokens + 1] = string.format("%s: (%s) Qual: %s", inv.slot, inv.quantity, inv.name("qual"))
    if include_item_info then
      local base = inv.name("base") or "N/A"
      local cls = inv.class(true) or "N/A"
      local st = inv.subtype() or "N/A"
      tokens[#tokens + 1] = string.format("    Base: %s Class: %s, Subtype: %s", base, cls, st)
    end
    tokens[#tokens + 1] = "\n"
  end

  BRC.dump.text(table.concat(tokens), char_dump)
end

function BRC.dump.text(text, char_dump)
  BRC.mpr.color(text, BRC.COLORS.white)

  if char_dump then
    crawl.take_note(text)
    crawl.dump_char()
  end
end

--[[
The functions above are general purpose: They should apply to any crawl RC file.
The functions below contain design choices or logic that are somewhat specific to BRC.
Examples: Custom definition of `branded`, weapon DPS, or what a "risky ego" is.
--]]

-- Local functions; Many duplicate calculations that live in crawl.
-- Each such function is commented with the last dcss version it was compared against.

local function format_dmg(dmg)
  -- Always return a string of length 4
  if dmg < 10 then return string.format("%.2f", dmg) end
  if dmg > 99.9 then return ">100" end
  return string.format("%.1f", dmg)
end

local function format_stat(abbr, val, is_worn)
  local stat_str = string.format("%.1f", val)
  if val < 0 then
    return string.format("%s%s", abbr, stat_str)
  elseif is_worn then
    return string.format("%s:%s", abbr, stat_str)
  else
    return string.format("%s+%s", abbr, stat_str)
  end
end

local function get_size_penalty()
  if util.contains(BRC.ALL_LITTLE_RACES, you.race()) then
    return BRC.SIZE_PENALTY.LITTLE
  elseif util.contains(BRC.ALL_SMALL_RACES, you.race()) then
    return BRC.SIZE_PENALTY.SMALL
  elseif util.contains(BRC.ALL_LARGE_RACES, you.race()) then
    return BRC.SIZE_PENALTY.LARGE
  end
  return BRC.SIZE_PENALTY.NORMAL
end

local function get_unadjusted_armour_pen(encumb)
  -- dcss v0.33.1
  local pen = encumb - 2 * BRC.get.mut(BRC.MUTATIONS.sturdy_frame, true)
  if pen > 0 then return pen end
  return 0
end

local function get_adjusted_armour_pen(encumb, str)
  -- dcss v0.33.1
  local base_pen = get_unadjusted_armour_pen(encumb)
  return 2 * base_pen * base_pen * (45 - you.skill("Armour")) / 45 / (5 * (str + 3))
end

local function get_adjusted_dodge_bonus(encumb, str, dex)
  -- dcss v0.33.1
  local size_factor = -2 * get_size_penalty()
  local dodge_bonus = 8 * (10 + you.skill("Dodging") * dex) / (20 - size_factor) / 10
  local armour_dodge_penalty = get_unadjusted_armour_pen(encumb) - 3
  if armour_dodge_penalty <= 0 then return dodge_bonus end

  if armour_dodge_penalty >= str then return dodge_bonus * str / (armour_dodge_penalty * 2) end
  return dodge_bonus - dodge_bonus * armour_dodge_penalty / (str * 2)
end

local function get_shield_penalty(sh)
  -- dcss v0.33.1
  return 2 * sh.encumbrance * sh.encumbrance * (27 - you.skill("Shields")) / 27 / (25 + 5 * you.strength())
end

local function get_branded_delay(delay, ego)
  if not ego then return delay end
  if ego == "speed" then
    return delay * 2 / 3
  elseif ego == "heavy" then
    return delay * 1.5
  end
  return delay
end

local function get_weap_min_delay(it)
  -- dcss v0.33.1
  -- This is an abbreviated version of the actual calculation.
  -- Skips brand and >=3 checks, which are covered in get_weap_delay()
  if it.artefact and it.name("qual"):find("woodcutter's axe", 1, true) then return it.delay end

  local min_delay = math.floor(it.delay / 2)
  if it.weap_skill == "Short Blades" then return 5 end
  if it.is_ranged then
    local basename = it.name("base")
    local is_2h_ranged = basename:find("crossbow", 1, true) or basename:find("arbalest", 1, true)
    if is_2h_ranged then return math.max(min_delay, 10) end
  end

  return math.min(min_delay, 7)
end

local function get_weap_delay(it)
  -- dcss v0.33.1
  local delay = it.delay - BRC.get.skill(it.weap_skill) / 2
  delay = math.max(delay, get_weap_min_delay(it))
  delay = get_branded_delay(delay, BRC.get.ego(it))
  delay = math.max(delay, 3)

  local sh = items.equipped_at("offhand")
  if BRC.is.shield(sh) then delay = delay + get_shield_penalty(sh) end

  if it.is_ranged then
    local worn = items.equipped_at("armour")
    if worn then
      local str = you.strength()

      local cur = items.equipped_at("weapon")
      if cur and cur ~= it and cur.artefact then
        if it.artefact and it.artprops["Str"] then str = str + it.artprops["Str"] end
        if cur.artefact and cur.artprops["Str"] then str = str - cur.artprops["Str"] end
      end

      delay = delay + get_adjusted_armour_pen(worn.encumbrance, str)
    end
  end

  return delay / 10
end

local function get_slay_bonuses()
  local sum = 0

  -- Slots can go as high as 18 afaict
  for i = 0, 20 do
    local it = items.equipped_at(i)
    if it then
      if BRC.is.ring(it) then
        if it.artefact then
          local name = it.name()
          local idx = name:find("Slay", 1, true)
          if idx then
            local slay = tonumber(name:sub(idx + 5, idx + 5))
            if slay == 1 then
              local next_digit = tonumber(name:sub(idx + 6, idx + 6))
              if next_digit then slay = 10 + next_digit end
            end

            if name:sub(idx + 4, idx + 4) == "+" then
              sum = sum + slay
            else
              sum = sum - slay
            end
          end
        elseif BRC.get.ego(it) == "Slay" then
          sum = sum + it.plus
        end
      elseif it.artefact and (BRC.is.armour(it, true) or BRC.is.amulet(it)) then
        local slay = it.artprops["Slay"]
        if slay then sum = sum + slay end
      end
    end
  end

  if you.race() == "Demonspawn" then
    sum = sum + 3 * BRC.get.mut(BRC.MUTATIONS.augmentation, true)
    sum = sum + BRC.get.mut(BRC.MUTATIONS.sharp_scales, true)
  end

  return sum
end

local function get_staff_bonus_dmg(it, dmg_type)
  -- dcss v0.33.1
  if dmg_type == BRC.DMG_TYPE.unbranded then return 0 end
  if dmg_type == BRC.DMG_TYPE.plain then
    local basename = it.name("base")
    if basename ~= "staff of earth" and basename ~= "staff of conjuration" then return 0 end
  end

  local spell_skill = BRC.get.skill(BRC.get.staff_school(it))
  local evo_skill = you.skill("Evocations")

  local chance = (2 * evo_skill + spell_skill) / 30
  if chance > 1 then chance = 1 end
  -- 0.75 is an acceptable approximation; most commonly 63/80
  -- Varies by staff type in sometimes complex ways
  local avg_dmg = 3 / 4 * (evo_skill / 2 + spell_skill)
  return avg_dmg * chance
end

-- Formatting for stat inscriptions & alerts
function BRC.get.armour_info(it)
  if not BRC.is.armour(it) then return "", "" end

  -- Compare against last slot if poltergeist
  local slot_num = you.race() == "Poltergeist" and 6 or 1
  local cur = items.equipped_at(it.equip_type, slot_num)
  local is_worn = it.equipped or (it.ininventory and cur and cur.slot == it.slot)
  local cur_ac = 0
  local cur_sh = 0
  local cur_ev = 0
  if cur and not is_worn then
    -- Show deltas if not worn, else compare against 0
    if BRC.is.shield(cur) then
      cur_sh = BRC.get.shield_sh(cur)
      cur_ev = -get_shield_penalty(cur)
    else
      cur_ac = BRC.get.armour_ac(cur)
      cur_ev = BRC.get.armour_ev(cur)
    end
  end

  if BRC.is.shield(it) then
    local sh_str = format_stat("SH", BRC.get.shield_sh(it) - cur_sh, is_worn)
    local ev_str = format_stat("EV", -get_shield_penalty(it) - cur_ev, is_worn)
    return sh_str, ev_str
  else
    local ac_str = format_stat("AC", BRC.get.armour_ac(it) - cur_ac, is_worn)
    if not BRC.is.body_armour(it) then return ac_str end
    local ev_str = format_stat("EV", BRC.get.armour_ev(it) - cur_ev, is_worn)
    return ac_str, ev_str
  end
end

function BRC.get.weapon_info(it, dmg_type)
  if not it.is_weapon then return end
  dmg_type = dmg_type or BRC.DMG_TYPE[BRC.Config.inscribe_dps_type] or BRC.DMG_TYPE.plain
  local dmg = format_dmg(BRC.get.weap_damage(it, dmg_type))
  local delay = get_weap_delay(it)
  local delay_str = string.format("%.1f", delay)
  if delay < 1 then
    delay_str = string.format("%.2f", delay)
    delay_str = delay_str:sub(2, #delay_str)
  end

  local dps = format_dmg(dmg / delay)
  local acc = it.accuracy + (it.plus or 0)
  if acc >= 0 then acc = string.format("+%s", acc) end

  --TODO: This would be nice if it worked in all UIs
  --return string.format("DPS:<w>%s</w> (%s/%s), Acc<w>%s</w>", dps, dmg, delay_str, acc)
  return string.format("DPS: %s (%s/%s), Acc%s", dps, dmg, delay_str, acc)
end

-- Egos
function BRC.get.ego(it)
  if BRC.is.usable_ego(it) then
    return type(it.ego) == "string" and it.ego or it.ego(true)
  elseif BRC.is.body_armour(it) then
    local qualname = it.name("qual")
    if qualname:find("dragon scales") or qualname:find("troll leather", 1, true) then return qualname end
  end
end

function BRC.get.hands(it)
  if you.race() ~= "Formicid" then return it.hands end
  local st = it.subtype()
  if st == "giant club" or st == "giant spiked club" then return 2 end
  return 1
end

--[[
BRC.is.branded - Checks if an item is branded, with a custom definition:
Excludes unusable egos. Includes: artefacts, and armour with innate egos (except steam dragon scales)
--]]
function BRC.is.branded(it, exclude_stat_only_egos)
  if not it then return false end
  if it.is_weapon then
    if exclude_stat_only_egos then
      local ego = BRC.get.ego(it)
      if ego and (ego == "speed" or ego == "heavy") then return false end
    end
    return it.artefact or BRC.is.usable_ego(it) or BRC.is.magic_staff(it)
  end

  if it.artefact or BRC.is.usable_ego(it) then return true end
  local basename = it.name("base")
  if basename:find("troll leather", 1, true) then return true end
  if basename:find("dragon scales", 1, true) and not basename:find("steam", 1, true) then return true end
  return false
end

function BRC.is.usable_ego(it)
  if not it.branded then return false end
  -- ego may be a string if referencing a WEAP_CACHE entry
  local ego = type(it.ego) == "string" and it.ego or it.ego(true)
  if ego == "holy" and util.contains(BRC.ALL_POIS_RES_RACES, you.race()) then return false end
  if ego == "rPois" and util.contains(BRC.ALL_POIS_RES_RACES, you.race()) then return false end
  return true
end

function BRC.is.risky_ego(it)
  local text = it.artefact and it.name() or BRC.get.ego(it)
  if not text then return false end
  for _, v in ipairs(BRC.ALL_RISKY_EGOS) do
    if text:find(v) then return true end
  end
  return false
end

-- Armour stats
function BRC.get.armour_ac(it)
  -- dcss v0.33.1
  local it_plus = it.plus or 0

  if it.artefact and it.is_identified then
    local art_ac = it.artprops["AC"]
    if art_ac then it_plus = it_plus + art_ac end
  end

  local ac = it.ac * (1 + you.skill("Armour") / 22) + it_plus
  if not BRC.is.body_armour(it) then return ac end

  local deformed = BRC.get.mut(BRC.MUTATIONS.deformed, true) > 0
  local pseudopods = BRC.get.mut(BRC.MUTATIONS.pseudopods, true) > 0
  if pseudopods or deformed then return ac * 6 / 10 end

  return ac
end

function BRC.get.armour_ev(it)
  -- dcss v0.33.1
  -- This function computes the armour-based component to standard EV (not paralysed, etc)
  -- Factors in stat changes from this armour and removing current one
  local str = you.strength()
  local dex = you.dexterity()
  local no_art_str = str
  local no_art_dex = dex
  local art_ev = 0

  -- Adjust str/dex/EV for artefact stat changes
  local worn = items.equipped_at("armour")
  if worn and worn.artefact then
    if worn.artprops["Str"] then str = str - worn.artprops["Str"] end
    if worn.artprops["Dex"] then dex = dex - worn.artprops["Dex"] end
    if worn.artprops["EV"] then art_ev = art_ev - worn.artprops["EV"] end
  end

  if it.artefact then
    if it.artprops["Str"] then str = str + it.artprops["Str"] end
    if it.artprops["Dex"] then dex = dex + it.artprops["Dex"] end
    if it.artprops["EV"] then art_ev = art_ev + it.artprops["EV"] end
  end

  if str <= 0 then str = 1 end

  local dodge_bonus = get_adjusted_dodge_bonus(it.encumbrance, str, dex)
  local naked_dodge_bonus = get_adjusted_dodge_bonus(0, no_art_str, no_art_dex)
  return (dodge_bonus - naked_dodge_bonus) + art_ev - get_adjusted_armour_pen(it.encumbrance, str)
end

function BRC.get.shield_sh(it)
  -- dcss v0.33.1
  local dex = you.dexterity()
  if it.artefact and it.is_identified then
    local art_dex = it.artprops["Dex"]
    if art_dex then dex = dex + art_dex end
  end

  local cur = items.equipped_at("offhand")
  if BRC.is.shield(cur) and cur.artefact and cur.slot ~= it.slot then
    local art_dex = cur.artprops["Dex"]
    if art_dex then dex = dex - art_dex end
  end

  local it_plus = it.plus or 0

  local base_sh = it.ac * 2
  local shield = base_sh * (50 + you.skill("Shields") * 5 / 2)
  shield = shield + 200 * it_plus
  shield = shield + 38 * (you.skill("Shields") + 3 + dex * (base_sh + 13) / 26)
  return shield / 200
end

-- Weapon stats
function BRC.get.weap_dps(it, dmg_type)
  if not dmg_type then dmg_type = BRC.DMG_TYPE.scoring end
  return BRC.get.weap_damage(it, dmg_type) / get_weap_delay(it)
end

function BRC.get.weap_damage(it, dmg_type)
  -- Returns an adjusted weapon damage = damage * speed
  -- Includes stat/slay changes between weapon and the one currently wielded
  -- Aux attacks not included
  if not dmg_type then dmg_type = BRC.DMG_TYPE.scoring end
  local it_plus = it.plus or 0
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

  local stat = str
  if it.is_ranged or it.weap_skill:find("Blades", 1, true) then stat = dex end

  local stat_mod = 0.75 + 0.025 * stat
  local skill_mod = (1 + BRC.get.skill(it.weap_skill) / 25 / 2) * (1 + you.skill("Fighting") / 30 / 2)

  it_plus = it_plus + get_slay_bonuses()

  local pre_brand_dmg_no_plus = it.damage * stat_mod * skill_mod
  local pre_brand_dmg = pre_brand_dmg_no_plus + it_plus

  if BRC.is.magic_staff(it) then return (pre_brand_dmg + get_staff_bonus_dmg(it, dmg_type)) end

  if dmg_type == BRC.DMG_TYPE.plain then
    local ego = BRC.get.ego(it)
    if ego and util.contains(BRC.PLAIN_DMG_EGOS, ego) then
      local bonus = BRC.BrandBonus[ego] or BRC.BrandBonus.subtle[ego]
      return bonus.factor * pre_brand_dmg_no_plus + it_plus + bonus.offset
    end
  elseif dmg_type >= BRC.DMG_TYPE.branded then
    local ego = BRC.get.ego(it)
    if ego then
      local bonus = BRC.BrandBonus[ego]
      if not bonus and dmg_type == BRC.DMG_TYPE.scoring then bonus = BRC.BrandBonus.subtle[ego] end
      if bonus then return bonus.factor * pre_brand_dmg_no_plus + it_plus + bonus.offset end
    end
  end

  return pre_brand_dmg
end

function BRC.get.weap_score(it, no_brand_bonus)
  if it.dps and it.acc then
    -- Handle cached /  high-score tuples in WEAP_CACHE
    return it.dps + it.acc * BRC.Tuning.weap.pickup.accuracy_weight
  end
  local it_plus = it.plus or 0
  local dmg_type = no_brand_bonus and BRC.DMG_TYPE.unbranded or BRC.DMG_TYPE.scoring
  return BRC.get.weap_dps(it, dmg_type) + (it.accuracy + it_plus) * BRC.Tuning.weap.pickup.accuracy_weight
end
