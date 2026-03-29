-- @species Fo
-- @background Fi
-- @weapon waraxe
---------------------------------------------------------------------------------------------------
-- BRC feature test: pickup-alert (Formicid 2 glove equipment slots)
-- Verifies BRC.you.num_eq_slots() returns 2 for gloves for Formicid (you.lua:92 branch).
-- Formicid has 4 arms, so gloves occupy 2 aux slots.
-- Other item types (helmet, weapon) still return 1 for Formicid.
--
-- Note: Formicid Fighter's autopickup does NOT consume wizard-given gloves and helmet;
-- they remain on the floor. Search uses name-based matching (it.is_armour is nil for
-- floor items from you.floor_items()).
--
-- Phase flow:
--   "give"   (turn 0): wizard-give gloves + helmet, identify, CMD_WAIT → turn 1
--   "verify" (turn 1): find items on floor, assert num_eq_slots, T.pass, T.done
---------------------------------------------------------------------------------------------------

test_pickup_alert_formicid_gloves = {}
test_pickup_alert_formicid_gloves.BRC_FEATURE_NAME = "test-pickup-alert-formicid-gloves"

local _phase = "give"

function test_pickup_alert_formicid_gloves.ready()
  if T._done then return end

  T.run("pickup-alert-formicid-gloves", function()

    if _phase == "give" then
      T.wizard_give("pair of gloves")
      T.wizard_give("helmet")
      T.wizard_identify_all()
      _phase = "verify"
      crawl.do_commands({"CMD_WAIT"})

    elseif _phase == "verify" then
      T.eq(you.race(), "Formicid", "char-is-formicid")

      -- Formicid Fighter autopickup leaves items on the floor (not auto-equipped).
      -- Search floor items by name; is_armour is nil for floor items so skip that guard.
      local floor_gloves = nil
      local floor_helmet = nil
      for _, it in ipairs(you.floor_items()) do
        local n = it.name()
        if n:find("gloves") and not floor_gloves then
          floor_gloves = it
        elseif n:find("helmet") and not floor_helmet then
          floor_helmet = it
        end
      end
      T.true_(floor_gloves ~= nil, "gloves-on-floor")
      T.true_(floor_helmet ~= nil, "helmet-on-floor")
      if not floor_gloves or not floor_helmet then T.done() return end

      T.eq(BRC.you.num_eq_slots(floor_gloves), 2, "formicid-glove-slots-2")
      T.eq(BRC.you.num_eq_slots(floor_helmet), 1, "formicid-helmet-slots-1")

      -- Starting waraxe in weapon slot: Formicid has 1 weapon slot (not Coglin)
      local weap = items.equipped_at("weapon")
      if weap then
        T.eq(BRC.you.num_eq_slots(weap), 1, "formicid-weapon-slots-1")
      end

      T.pass("pickup-alert-formicid-gloves")
      T.done()
    end
  end)
end
