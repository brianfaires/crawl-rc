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
-- last_thrown/last_queued state is on module fields (not local) for test observability
local M = f_quiver_reminders
local C -- config alias

---- Initialization ----
function f_quiver_reminders.init()
  C = f_quiver_reminders.Config
  M.last_thrown = nil
  M.last_thrown_turn = -1
  M.last_queued = nil
  M.last_queued_turn = -1
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

  local lt = M.last_thrown
  local ltt = M.last_thrown_turn
  if lt and (you.turns() - ltt <= C.warn_diff_missile_turns) then
    local eq_name = items.equipped_at("Weapon") and items.equipped_at("Weapon").name("qual") or nil
    local quiv_name = parse_name_from_item(quivered)
    if quiv_name ~= M.last_thrown and quiv_name ~= eq_name then
      local q = BRC.txt.lightgreen(quiv_name)
      if not BRC.mpr.yesno("Did you mean to throw " .. q .. "?") then
        local t = BRC.txt.lightgreen(M.last_thrown)
        if BRC.mpr.yesno("Quiver and throw " .. t .. " instead?") then
          quiver_missile_by_name(M.last_thrown)
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
    M.last_queued_turn = you.turns()
    -- Missile name is shown in message like: "Throw: 23 darts (curare)". Strip prefix.
    M.last_queued = cleaned:sub(8, #cleaned)

    -- Remove quantity and pluralization
    M.last_queued = M.last_queued:gsub("^%d+ ", "")
    if M.last_queued:sub(-1) == "s" then
      M.last_queued = M.last_queued:sub(1, -2)
    else
      M.last_queued = M.last_queued:gsub("s %(", " (")
    end
  elseif cleaned:sub(1, 10) == "You throw " then
    local lqt = M.last_queued_turn
    if you.turns() ~= lqt then
      BRC.mpr.error("quiver-remind turn changed: " .. lqt .. " -> " .. you.turns())
    end
    M.last_thrown = M.last_queued
    M.last_thrown_turn = M.last_queued_turn
  end
end
