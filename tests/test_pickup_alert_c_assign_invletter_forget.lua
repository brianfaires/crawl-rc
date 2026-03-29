-- @species Co
-- @background Fi
-- @weapon flail
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (c_assign_invletter forgets multi-slot item alert)
-- Verifies the branch in pa-main.lua:297:
--   if BRC.you.num_eq_slots(it) > 1 then f_pa_data.forget_alert(it) end
--
-- Character: Coglin Fighter (dual-wield species) — weapons return num_eq_slots=2.
-- A helmet returns num_eq_slots=1 for Coglin (non-aux-armour, non-weapon path).
--
-- c_assign_invletter() is the Crawl hook called when an item is assigned an inventory letter
-- (i.e., when it's picked up). After calling it:
--   - For a weapon (num_eq_slots=2): forget_alert fires -> already_alerted returns nil
--   - For a helmet (num_eq_slots=1): forget_alert does NOT fire -> still alerted
--
-- Phase flow:
--   "give"   (turn 0): wizard-give hand axe + helmet, identify, CMD_WAIT -> turn 1
--   "check"  (turn 1): find items on floor; call remember_alert, verify alerted,
--                       then call c_assign_invletter, verify forget/keep behaviour;
--                       T.pass + T.done()
---------------------------------------------------------------------------------------------------

test_pickup_alert_c_assign_invletter_forget = {}
test_pickup_alert_c_assign_invletter_forget.BRC_FEATURE_NAME = "test-pickup-alert-c-assign-invletter-forget"

local _phase = "give"

function test_pickup_alert_c_assign_invletter_forget.ready()
  if T._done then return end

  T.run("pickup-alert-c-assign-invletter-forget", function()

    -- ── Phase 1: place a weapon and a helmet on the floor ───────────────────────────────────
    if _phase == "give" then
      T.wizard_give("hand axe")
      T.wizard_give("helmet")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    -- ── Phase 2: test c_assign_invletter behaviour ──────────────────────────────────────────
    elseif _phase == "check" then
      T.eq(you.race(), "Coglin", "char-is-coglin")

      -- Find the hand axe and helmet on the floor
      local floor_axe    = nil
      local floor_helmet = nil
      for _, it in ipairs(you.floor_items()) do
        local n = it.name()
        if n:find("hand axe") and not floor_axe then
          floor_axe = it
        elseif n:find("helmet") and not floor_helmet then
          floor_helmet = it
        end
      end

      T.true_(floor_axe    ~= nil, "hand-axe-on-floor")
      T.true_(floor_helmet ~= nil, "helmet-on-floor")
      if not floor_axe or not floor_helmet then T.done() return end

      -- Confirm slot counts
      T.eq(BRC.you.num_eq_slots(floor_axe),    2, "axe-has-2-slots")
      T.eq(BRC.you.num_eq_slots(floor_helmet),  1, "helmet-has-1-slot")

      -- ── Weapon (2-slot): alert should be FORGOTTEN after c_assign_invletter ──
      f_pa_data.forget_alert(floor_axe)          -- clean slate
      f_pa_data.remember_alert(floor_axe)        -- mark as alerted
      T.true_(f_pa_data.already_alerted(floor_axe) ~= nil, "axe-alerted-before-assign")

      f_pickup_alert.c_assign_invletter(floor_axe)

      -- num_eq_slots=2 > 1  =>  forget_alert fires  =>  already_alerted returns nil
      T.true_(f_pa_data.already_alerted(floor_axe) == nil, "axe-alert-forgotten-after-assign")

      -- ── Helmet (1-slot): alert should be KEPT after c_assign_invletter ───────
      f_pa_data.forget_alert(floor_helmet)       -- clean slate
      f_pa_data.remember_alert(floor_helmet)     -- mark as alerted
      T.true_(f_pa_data.already_alerted(floor_helmet) ~= nil, "helmet-alerted-before-assign")

      f_pickup_alert.c_assign_invletter(floor_helmet)

      -- num_eq_slots=1, NOT > 1  =>  forget_alert does NOT fire  =>  still alerted
      T.true_(f_pa_data.already_alerted(floor_helmet) ~= nil, "helmet-alert-kept-after-assign")

      T.pass("pickup-alert-c-assign-invletter-forget")
      T.done()
    end
  end)
end
