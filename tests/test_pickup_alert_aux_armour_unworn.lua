---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert aux armour with unworn_inv_item argument
-- Verifies that alert_aux_armour correctly handles the unworn_inv_item path.
--
-- Character: Mummy Berserker, starts with no cloak equipped (cloak slot empty).
--
-- alert_aux_armour flow (pa-armour.lua lines ~291-316) with unworn_inv_item:
--   it.artefact = false → skip artefact path
--   all_equipped, num_slots = BRC.you.equipped_at(it)   [cloak: 0 equipped, 1 slot]
--   #all_equipped (0) < num_slots (1) → enter the empty-slot branch
--   unworn_inv_item is provided → all_equipped[1] = unworn_inv_item (plain cloak)
--   (does NOT fire "Aux armour" early-exit)
--   compare floor ego cloak against the plain cloak in all_equipped:
--     ego_change = GAIN (floor has ego, plain has none)
--     is_good_ego_change(GAIN, false) = true
--     → fire do_alert(it, "Gain ego", E.EGO, M.aux_armour)
--
-- Both cloaks come from wizard_give so both land on the floor.
-- We pass the plain cloak as the "unworn_inv_item" argument directly,
-- simulating the scenario where the character carries one in inventory.
--
-- BRC.mpr.que_optmore queues messages; consume_queue() fires after all ready() hooks.
-- So "check" phase calls the alert (queues message) + CMD_WAIT, then "verify" checks messages.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give "cloak" (plain) + "cloak ego:fire_resistance"; identify;
--                      CMD_WAIT → turn 1
--   "check"  (turn 1): find both cloaks, call alert_armour(ego_cloak, plain_cloak);
--                      CMD_WAIT → turn 2
--   "verify" (turn 2): assert T.last_messages contains "Gain ego"
---------------------------------------------------------------------------------------------------

test_pickup_alert_aux_armour_unworn = {}
test_pickup_alert_aux_armour_unworn.BRC_FEATURE_NAME = "test-pickup-alert-aux-armour-unworn"

local _phase = "give"
local _plain_cloak = nil
local _ego_cloak   = nil

function test_pickup_alert_aux_armour_unworn.ready()
  if T._done then return end

  T.run("pickup-alert-aux-armour-unworn", function()

    -- ── Phase 1: place two cloaks on the floor ──────────────────────────────────────────────
    if _phase == "give" then
      -- Place a plain cloak first, then an ego cloak.
      -- wizard_give("cloak ego:fire_resistance") creates a cloak of fire resistance.
      T.wizard_give("cloak")
      T.wizard_give("cloak ego:fire_resistance")
      T.wizard_identify_all()
      _phase = "check"
      crawl.do_commands({"CMD_WAIT"})

    -- ── Phase 2: call alert_armour with unworn_inv_item arg ─────────────────────────────────
    elseif _phase == "check" then

      -- Find both cloaks on floor: one plain, one with ego
      for _, it in ipairs(you.floor_items()) do
        if BRC.it.is_armour(it) and not BRC.it.is_body_armour(it) and not BRC.it.is_shield(it)
            and not it.artefact and it.name("base"):find("cloak") then
          local ego = BRC.eq.get_ego(it)
          crawl.stderr("cloak found: name=" .. tostring(it.name()) .. " ego=" .. tostring(ego))
          if ego and not _ego_cloak then
            _ego_cloak = it
          elseif not ego and not _plain_cloak then
            _plain_cloak = it
          end
        end
      end

      T.true_(_plain_cloak ~= nil, "plain-cloak-on-floor")
      T.true_(_ego_cloak   ~= nil, "ego-cloak-on-floor")
      if not _plain_cloak or not _ego_cloak then T.done() return end

      crawl.stderr("plain_cloak: " .. tostring(_plain_cloak.name()))
      crawl.stderr("ego_cloak: "   .. tostring(_ego_cloak.name()))

      -- Suppress force_more for aux_armour and armour_ego paths.
      local M = f_pickup_alert.Config.Alert.More
      local orig_aux_armour = M.aux_armour
      local orig_armour_ego = M.armour_ego
      M.aux_armour = false
      M.armour_ego = false

      -- Forget prior alert records
      f_pa_data.forget_alert(_ego_cloak)
      f_pa_data.forget_alert(_plain_cloak)

      -- Call alert_armour with ego_cloak as the floor item and plain_cloak as the
      -- "unworn inventory item". This exercises the unworn_inv_item path:
      --   all_equipped (empty cloak slot) → add plain_cloak → compare ego vs plain → "Gain ego"
      local result = f_pa_armour.alert_armour(_ego_cloak, _plain_cloak)

      M.aux_armour = orig_aux_armour
      M.armour_ego = orig_armour_ego

      crawl.stderr("alert_armour(ego_cloak, plain_cloak) result: " .. tostring(result))

      T.true_(result ~= nil and result ~= false, "aux-armour-unworn-arg-alert-fires")

      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- consume_queue() fires during BRC.ready() this turn

    -- ── Phase 3: verify message was output ──────────────────────────────────────────────────
    elseif _phase == "verify" then
      -- alert_aux_armour fires "Gain ego" for ego_change == GAIN (floor has ego, plain does not)
      T.true_(T.messages_contain("Gain ego"), "aux-armour-unworn-gain-ego-message")
      T.pass("pickup-alert-aux-armour-unworn")
      T.done()
    end
  end)
end
