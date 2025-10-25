----------------------------------
---- BRC.it - Item attributes ----
BRC.it = {}

function BRC.it.get_xy(name, radius)
  local r = radius or you.los()
  for dx = -r, r do
    for dy = -r, r do
      for _, fl in ipairs(items.get_items_at(dx, dy) or {}) do
        if fl.name() == name then
          return dx, dy
        end
      end
    end
  end
end

function BRC.it.get_staff_school(it)
  for k, v in pairs(BRC.MAGIC_SCHOOLS) do
    if it.subtype() == k then return v end
  end
end

function BRC.it.get_talisman_min_level(it)
  if it.name() == "protean talisman" then return 6 end

  -- Parse the item description
  local tokens = crawl.split(it.description, "\n")
  for _, v in ipairs(tokens) do
    if v:sub(1, 4) == "Min " then
      local start_pos = v:find("%d", 4)
      if start_pos then
        local end_pos = v:find("[^%d]", start_pos)
        return tonumber(v:sub(start_pos, end_pos - 1))
      end
    end
  end

  BRC.mpr.error("Failed to find skill required for: " .. it.name())
  return -1
end


---- Simple boolean checks ----
function BRC.it.is_amulet(it)
  return it and it.name("base") == "amulet"
end

function BRC.it.is_armour(it, include_orbs)
  return it and it.class(true) == "armour" and (include_orbs or not BRC.it.is_orb(it))
end

function BRC.it.is_aux_armour(it)
  return BRC.it.is_armour(it) and not (BRC.it.is_body_armour(it) or BRC.it.is_shield(it))
end

function BRC.it.is_body_armour(it)
  return it and it.subtype() == "body"
end

function BRC.it.is_jewellery(it)
  return it and it.class(true) == "jewellery"
end

function BRC.it.is_magic_staff(it)
  return it and it.class and it.class(true) == "magical staff"
end

function BRC.it.is_ring(it)
  return it and it.name("base") == "ring"
end

function BRC.it.is_scarf(it)
  return BRC.it.is_armour(it) and it.subtype() == "cloak" and it.name():contains("scarf")
end

function BRC.it.is_shield(it)
  return it and it.is_shield()
end

function BRC.it.is_talisman(it)
  return it and it.class(true) == "talisman"
end

function BRC.it.is_orb(it)
  return it and it.subtype() == "offhand" and not it.is_shield()
end

function BRC.it.is_polearm(it)
  return it and it.weap_skill:contains("Polearms")
end
