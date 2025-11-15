---------------------------------------------------------------------------------------------------
-- BRC feature module: bread-swinger
-- @module f_bread_swinger
-- @author gammafunk, buehler
-- Efficient resting during turncount runs, by wielding slow weapons, or walking back and forth.
-- Based on: https://github.com/gammafunk/dcss-rc/blob/master/speedrun_rest.lua
---------------------------------------------------------------------------------------------------

f_bread_swinger = {}
f_bread_swinger.BRC_FEATURE_NAME = "bread-swinger"
f_bread_swinger.Config = {
  disabled = true, -- Disable by default
  allow_plant_damage = false, -- Allow damaging plants to rest
  walk_delay = 50, -- ms delay between walk commands. Makes visuals less jarring. 0 to disable.
  alert_slow_weap_min = 1.5, -- Alert when finding the slowest weapon yet, starting at this delay.
} -- f_bread_swinger.Config (do not remove this comment)

---- Persistent variables ----
bs_manual_swing_slot = BRC.Data.persist("bs_manual_swing_slot", nil)
bs_highest_delay = BRC.Data.persist("bs_highest_delay", 0)
bs_highest_delay_1h = BRC.Data.persist("bs_highest_delay_1h", 0)

---- Local constants ----
local DIR_TO_VI = {
  [-1] = { [-1] = "y", [0] = "h", [1] = "b" },
  [0] = { [-1] = "k", [1] = "j" },
  [1] = { [-1] = "u", [0] = "l", [1] = "n" },
} -- DIR_TO_VI (do not remove this comment)

local SOLID_FEATURES = {
  "wall", "grate", "tree", "mangrove", "endless_lava", "open_sea", "statue", "idol",
  "malign_gateway", "sealed_door", "closed_door", "runed_door", "explore_horizon"
} -- SOLID_FEATURES (do not remove this comment)

---- Local variables ----
local C -- config alias
local swing_slot
local turns_remaining
local turns_to_rest
local rest_type
local wielding
local dir

---- Local functions ----
local function reset_rest(msg)
  -- Display msg iff we're aborting a rest command
  if turns_remaining and turns_remaining > 0 and msg then
    if turns_remaining ~= turns_to_rest then
      local diff = turns_to_rest - turns_remaining
      msg = string.format("%s (Rested %s/%s turns)", msg, diff, turns_to_rest)
    end
    BRC.mpr.warning(msg)
  end

  swing_slot = nil
  turns_remaining = 0
  turns_to_rest = 0
  rest_type = nil
  wielding = false
  dir = { x = nil, y = nil }
end

local function get_num_turns()
  BRC.mpr.info(BRC.txt.white("Enter number of turns to rest")
    .. " (Esc to manually set weapon slot): ")
  local input = crawl.c_input_line()
  local turns = tonumber(input)
  if not turns then
    return nil
  elseif turns <= 0 then
    BRC.mpr.warning("Must be a positive number!")
    return 0
  end
  return turns
end

local function do_alert(msg, it)
  local tokens = {}
  tokens[1] = BRC.Config.emojis and "🍞 " or BRC.txt.cyan("---- ")
  tokens[#tokens + 1] = msg .. ": "
  tokens[#tokens + 1] = BRC.txt.cyan(it.name() .. " (")
  tokens[#tokens + 1] = BRC.txt.lightmagenta(string.format("%.2f", BRC.eq.get_weap_delay(it)))
  tokens[#tokens + 1] = BRC.txt.cyan(") ")
  tokens[#tokens + 1] = tokens[1]
  BRC.mpr.que(table.concat(tokens))
  you.stop_activity()
end

-- Weapon functions
local function weapon_can_swap()
  local weapon = items.equipped_at("Weapon")
  if not weapon then return true end

  if weapon.ego() == "distortion" and you.god() ~= "Lugonu" then return false end

  if weapon.artefact then
    local artp = weapon.artprops
    return not (artp["*Contam"] or artp["*Drain"])
  end

  return true
end

local function get_slowest_slot()
  local slowest_slot = nil
  local largest_delay = 0
  for _, item in ipairs(items.inventory()) do
    if item.class() == "Hand Weapons" and BRC.eq.get_weap_delay(item) > largest_delay then
      largest_delay = BRC.eq.get_weap_delay(item)
      slowest_slot = item.slot
    end
  end

  if not slowest_slot then return nil end
  return items.index_to_letter(slowest_slot)
end

local function swing_item_wielded()
  local weapon = items.equipped_at("Weapon")
  if not weapon or not swing_slot then return false end
  return weapon.slot == items.letter_to_index(swing_slot)
end

local function wield_swing_item()
  if not swing_slot then return end
  wielding = true
  BRC.opt.single_turn_mute(swing_slot .. " - ")
  crawl.sendkeys({ "w", "*", swing_slot })
  crawl.flush_input()
end

-- Feature checks
local function is_water(x, y)
  local feat = view.feature_at(x, y)
  return feat and feat:contains("water") and not you.status("flying")
end

local function is_monster(x, y)
  local mon = monster.get_monster_at(x, y)
  return mon and not (C.allow_plant_damage and mon.is_stationary())
end

local function is_solid(x, y)
  local feat = view.feature_at(x, y):lower()
  return util.exists(SOLID_FEATURES, function(f) return feat:find(f) end)
end

-- Setting direction to move or swing
local function is_good_dir_walk(x, y)
  if x == 0 and y == 0 then return false end
  return is_water(x, y) == is_water(0, 0)
    and view.is_safe_square(x, y)
    and not is_solid(x, y)
    and not monster.get_monster_at(x, y)
end

local function is_good_dir_swing(x, y)
  if x == 0 and y == 0 then return false end
  local weapon = items.equipped_at("Weapon")
  if not weapon then return false end

  if weapon.is_ranged then
    -- Confirm no monsters in straight line
    for i = 1, you.los() do
      local cur_x = i * x
      local cur_y = i * y
      if is_monster(cur_x, cur_y) then return false end
      if is_solid(cur_x, cur_y) then break end
    end
  elseif weapon.weap_skill:contains("Axes") then
    -- Confirm no monsters in adjacent squares
    for cur_x = -1, 1 do
      for cur_y = -1, 1 do
        if is_monster(cur_x, cur_y) then return false end
      end
    end
  else
    return not is_solid(x, y) and not is_monster(x, y)
  end

  return true
end

local function get_good_direction()
  local func_is_good_dir = rest_type == "walk" and is_good_dir_walk or is_good_dir_swing
  for x = -1, 1 do
    for y = -1, 1 do
      if func_is_good_dir(x, y) then return x, y end
    end
  end
  return nil
end

local function set_good_direction()
  if rest_type == "walk" and dir.x ~= nil then
    -- Try to move back and forth by saving next dir
    if is_good_dir_walk(dir.x, dir.y) then return true end
    dir.x = nil
  end
  if dir.x == nil or not is_good_dir_swing(dir.x, dir.y) then
    dir.x, dir.y = get_good_direction()
    if not dir.x then
      reset_rest("No good direction found!")
      return false
    end
  end

  return true
end

-- Resting
local function set_rest_type()
  local inv = items.inslot(items.letter_to_index(swing_slot))
  if not swing_slot
    or (not swing_item_wielded() and not weapon_can_swap())
    or you.movement_cost and you.movement_cost() > 10 * BRC.eq.get_weap_delay(inv)
  then
    rest_type = "walk"
  else
    rest_type = "item"
  end
end

local function verify_safe_rest()
  local hp, mhp = you.hp()
  if hp == mhp then
    reset_rest("You are already at full health!")
    return false
  elseif turns_remaining <= 0 then
    reset_rest()
    return false
  elseif not you.feel_safe() then
    reset_rest("You can't rest with a hostile monster in view!")
    return false
  elseif rest_type == "walk" then
    if you.movement_cost and you.movement_cost() <= 10 then
      reset_rest("You can't walk slowly right now!")
      return false
    elseif you.status("manticore barbs") then
      reset_rest("You must remove the manticore barbs first.")
      return false
    end
  end
  return true
end

local function do_resting()
  if not set_good_direction() then return end

  if rest_type == "item" then
    BRC.opt.single_turn_mute("You swing at nothing.")
    BRC.opt.single_turn_mute("You shoot ")
    crawl.sendkeys({ BRC.util.cntl(DIR_TO_VI[dir.x][dir.y]) })
    crawl.flush_input()
  else
    -- Save the return direction as our next direction
    local cur_x = dir.x
    local cur_y = dir.y
    dir.x = -dir.x
    dir.y = -dir.y
    crawl.sendkeys({ DIR_TO_VI[cur_x][cur_y] })
    crawl.flush_input()

    if C.walk_delay > 0 then crawl.delay(C.walk_delay) end
  end

  turns_remaining = turns_remaining - 1
  if turns_remaining <= 0 then
    BRC.mpr.green("Resting complete. (" .. turns_to_rest .. " turns)")
    reset_rest()
  end
end


---- Public API ----
function macro_brc_bread_swing(turns)
  turns_to_rest = turns or get_num_turns()
  if not turns_to_rest then
    f_bread_swinger.set_swing_slot()
    return
  elseif turns_to_rest <= 0 then
    return
  end
  turns_remaining = turns_to_rest

  -- Set swing slot
  local slowest_slot = get_slowest_slot()
  swing_slot = bs_manual_swing_slot or slowest_slot
  if not swing_slot then return end
  local weap = items.inslot(items.letter_to_index(swing_slot))
  if not weap or not weap.is_weapon then
    BRC.mpr.warning("Swing slot " .. BRC.txt.lightmagenta(swing_slot) .. " is not a weapon!")
    return
  end

  -- Determine rest type
  set_rest_type()
  if rest_type == "walk" and turns_to_rest % 2 == 1 then
    turns_to_rest = turns_to_rest - 1
    turns_remaining = turns_remaining - 1
  end

  f_bread_swinger.ready()
end

function f_bread_swinger.set_swing_slot()
  BRC.mpr.info(BRC.txt.white("Enter the inventory slot") .. " for the swing item: ")
  local letter = crawl.getch()
  if not letter or letter < string.byte('A') or letter > string.byte('z') then
    bs_manual_swing_slot = nil
    BRC.mpr.info(BRC.txt.magenta("Swing slot cleared.") .. " (Must be a letter a-z or A-Z).")
    return
  end
  bs_manual_swing_slot = string.char(letter)
  BRC.mpr.info(BRC.txt.lightgrey("Set swing slot to " .. BRC.txt.cyan(bs_manual_swing_slot) .. "."))
end

---- Initialization ----
function f_bread_swinger.init()
  C = f_bread_swinger.Config
  reset_rest()
  BRC.opt.macro("5", "macro_brc_bread_swing")
end

---- Crawl hook functions ----
function f_bread_swinger.c_message(_, channel)
  if turns_remaining <= 0 then return end
  if channel == "recovery" or channel == "duration" then return end
  reset_rest() -- Stop on any unrecognized message
end

function f_bread_swinger.ready()
  if not turns_remaining or turns_remaining <= 0 then return end
  if not verify_safe_rest() then return end

  if wielding and not swing_item_wielded() then
    -- An error happened with the 'w' command
    reset_rest("Unable to wield swing item on slot " .. swing_slot .. "!")
    return
  end

  if rest_type == "item" and not swing_item_wielded() then
    wield_swing_item()
  else
    do_resting()
  end
end

function f_bread_swinger.autopickup(it)
  if it.is_useless or not it.is_weapon then return nil end
  local delay = BRC.eq.get_weap_delay(it)
  if delay < C.alert_slow_weap_min then return nil end

  if delay > bs_highest_delay and (BRC.eq.get_hands(it) == 1 or BRC.you.free_offhand()) then
    bs_highest_delay = delay
    if BRC.eq.get_hands(it) == 1 then bs_highest_delay_1h = delay end
    do_alert("Found slowest weapon", it)
  elseif delay > bs_highest_delay_1h
    and BRC.eq.get_hands(it) == 1
    and not BRC.you.free_offhand()
  then
    bs_highest_delay_1h = delay
    do_alert("Found slowest 1-handed weapon", it)
  end
end
