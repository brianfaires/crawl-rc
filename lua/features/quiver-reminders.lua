--[[
Feature: quiver-reminders
Description: A handful of useful quiver-related reminders
Author: buehler
Dependencies: core/data.lua, core/util.lua
--]]

f_quiver_reminders = {}
f_quiver_reminders.BRC_FEATURE_NAME = "quiver-reminders"
f_quiver_reminders.Config = {
  confirm_consumables = true,
  warn_diff_missile_turns = 10,

} -- f_quiver_reminders.Config (do not remove this comment)

---- Persistent variables ----

---- Local variables ----
local last_thrown = nil
local last_thrown_turn = 0

---- Local config alias ----
local Config = f_quiver_reminders.Config

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
  crawl.process_keys(BRC.get.command_key("CMD_QUIVER_ITEM") .. "*(" .. BRC.util.int2char(slot))
end

---- Macro function ----
function macro_f_quiver_reminders_fire()
  if not BRC.active or Config.disabled then return BRC.util.do_cmd("CMD_FIRE") end
  local quivered = items.fired_item()
  if not quivered then return end

  if Config.confirm_consumables then
    local cls = quivered.class(true)
    if cls == "potion" or cls == "scroll" then
      local action = cls == "potion" and "drink" or "read"
      local msg = "Really %s %s from quiver?"
      msg = msg:format(action, BRC.text.lightgreen(quivered.name()))
      if not BRC.mpr.yesno(msg) then return BRC.mpr.okay() end
    end
  end

  if you.turns() - last_thrown_turn <= Config.warn_diff_missile_turns then
    if last_thrown ~= quivered.name("qual") then
      local msg = "Did you mean to throw " .. BRC.text.lightgreen(quivered.name("qual")) .. "?"
      if not BRC.mpr.yesno(msg) then
        if BRC.mpr.yesno("Quiver and throw " .. BRC.text.lightgreen(last_thrown) .. " instead?") then
          quiver_missile_by_name(last_thrown)
        else
          return BRC.mpr.okay()
        end
      end
    end
  end

  BRC.util.do_cmd("CMD_FIRE")
end

---- Hook functions ----
function f_quiver_reminders.init()
  BRC.set.macro(BRC.get.command_key("CMD_FIRE") or "f", "macro_f_quiver_reminders_fire")
end

function f_quiver_reminders.c_message(text, _)
  local cleaned = BRC.text.clean(text)
  local prefix = "You throw a "
  if cleaned:sub(1, #prefix) == prefix then
    last_thrown = cleaned:sub(#prefix + 1, #cleaned-1):gsub(" {.*}", "")
    last_thrown_turn = you.turns()
  end
end
