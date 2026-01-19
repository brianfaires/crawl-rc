---------------------------------------------------------------------------------------------------
-- BRC feature module: quiver-reminders
-- @module f_quiver_reminders
-- A handful of useful quiver-related reminders. (AKA things I often forget.)
---------------------------------------------------------------------------------------------------

f_quiver_reminders = {}
f_quiver_reminders.BRC_FEATURE_NAME = "quiver-reminders"
f_quiver_reminders.Config = {
  confirm_consumables = true,
  warn_diff_missile_turns = 10,
} -- f_quiver_reminders.Config (do not remove this comment)

---- Local variables ----
local C -- config alias
local last_thrown
local last_thrown_turn
local last_queued
local last_queued_turn

---- Initialization ----
function f_quiver_reminders.init()
  C = f_quiver_reminders.Config
  last_thrown = nil
  last_thrown_turn = -1
  last_queued = nil
  last_queued_turn = -1
  BRC.opt.macro(BRC.util.get_cmd_key("CMD_FIRE") or "f", "macro_brc_fire")
end

---- Local functions ----
--- Generate a string that matches the "Throw: <qty> <name> (<ego>)" format
local function parse_name_from_item(it)
  local ego = it.ego()
  if not ego then return it.name("db") end
  return it.name("db") .. " (" .. ego .. ")"
end


local function quiver_missile_by_name(name)
  local slot = nil
  for _, inv in ipairs(items.inventory()) do
    if parse_name_from_item(inv) == name then
      slot = inv.slot
      break
    end
  end

  if not slot then
    BRC.mpr.error("Not found in inventory: " .. name)
    return
  end
  crawl.sendkeys(BRC.util.get_cmd_key("CMD_QUIVER_ITEM") .. "*(" .. BRC.txt.int2char(slot))
  crawl.flush_input()
end

---- Macro function: Fire from quiver ----
function macro_brc_fire()
  if BRC.active == false or f_quiver_reminders.Config.disabled then
    return BRC.util.do_cmd("CMD_FIRE")
  end

  local quivered = items.fired_item()
  if not quivered then return end

  if C.confirm_consumables then
    local cls = quivered.class(true)
    if cls == "potion" or cls == "scroll" then
      local action = cls == "potion" and "drink" or "read"
      local q = BRC.txt.lightgreen(quivered.name())
      local msg = string.format("Really %s %s from quiver?", action, q)
      if not BRC.mpr.yesno(msg) then return BRC.mpr.okay() end
    end
  end

  if last_thrown and (you.turns() - last_thrown_turn <= C.warn_diff_missile_turns) then
    local eq_name = items.equipped_at("Weapon") and items.equipped_at("Weapon").name("qual") or nil
    local quiv_name = parse_name_from_item(quivered)
    if quiv_name ~= last_thrown and quiv_name ~= eq_name then
      local q = BRC.txt.lightgreen(quiv_name)
      if not BRC.mpr.yesno("Did you mean to throw " .. q .. "?") then
        local t = BRC.txt.lightgreen(last_thrown)
        if BRC.mpr.yesno("Quiver and throw " .. t .. " instead?") then
          quiver_missile_by_name(last_thrown)
        else
          return BRC.mpr.okay()
        end
      end
    end
  end

  BRC.util.do_cmd("CMD_FIRE")
end

---- Crawl hook functions ----
function f_quiver_reminders.c_message(text, _)
  local cleaned = BRC.txt.clean(text)
  if cleaned:sub(1, 7) == "Throw: " then
    last_queued_turn = you.turns()
    -- Missile name is shown in message like: "Throw: 23 darts (curare)". Strip prefix.
    last_queued = cleaned:sub(8, #cleaned)

    -- Remove quantity and pluralization
    last_queued = last_queued:gsub("^%d+ ", "")
    if last_queued:sub(-1) == "s" then
      last_queued = last_queued:sub(1, -2)
    else
      last_queued = last_queued:gsub("s %(", " (")
    end
  elseif cleaned:sub(1, 10) == "You throw " then
    if you.turns() ~= last_queued_turn then
      BRC.mpr.error("quiver-remind turn changed: " .. last_queued_turn .. " -> " .. you.turns())
    end
    last_thrown = last_queued
    last_thrown_turn = last_queued_turn
  end
end
