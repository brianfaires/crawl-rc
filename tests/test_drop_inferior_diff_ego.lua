---------------------------------------------------------------------------------------------------
-- BRC feature test: drop-inferior (different non-risky ego guard)
-- Verifies that c_assign_invletter does NOT mark an inventory weapon when it has a different
-- non-risky ego from the floor weapon, even when the floor weapon is otherwise strictly better.
--
-- The not_worse guard in c_assign_invletter:
--   local not_worse = inv_ego == it_ego or not inv_ego or BRC.eq.is_risky(inv)
--
-- BRC.eq.get_ego() lowercases the DCSS ego string.  DCSS reports:
--   ego:freezing  ->  "freeze"
--   ego:flaming   ->  "flame"
-- Neither is in BRC.RISKY_EGOS, so is_risky() returns false for both.
--
-- When the floor item (it) has ego "flame" and an inventory item (inv) has ego "freeze":
--   inv_ego == it_ego  ->  "freeze" == "flame"  ->  false
--   not inv_ego        ->  not "freeze"          ->  false
--   BRC.eq.is_risky(inv) -> false
--   => not_worse = false  =>  inscribe_drop is NOT called for the freezing mace
--
-- The starting +0 plain mace (no ego) IS still marked as a positive control:
--   not inv_ego (nil) = true  =>  not_worse = true,  AND  inv.plus (0) <= it.plus (5)
--
-- Phase flow:
--   "give"   (turn 0): wizard_give("mace ego:freezing") + identify -> CMD_WAIT
--   "pickup" (turn 1): CMD_PICKUP (single floor item, no menu) -> freezing mace enters inv
--   "give2"  (turn 2): wizard_give("mace ego:flaming plus:5") + identify -> CMD_WAIT
--   "verify" (turn 3): clear any prior DROP_ME; call c_assign_invletter(floor flaming mace);
--                      assert freezing mace NOT marked; assert plain +0 mace IS marked
--
-- When CMD_PICKUP fires c_assign_invletter for the freezing mace, the hook marks the plain
-- starting mace (not inv_ego => true, 0 <= 0).  We clear that before the main assertion.
---------------------------------------------------------------------------------------------------

test_drop_inferior_diff_ego = {}
test_drop_inferior_diff_ego.BRC_FEATURE_NAME = "test-drop-inferior-diff-ego"

local _phase = "give"
local DROP_KEY = "~~DROP_ME"

function test_drop_inferior_diff_ego.ready()
  if T._done then return end

  T.run("drop-inferior-diff-ego", function()

    if _phase == "give" then
      -- Place a freezing mace on the floor and identify it.
      T.wizard_give("mace ego:freezing")
      T.wizard_identify_all()
      _phase = "pickup"
      crawl.do_commands({"CMD_WAIT"})  -- advance to turn 1

    elseif _phase == "pickup" then
      -- Pick up the single floor item (freezing mace); no menu since only one item.
      -- c_assign_invletter fires here and will mark the starting plain mace; expected.
      crawl.do_commands({"CMD_PICKUP"})
      _phase = "give2"

    elseif _phase == "give2" then
      -- Place a +5 flaming mace on the floor and identify it.
      T.wizard_give("mace ego:flaming plus:5")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})  -- advance to next turn

    elseif _phase == "verify" then
      -- ── Locate the +5 flaming mace on the floor ──────────────────────────────────────────────
      local flaming_mace = nil
      for _, it in ipairs(you.floor_items()) do
        -- BRC.eq.get_ego() lowercases; DCSS reports "flame" for ego:flaming
        if it.is_weapon and it.subtype() == "mace"
            and BRC.eq.get_ego(it) == "flame" then
          flaming_mace = it
          break
        end
      end

      T.true_(flaming_mace ~= nil, "flaming-mace-on-floor")
      if not flaming_mace then T.done() return end

      crawl.stderr("floor flaming mace: " .. flaming_mace.name()
        .. " ego=" .. tostring(BRC.eq.get_ego(flaming_mace))
        .. " plus=" .. tostring(flaming_mace.plus)
        .. " risky=" .. tostring(BRC.eq.is_risky(flaming_mace)))

      -- ── Locate the freezing mace in inventory (picked up in "pickup" phase) ─────────────────
      local function find_freezing_mace()
        for _, it in ipairs(items.inventory()) do
          -- BRC.eq.get_ego() lowercases; DCSS reports "freeze" for ego:freezing
          if it.is_weapon and it.subtype() == "mace"
              and BRC.eq.get_ego(it) == "freeze" then
            return it
          end
        end
        return nil
      end

      -- ── Locate the plain +0 starting mace in inventory ───────────────────────────────────────
      local function find_plain_mace()
        for _, it in ipairs(items.inventory()) do
          if it.is_weapon and it.subtype() == "mace"
              and BRC.eq.get_ego(it) == nil then
            return it
          end
        end
        return nil
      end

      local freezing_mace = find_freezing_mace()
      T.true_(freezing_mace ~= nil, "freezing-mace-in-inventory")
      if not freezing_mace then T.done() return end

      local plain_mace = find_plain_mace()
      T.true_(plain_mace ~= nil, "plain-mace-in-inventory")
      if not plain_mace then T.done() return end

      crawl.stderr("freezing mace ego=" .. tostring(BRC.eq.get_ego(freezing_mace))
        .. " risky=" .. tostring(BRC.eq.is_risky(freezing_mace))
        .. " inscr=[" .. tostring(freezing_mace.inscription) .. "]")
      crawl.stderr("plain mace ego=" .. tostring(BRC.eq.get_ego(plain_mace))
        .. " inscr=[" .. tostring(plain_mace.inscription) .. "]")

      -- Clear any DROP_ME left from the "pickup" phase (the hook marked plain mace then).
      local function clear_drop_key(it)
        local cur = tostring(it.inscription)
        if cur:find(DROP_KEY, 1, true) then
          it.inscribe(cur:gsub(DROP_KEY, ""), false)
        end
      end
      clear_drop_key(freezing_mace)
      clear_drop_key(plain_mace)

      -- ── Call the hook directly with the floor flaming mace as the newly-picked-up item ───────
      f_drop_inferior.c_assign_invletter(flaming_mace)

      -- Re-fetch both inventory items after the hook may have mutated inscriptions.
      freezing_mace = find_freezing_mace()
      plain_mace    = find_plain_mace()

      crawl.stderr("after hook — freezing: ["
        .. tostring(freezing_mace and freezing_mace.inscription or "nil") .. "]  plain: ["
        .. tostring(plain_mace and plain_mace.inscription or "nil") .. "]")

      -- ── KEY ASSERTION: freezing mace must NOT be marked (different non-risky ego) ─────────────
      T.true_(freezing_mace ~= nil, "freezing-mace-still-in-inventory")
      if freezing_mace then
        T.false_(
          string.find(tostring(freezing_mace.inscription), DROP_KEY, 1, true) ~= nil,
          "freezing-mace-not-marked-different-ego"
        )
      end

      -- ── POSITIVE CONTROL: plain +0 mace must be marked (no ego => not_worse = true) ─────────
      T.true_(plain_mace ~= nil, "plain-mace-still-in-inventory")
      if plain_mace then
        T.true_(
          string.find(tostring(plain_mace.inscription), DROP_KEY, 1, true) ~= nil,
          "plain-mace-marked-as-positive-control"
        )
      end

      T.pass("drop-inferior-diff-ego")
      T.done()
    end
  end)
end
