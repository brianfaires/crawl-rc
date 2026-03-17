-- @species Fo
-- @background Fi
-- @weapon waraxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Formicid BRC.eq.get_hands logic)
-- Verifies BRC.eq.get_hands(it) returns correct hand count for Formicid (equipment.lua).
--
-- Formicid logic in get_hands:
--   - "giant club" / "giant spiked club" -> 2  (stays 2-handed even for Formicid)
--   - all other weapons                  -> 1  (Formicid one-hands them)
--
-- Assertions:
--   1. you.race() == "Formicid"                          (sanity check)
--   2. get_hands(giant club)  == 2                       (Formicid exception: stays 2h)
--   3. get_hands(war axe)     == 1                       (normally 2h, but Formicid one-hands it)
--   4. get_hands(hand axe)    == 1                       (normally 1h, stays 1h for Formicid)
--
-- Note: Formicid Fighter may autopickup the war axe and hand axe into inventory.
-- Search both floor_items() and inventory() for each weapon type.
--
-- Phase flow:
--   "give"   (turn 0): wizard-give giant club + war axe + hand axe, identify, CMD_WAIT -> turn 1
--   "verify" (turn 1): find items on floor or in inventory, assert get_hands, T.pass, T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_formicid_get_hands = {}
test_pickup_alert_formicid_get_hands.BRC_FEATURE_NAME = "test-pickup-alert-formicid-get-hands"

local _phase = "give"

function test_pickup_alert_formicid_get_hands.ready()
  if T._done then return end

  T.run("pickup-alert-formicid-get-hands", function()

    if _phase == "give" then
      T.wizard_give("giant club")
      T.wizard_give("war axe")
      T.wizard_give("hand axe")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      -- Sanity: confirm we are playing a Formicid
      T.eq(you.race(), "Formicid", "char-is-formicid")

      -- Helper: search floor items and inventory for a name pattern; return first match.
      local function find_item(pattern)
        for _, it in ipairs(you.floor_items()) do
          if it.name():find(pattern) then return it end
        end
        for _, it in ipairs(items.inventory()) do
          if it.name():find(pattern) then return it end
        end
        return nil
      end

      local giant_club = find_item("giant club")
      local war_axe    = find_item("war axe")
      local hand_axe   = find_item("hand axe")

      T.true_(giant_club ~= nil, "giant-club-found")
      T.true_(war_axe    ~= nil, "war-axe-found")
      T.true_(hand_axe   ~= nil, "hand-axe-found")

      if not giant_club or not war_axe or not hand_axe then T.done() return end

      -- Giant club: Formicid exception — stays 2-handed
      T.eq(BRC.eq.get_hands(giant_club), 2, "formicid-giant-club-is-2h")

      -- War axe: normally 2-handed, but Formicid one-hands it
      T.eq(BRC.eq.get_hands(war_axe), 1, "formicid-war-axe-is-1h")

      -- Hand axe: normally 1-handed, stays 1-handed for Formicid
      T.eq(BRC.eq.get_hands(hand_axe), 1, "formicid-hand-axe-is-1h")

      T.pass("pickup-alert-formicid-get-hands")
      T.done()
    end
  end)
end
