local loaded_pa_armour, loaded_pa_misc, loaded_pa_weapons
pause_pa_system = nil

function has_configured_force_more(it)
  if CONFIG.fm_alert.artefact and it.artefact then return true end
  if CONFIG.fm_alert.armour_ego and is_armour(it) and not is_orb(it) and has_ego(it) then return true end
  return false
end

function init_pa_main()
  pause_pa_system = false
  init_pa_data()

  if CONFIG.debug_init then crawl.mpr("Initializing pa-main") end

  loaded_pa_misc = pa_alert_orb and true or false
  if pa_alert_armour then
    loaded_pa_armour = true
    init_pa_armour()
  end
  if pa_alert_weapon then
    loaded_pa_weapons = true
    init_pa_weapons()
  end
  
  if CONFIG.debug_init then
    if loaded_pa_armour then crawl.mpr("pa-armour loaded") end
    if loaded_pa_misc then crawl.mpr("pa-misc loaded") end
    if loaded_pa_weapons then crawl.mpr("pa-weapons loaded") end
  end

  -- Check for duplicate autopickup creation (affects local only)
  create_persistent_data("num_autopickup_funcs", #chk_force_autopickup + 1)
  if num_autopickup_funcs < #chk_force_autopickup then
    crawl.mpr("Warning: Duplicate autopickup funcs loaded. (Commonly from reloading a local game.)")
    crawl.mpr("Expected: " .. num_autopickup_funcs .. " but got: " .. #chk_force_autopickup)
    crawl.mpr("Will skip reloading buehler autopickup. Reload the game to fix crawl's memory usage.")
    return
  end

  ---- Autopickup main ----
  add_autopickup_func(function (it, _)
    if pause_pa_system then return end
    if CACHE.have_orb then return end
    if has_ego(it) and not it.is_identified then return false end
    if not it.is_useless then
      if already_contains(pa_items_picked, it) then return end

      -- Check for pickup
      local retVal = false
      if loaded_pa_armour and CONFIG.pickup.armour and is_armour(it) then
        if pa_pickup_armour(it) then return true end
      elseif loaded_pa_weapons and CONFIG.pickup.weapons and it.is_weapon then
        if pa_pickup_weapon(it) then return true end
      elseif loaded_pa_misc and CONFIG.pickup.staves and is_magic_staff(it) then
        if pa_pickup_staff(it) then return true end
      elseif loaded_pa_misc and is_unneeded_ring(it) then
        return false
      end
    end

    -- Not picking up this item. Now check for alerts.
    -- If useless and aux armour, check if unless carrying one of the same subtype (ie useless from non-innate mutations)
    local do_alerts = not it.is_useless
    local unworn_aux_item = nil
    if not do_alerts then
      local st = it.subtype()
      if not is_armour(it) or is_body_armour(it) or is_shield(it) or is_orb(it) then return end
      for inv in iter.invent_iterator:new(items.inventory()) do
        local inv_st = inv.subtype()
        if inv_st and inv_st == st then
          do_alerts = true
          unworn_aux_item = inv
          break
        end
      end
    end

    if do_alerts then
      if not (CONFIG.alert.system_enabled and you.turn_is_over()) then return end
      if already_contains(pa_items_alerted, it) then return end

      if loaded_pa_misc and CONFIG.alert.one_time and #CONFIG.alert.one_time > 0 then
        if pa_alert_OTA(it) then return end
      end

      if loaded_pa_misc and CONFIG.alert.staff_resists and is_magic_staff(it) then
        if pa_alert_staff(it) then return end
      elseif loaded_pa_misc and CONFIG.alert.orbs and is_orb(it) then
        if pa_alert_orb(it) then return end
      elseif loaded_pa_misc and CONFIG.alert.talismans and is_talisman(it) then
        if pa_alert_talisman(it) then return end
      elseif loaded_pa_armour and CONFIG.alert.armour and is_armour(it) then
        if pa_alert_armour(it, unworn_aux_item) then return end
      else
        if loaded_pa_weapons and CONFIG.alert.weapons and it.is_weapon then
          if pa_alert_weapon(it) then return end
        end
      end
    end
  end)
end

function pa_alert_item(it, alert_type, emoji, force_more)
  local item_desc = get_plussed_name(it, "plain")
  local alert_colors
  if it.is_weapon then
    alert_colors = ALERT_COLORS.weapon
    update_high_scores(it)
    item_desc = item_desc .. with_color(ALERT_COLORS.weapon.stats, " (" .. get_weapon_info_string(it) .. ")")
  elseif is_body_armour(it) then
    alert_colors = ALERT_COLORS.body_arm
    update_high_scores(it)
    local ac, ev = get_armour_info_strings(it)
    item_desc = item_desc .. with_color(ALERT_COLORS.body_arm.stats, " {" .. ac .. ", " .. ev .. "}")
  elseif is_armour(it) then
    alert_colors = ALERT_COLORS.aux_arm
  elseif is_orb(it) then
    alert_colors = ALERT_COLORS.orb
  elseif is_talisman(it) then
    alert_colors = ALERT_COLORS.talisman
  else 
    alert_colors = ALERT_COLORS.misc
  end
  local tokens = {}
  tokens[1] = emoji and emoji or with_color(COLORS.cyan, "----")
  tokens[#tokens+1] = with_color(alert_colors.desc, " " .. alert_type .. ": ")
  tokens[#tokens+1] = with_color(alert_colors.item, item_desc .. " ")
  tokens[#tokens+1] = tokens[1]

  enqueue_mpr_opt_more(force_more or has_configured_force_more(it), table.concat(tokens))

  pa_recent_alerts[#pa_recent_alerts+1] = get_plussed_name(it)
  add_to_pa_table(pa_items_alerted, it)
  you.stop_activity()
  return true
end

------------------- Hooks -------------------
function c_assign_invletter_item_alerts(it)
  pa_alert_OTA(it)
  add_to_pa_table(pa_items_picked, it)
  local name, _ = get_pa_keys(it)
  pa_items_alerted[name] = nil
  util.remove(pa_recent_alerts, get_plussed_name(it))

  if it.is_weapon or is_armour(it) then
    update_high_scores(it)
  end
end

function c_message_item_alerts(text, channel)
  if channel == "multiturn" then
    if not pause_pa_system and text:find("ou start ", 1, true) then
      pause_pa_system = true
    end
  elseif channel == "plain" then
    if pause_pa_system and (text:find("ou stop ", 1, true) or text:find("ou finish ", 1, true)) then
      pause_pa_system = false
    elseif text:find("one exploring", 1, true) or text:find("artly explored", 1, true) then
      local tokens = {}
      for _,v in ipairs(pa_recent_alerts) do
        tokens[#tokens+1] = "\n  " .. v
      end
      if #tokens > 0 then
        enqueue_mpr(with_color(COLORS.magenta, "Recent alerts:" .. table.concat(tokens)))
      end
      pa_recent_alerts = {}
    end
  end
end

function ready_item_alerts()
  if pause_pa_system then return end
  ready_pa_weapons()
  update_high_scores(items.equipped_at("armour"))
end
