---------------------------------------------------------------------------------------------------
-- BRC feature module: quiver-reminders
-- @module f_quiver_reminders
-- A handful of useful quiver-related reminders. (AKA things I often screw up.)
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

---- Initialization ----
function f_quiver_reminders.init()
  C = f_quiver_reminders.Config
  last_thrown = nil
  last_thrown_turn = -1

  BRC.opt.macro(BRC.util.get_cmd_key("CMD_FIRE") or "f", "macro_brc_fire")
end

---- Local functions ----
local function quiver_missile_by_name(name)
  local slot = nil
  for _, inv in ipairs(items.inventory()) do
    if inv.name("qual") == name then
      slot = inv.slot
      break
    end
  end

  if not slot then return end
  crawl.sendkeys(BRC.util.get_cmd_key("CMD_QUIVER_ITEM") .. "*(" .. BRC.txt.int2char(slot))
  crawl.flush_input()
end

---- Macro function: Fire from quiver ----
function macro_brc_fire()
  if not BRC.active or C.disabled then return BRC.util.do_cmd("CMD_FIRE") end
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

  if you.turns() - last_thrown_turn <= C.warn_diff_missile_turns then
    if last_thrown ~= quivered.name("qual") then
      local q = BRC.txt.lightgreen(quivered.name("qual"))
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
  local prefix = "You throw a "
  if cleaned:sub(1, #prefix) == prefix then
    last_thrown = cleaned:sub(#prefix + 1, #cleaned - 1):gsub(" {.*}", "")
    last_thrown_turn = you.turns()
  end
end
