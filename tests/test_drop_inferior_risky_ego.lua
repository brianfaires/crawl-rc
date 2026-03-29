---------------------------------------------------------------------------------------------------
-- BRC feature test: drop-inferior (risky ego guard)
-- Verifies that f_drop_inferior.c_assign_invletter does NOT mark the starting "+0 mace" with
-- "~~DROP_ME" when the floor item has a risky ego (chaos), but DOES mark it for a plain +5 mace.
--
-- The guard in c_assign_invletter:
--   if not (it.is_weapon or BRC.it.is_armour(it))
--     or BRC.eq.is_risky(it)          <-- floor item is risky: return early, no marking
--     or BRC.you.num_eq_slots(it) > 1
--   then return end
--
-- BRC.RISKY_EGOS = { "antimagic", "chaos", "distort", "harm", "heavy", "Infuse", "Ponderous" }
-- "chaos" is in RISKY_EGOS, so a mace of chaos should trigger the guard and leave the
-- starting mace uninscribed.
--
-- Phase flow:
--   "give"   (turn 0): wizard_give both weapons + identify -> CMD_WAIT to turn 1
--   "verify" (turn 1): find both on floor; run risky test first (no mark expected),
--                      then positive test (mark expected after clearing any prior inscription)
---------------------------------------------------------------------------------------------------

test_drop_inferior_risky_ego = {}
test_drop_inferior_risky_ego.BRC_FEATURE_NAME = "test-drop-inferior-risky-ego"

local _phase = "give"

function test_drop_inferior_risky_ego.ready()
  if T._done then return end

  T.run("drop-inferior-risky-ego", function()
    if _phase == "give" then
      -- Place a chaos mace (+5, risky ego) and a plain +5 mace on the floor, then identify.
      T.wizard_give("mace ego:chaos plus:5")
      T.wizard_give("mace plus:5")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1; returns synchronously

    elseif _phase == "verify" then
      -- ── Find floor items ──────────────────────────────────────────────────────────────────────
      local chaos_mace = nil
      local plain_mace = nil
      for _, it in ipairs(you.floor_items()) do
        if it.is_weapon and it.subtype() == "mace" then
          local ego = BRC.eq.get_ego(it)
          crawl.stderr("floor item: " .. it.name() .. " ego=" .. tostring(ego)
            .. " plus=" .. tostring(it.plus) .. " risky=" .. tostring(BRC.eq.is_risky(it)))
          if BRC.eq.is_risky(it) and chaos_mace == nil then
            chaos_mace = it
          elseif not BRC.eq.is_risky(it) and (it.plus or 0) >= 5 and plain_mace == nil then
            plain_mace = it
          end
        end
      end

      T.true_(chaos_mace ~= nil, "chaos-mace-on-floor")
      T.true_(plain_mace ~= nil, "plain-mace-on-floor")
      if not chaos_mace or not plain_mace then T.done() return end

      -- ── Find the starting mace in inventory ───────────────────────────────────────────────────
      -- The Mummy Berserker starts with a +0 mace; it has plus < 5 and no risky ego.
      local function find_starting_mace()
        for _, inv in ipairs(items.inventory()) do
          if inv.is_weapon and inv.subtype() == "mace" and (inv.plus or 0) < 5 then
            return inv
          end
        end
        return nil
      end

      local starting_mace = find_starting_mace()
      T.true_(starting_mace ~= nil, "starting-mace-in-inventory")
      if not starting_mace then T.done() return end

      -- ── RISKY TEST: chaos mace should NOT mark the starting mace ─────────────────────────────
      -- Clear any pre-existing DROP_ME inscription so the test is clean.
      local DROP_KEY = "~~DROP_ME"
      local inscr_before = tostring(starting_mace.inscription)
      if inscr_before:find(DROP_KEY, 1, true) then
        starting_mace.inscribe(inscr_before:gsub(DROP_KEY, ""), false)
      end

      crawl.stderr("risky test — starting mace before: [" .. tostring(starting_mace.inscription) .. "]")
      f_drop_inferior.c_assign_invletter(chaos_mace)
      crawl.stderr("risky test — starting mace after:  [" .. tostring(starting_mace.inscription) .. "]")

      -- Re-fetch in case Lua item handle was refreshed
      starting_mace = find_starting_mace()
      T.true_(starting_mace ~= nil, "starting-mace-still-in-inventory-after-risky")
      if starting_mace then
        local inscr_risky = tostring(starting_mace.inscription)
        T.false_(
          string.find(inscr_risky, DROP_KEY, 1, true) ~= nil,
          "risky-chaos-mace-does-not-mark-starting-mace"
        )
      end

      -- ── POSITIVE TEST: plain +5 mace SHOULD mark the starting mace ───────────────────────────
      -- Clear any inscription left from the risky call (should be none, but be safe).
      starting_mace = find_starting_mace()
      if starting_mace then
        local inscr_cur = tostring(starting_mace.inscription)
        if inscr_cur:find(DROP_KEY, 1, true) then
          starting_mace.inscribe(inscr_cur:gsub(DROP_KEY, ""), false)
        end
      end

      crawl.stderr("positive test — starting mace before: [" .. tostring(starting_mace and starting_mace.inscription or "nil") .. "]")
      f_drop_inferior.c_assign_invletter(plain_mace)

      starting_mace = find_starting_mace()
      T.true_(starting_mace ~= nil, "starting-mace-still-in-inventory-after-plain")
      if starting_mace then
        local inscr_after = tostring(starting_mace.inscription)
        crawl.stderr("positive test — starting mace after: [" .. inscr_after .. "]")
        T.true_(
          string.find(inscr_after, DROP_KEY, 1, true) ~= nil,
          "plain-plus5-mace-marks-starting-mace-for-drop"
        )
      end

      T.pass("drop-inferior-risky-ego")
      T.done()
    end
  end)
end
