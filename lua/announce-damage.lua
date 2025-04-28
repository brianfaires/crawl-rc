------------------------------------------
---- Damage Calc (attribution needed) ----
------------------------------------------
local previous_hp = 0
local previous_mp = 0
local previous_form = ""
local was_berserk_last_turn = false

function ready_announce_damage()
  local current_hp, max_hp = you.hp()
  local current_mp, max_mp = you.mp()
  --Things that increase hp/mp temporarily really mess with this
  local current_form = you.transform()
  local you_are_berserk = you.berserk()
  local max_hp_increased = false
  local max_hp_decreased = false

  if (current_form ~= previous_form) then
    if (previous_form:find("dragon") or
        previous_form:find("statue") or
        previous_form:find("tree") or
        previous_form:find("ice")) then
      max_hp_decreased = true
    elseif (current_form:find("dragon") or
        current_form:find("statue") or
        current_form:find("tree") or
        current_form:find("ice")) then
      max_hp_increased = true
    end
  end
  if (was_berserk_last_turn and not you_are_berserk) then
    max_hp_decreased = true
  elseif (you_are_berserk and not was_berserk_last_turn) then
    max_hp_increased = true
  end


  --Skips message on initializing game
  if you.turns() > 1 then
    local hp_difference = previous_hp - current_hp
    local mp_difference = previous_mp - current_mp

    if max_hp_increased or max_hp_decreased then
      if max_hp_increased then
        crawl.mpr("<green>You now have " .. current_hp .. "/" .. max_hp .. " hp.</green>")
      else
        crawl.mpr("<yellow>You now have " .. current_hp .. "/" .. max_hp .. " hp.</yellow>")
      end
    else
      --On losing health
      if (current_hp < previous_hp) then
        local msg
        if current_hp <= (max_hp * 0.30) then
          msg = "<red>You take " .. hp_difference .. " damage,</red>" ..
                    "<lightred> and have " .. current_hp .. "/" .. max_hp .. " hp.</lightred>"
        elseif current_hp <= (max_hp * 0.50) then
          msg = "<red>You take " .. hp_difference .. " damage, and have " ..
                  current_hp .. "/" .. max_hp .. " hp.</red>"
        elseif current_hp <= (max_hp *  0.70) then
          msg = "<red>You take " .. hp_difference .. " damage,</red><yellow> and have " ..
                  current_hp .. "/" .. max_hp .. " hp.</yellow>"
        elseif current_hp <= (max_hp * 0.90) then
          msg = "<red>You take " .. hp_difference .. " damage,</red><lightgrey> and have " ..
                  current_hp .. "/" .. max_hp .. " hp.</lightgrey>"
        else
          msg = "<red>You take " .. hp_difference .. " damage,</red><green> and have " ..
                  current_hp .. "/" .. max_hp .. " hp.</green>"
        end
        crawl.mpr(msg)

        if hp_difference > (max_hp * 0.20) then
          crawl.mpr("<lightred>MASSIVE DAMAGE!!</lightred>")
        end
      end

      --On gaining more than 2 HP
      if (current_hp > previous_hp + 2) then
        --Removes the negative sign
        local health_inturn = (0 - hp_difference)
        if (health_inturn > 1) and current_hp ~= max_hp then
          local msg
          if current_hp <= (max_hp * 0.30) then
            msg = "<green>You regained " .. health_inturn .. " hp,</green><lightred> and now have " ..
                    current_hp .. "/" .. max_hp .. " hp.</lightred>"
          elseif current_hp <= (max_hp * 0.50) then
            msg = "<green>You regained " .. health_inturn .. " hp,</green><red> and now have " ..
                    current_hp .. "/" .. max_hp .. " hp.</red>"
          elseif current_hp <= (max_hp *  0.70) then
            msg = "<green>You regained " .. health_inturn .. " hp,</green><yellow> and now have " ..
                    current_hp .. "/" .. max_hp .. " hp.</yellow>"
          elseif current_hp <= (max_hp * 0.90) then
            msg = "<green>You regained " .. health_inturn .. " hp,</green><lightgrey> and now have " ..
                    current_hp .. "/" .. max_hp .. " hp.</lightgrey>"
          else
            msg = "<green>You regained " .. health_inturn .. " hp, and now have " .. current_hp .. "/" ..
                      max_hp .. " hp.</green>"
          end
          crawl.mpr(msg)
        end
        if (current_hp == max_hp) then
          crawl.mpr("<green>Health restored: " .. current_hp .. "</green>")
        end
      end

      --On gaining more than 1 MP
      if (current_mp > previous_mp+1) then
        --Removes the negative sign
        local mp_inturn = (0 - mp_difference)
        if (mp_inturn > 1) and current_mp ~= max_mp then
          local msg
          if current_mp < (max_mp * 0.25) then
            msg = "<lightcyan>You regained " .. mp_inturn .. " mp,</lightcyan><red> and now have " ..
                    current_mp .. "/" .. max_mp .. " mp.</red>"
          elseif current_mp < (max_mp * 0.50) then
            msg = "<lightcyan>You regained " .. mp_inturn .. " mp,</lightcyan><yellow> and now have " ..
                    current_mp .. "/" .. max_mp .. " mp.</yellow>"
          else
            msg = "<lightcyan>You regained " .. mp_inturn .. " mp,</lightcyan><green> and now have " ..
                    current_mp .. "/" .. max_mp .. " mp.</green>"
          end
          crawl.mpr(msg)
        end
        if (current_mp == max_mp) then
          crawl.mpr("<lightcyan>MP restored: " .. current_mp .. "</lightcyan>")
        end
      end

      --On losing magic
      if current_mp < previous_mp then
        if current_mp <= (max_mp / 5) then
          crawl.mpr("<lightcyan>You now have </lightcyan><red>" .. current_mp .. "/" ..max_mp .." mp.</red>")
        elseif current_mp <= (max_mp / 2) then
          crawl.mpr("<lightcyan>You now have </lightcyan><yellow>" .. current_mp .. "/" ..max_mp .." mp.</yellow>")
        else
          crawl.mpr("<lightcyan>You now have </lightcyan><green>" .. current_mp .. "/" ..max_mp .." mp.</green>")
        end
      end
    end
  end

  --Set previous hp/mp and form at end of turn
  previous_hp = current_hp
  previous_mp = current_mp
  previous_form = current_form
  was_berserk_last_turn = you_are_berserk
end
