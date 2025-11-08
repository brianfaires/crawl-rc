---------------------------------------------------------------------------------------------------
-- BRC feature module: bread-swinger
-- @module f_bread_swinger
-- @author gammafunk, buehler
-- Efficient resting during speedruns by wielding slow items at nothing,
-- or walking back and forth slowly when item swinging isn't possible.
-- Based on: https://github.com/gammafunk/dcss-rc/blob/master/speedrun_rest.lua
---------------------------------------------------------------------------------------------------

f_bread_swinger = {}
f_bread_swinger.BRC_FEATURE_NAME = "bread-swinger"
f_bread_swinger.Config = {
  naga_always_walk = false, -- Naga always walk instead of item swing
  walk_delay = 50, -- ms delay between walk commands. Make visuals less jarring.

  -- Status messages to ignore during rest. Key is status from you.status().
  status_messages = {
    ["poisoned"] = {"You feel[^%.]+sick%.", "You are no longer poisoned%."},
    ["regenerating"] = {
      "You feel the effects of Trog's Hand fading%.",
      "Your skin is crawling a little less now%.",
    },
  },

  -- Arbitrary messages to ignore during rest
  ignore_messages = {
    -- RandomTiles messages
    "Trog roars: Now[^!]+!+",
    "Sif Muna whispers: Become[^!]+!+",
    "[^:]+ says: Become[^!]+!+",
    -- Debug messages
    "Dbg:.*",
  },
} -- f_bread_swinger.Config (do not remove this comment)

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
local Config
local bs_swing_slot
local turns_remaining
local wielding
local dir

---- Local functions ----
local function reset_rest(msg)
  if turns_remaining and turns_remaining > 0 and msg then BRC.mpr.warning(msg) end

  bs_swing_slot = nil
  turns_remaining = 0
  wielding = false
  dir = { x = nil, y = nil }
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
  if not weapon or not bs_swing_slot then return false end
  return weapon.slot == items.letter_to_index(bs_swing_slot)
end

local function wield_swing_item()
  if not bs_swing_slot then return end
  wielding = true
  crawl.sendkeys({ "w", "*", bs_swing_slot })
  crawl.flush_input()
end

-- Feature checks
local function in_water()
  local feat = view.feature_at(0, 0)
  return feat and feat:contains("water") and not you.status("flying")
end

local function feat_is_open(feat)
  local lower = feat:lower()
  return not util.exists(SOLID_FEATURES, function(f) return lower:find(f) end)
end

-- Player attributes
local function get_rest_type()
  if you.race() == "Naga" and Config.naga_always_walk
    or you.god() == "Cheibriados"
    or (not swing_item_wielded() and not weapon_can_swap())
  then
    return "walk"
  end

  return "item"
end

local function player_move_speed()
  if you.transform() == "tree" then
    return 0
  end

  -- This is a basic approximation
  local base_speed = 10
  local move_speed = base_speed
  local in_water_flag = in_water()

  if in_water_flag then move_speed = move_speed + 3 end

  local speed_mut = you.mutation("speed")
  local slow_mut = you.mutation("slowness")
  if speed_mut > 0 then
    move_speed = move_speed - speed_mut - 1
  elseif slow_mut > 0 then
    move_speed = math.floor(move_speed * (10 + slow_mut * 2) / 10)
  end

  if not in_water_flag and you.status("sluggish") then
    if move_speed >= 8 then
      move_speed = math.floor(move_speed * 3 / 2)
    elseif move_speed == 7 then
      move_speed = math.floor(7 * 6 / 5)
    end
  elseif not in_water_flag and you.status("swift") then
    move_speed = math.floor(move_speed * 3 / 4)
  end

  if move_speed < 6 then
    move_speed = 6
  end

  return math.floor(base_speed * move_speed / 10)
end

-- Finding safe direction to move or swing
local function is_safe_direction(x, y)
  if x == nil or y == nil or x == 0 and y == 0 then return false end
  if get_rest_type() == "walk" then
    local pos_is_water = view.feature_at(x, y):find("water")
    return in_water() == pos_is_water and view.is_safe_square(x, y)
  else
    return not monster.get_monster_at(x, y) and feat_is_open(view.feature_at(x, y))
  end
end

local function get_safe_direction()
  for x = -1, 1 do
    for y = -1, 1 do
      if is_safe_direction(x, y) then return x, y end
    end
  end
  return nil
end

local function set_safe_direction()
  if get_rest_type() == "walk" or not is_safe_direction(dir.x, dir.y) then
    dir.x, dir.y = get_safe_direction()
    if not dir.x then
      reset_rest("No safe direction found!")
      return false
    end
  end

  return true
end

-- Resting
local function okay_to_rest()
  local hp, mhp = you.hp()
  if hp == mhp then
    reset_rest("You are already at full health!")
  elseif turns_remaining <= 0 then
    reset_rest()
  elseif not you.feel_safe() then
    reset_rest("You can't rest with a hostile monster in view!")
  elseif you.status("manticore barbs") then
    reset_rest("You must remove the manticore barbs first.")
  elseif get_rest_type() == "walk" and player_move_speed() <= 10 then
    reset_rest("You cannot walk slowly right now!")
  else
    return true
  end
end

local function do_resting()
  if not set_safe_direction() then return end

  local rest_type = get_rest_type()
  if rest_type == "item" then
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

    if Config.walk_delay > 0 then crawl.delay(Config.walk_delay) end
  end

  turns_remaining = turns_remaining - 1
  if turns_remaining <= 0 then reset_rest() end
end

local function get_num_turns()
  BRC.mpr.info("Enter number of turns to rest: ")
  local input = crawl.c_input_line()
  local turns = tonumber(input)
  if not turns or turns < 0 then
    BRC.mpr.warning("Must be a number!")
    return 0
  end
  return turns
end

---- Public API ----
function macro_brc_bread_swing(turns)
  turns_remaining = turns or get_num_turns()
  bs_swing_slot = get_slowest_slot()
  f_bread_swinger.ready()
end

function f_bread_swinger.set_swing_slot()
  BRC.mpr.info("Enter an slot letter for the swing item: ")
  local letter = crawl.c_input_line()
  local index = items.letter_to_index(letter)
  if not index or index < 0 then
    BRC.mpr.error("Must be a letter (a-z or A-Z)!")
    return
  end
  bs_swing_slot = letter
  BRC.mpr.info("Set swing slot to " .. letter .. ".")
end

---- Initialization ----
function f_bread_swinger.init()
  Config = f_bread_swinger.Config
  reset_rest()
  BRC.opt.macro("5", "macro_brc_bread_swing")
end

---- Crawl hook functions ----
function f_bread_swinger.c_message(text, _)
  if 1 == 1 then return end
  if turns_remaining <= 0 then return end

  -- Stop on any unrecognized message
  local swing_pt = "^ *You swing at nothing%. *$"
  local pattern = wielding and "^ *" .. bs_swing_slot .. " - .+[%)}] *$" or swing_pt
  if get_rest_type() == "walk" or not text:find(pattern) then
    reset_rest()
  end
end

function f_bread_swinger.ready()
  if not turns_remaining or turns_remaining <= 0 then return end
  if not okay_to_rest() then
    reset_rest("You can't rest here.")
  end

  if wielding and not swing_item_wielded() then
    -- An error happened with the 'w' command
    reset_rest("Unable to wield swing item on slot " .. bs_swing_slot .. "!")
    return
  end

  if get_rest_type() == "item" and not swing_item_wielded() then
    wield_swing_item()
  else
    do_resting()
  end
end



-- -- TODO: ignore in c_message
-- local function get_last_message()
--   local rest_type = get_rest_type()
--   local in_water_flag = in_water()
--   -- Ignore these movement messages when walking
--   local move_patterns = {"There is a[^%.]+here%.", "Things that are here:.*", "Items here:.*"}

--   for i = 1, 200 do
--     local msg = crawl_message(i)
--     for s, _ in pairs(start_status) do
--       local patterns = Config.status_messages[s]
--       if type(patterns) == "table" then
--         for _, p in ipairs(patterns) do
--           msg = msg:gsub(p, "")
--         end
--       else
--         msg = msg:gsub(patterns, "")
--       end
--     end

--     if rest_type == "walk" then
--       for _, p in ipairs(move_patterns) do
--         msg = msg:gsub(" *" .. p .. " *", "")
--       end
--     end

--     msg = msg:gsub(" *Beep! [^%.]+%. *", "")

--     for _, p in ipairs(Config.ignore_messages) do
--       msg = msg:gsub(p, "")
--     end

--     if msg ~= "" then
--       return msg
--     end
--   end

--   return nil
-- end
