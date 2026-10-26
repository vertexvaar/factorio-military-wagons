local config = require("config")

-- The wagons' grid takes everything the tank's grid takes, plus the armour plates.
local tank = data.raw["car"]["tank"]
local tank_grid = tank and tank.equipment_grid and data.raw["equipment-grid"][tank.equipment_grid]
if tank_grid then
  local grid = data.raw["equipment-grid"][config.grid]
  for _, category in pairs(tank_grid.equipment_categories) do
    if category ~= config.armor_category then table.insert(grid.equipment_categories, category) end
  end
end

-- Mine launchers answer only their own remote's flares, so the artillery remote's
-- flares must not call them: those are for artillery shells.
if data.raw["artillery-flare"]["mine-launcher-flare"] then
  local flare = data.raw["artillery-flare"]["artillery-flare"]
  if flare and not flare.shot_category then flare.shot_category = "artillery-shell" end
end

-- Cannon wagon turrets fire copies of every tank shell that pass their own side (see
-- config.shell_category). The tank and its shells stay as they are.
if data.raw["ammo-turret"]["twin-cannon-wagon-turret"] or data.raw["ammo-turret"]["howitzer-wagon-turret"] then
  data:extend({ { type = "ammo-category", name = config.shell_category, hidden = true } })

  -- every trigger in a copy's actions (impact and the explosion at the end) spares its own side
  local function spare(node)
    if type(node) ~= "table" then return end
    if node.type == "area" or node.type == "direct" or node.type == "line" or node.type == "cluster" then
      node.force = "not-same"
    end
    for _, child in pairs(node) do
      spare(child)
    end
  end

  -- points every projectile in an ammo type at its copy, made on first use
  local function own_side(node)
    if type(node) ~= "table" then return end
    if node.type == "projectile" and node.projectile then
      local copy = config.shell_prefix .. node.projectile
      if not data.raw["projectile"][copy] and data.raw["projectile"][node.projectile] then
        local projectile = table.deepcopy(data.raw["projectile"][node.projectile])
        projectile.name = copy
        projectile.force_condition = "not-same"
        -- flies on along its line through the target point, like vtk-cannon-turret's shells
        projectile.direction_only = true
        spare(projectile.action)
        spare(projectile.final_action)
        data:extend({ projectile })
      end
      node.projectile = copy
      node.max_range = math.max(node.max_range or 0, config.shell_range)
    end
    for _, child in pairs(node) do
      own_side(child)
    end
  end

  local shells = {}
  for name, ammo in pairs(data.raw["ammo"]) do
    if ammo.ammo_category == "cannon-shell" then shells[#shells + 1] = ammo end
  end
  for _, ammo in pairs(shells) do
    local copy = table.deepcopy(ammo)
    copy.name = config.shell_prefix .. ammo.name
    copy.localised_name = ammo.localised_name or { "item-name." .. ammo.name }
    copy.localised_description = ammo.localised_description or { "item-description." .. ammo.name }
    copy.ammo_category = config.shell_category
    copy.hidden = true
    copy.hidden_in_factoriopedia = true
    copy.auto_recycle = false
    own_side(copy.ammo_type)
    data:extend({ copy })
  end

  -- research that improves cannon shells improves the copies too
  for _, technology in pairs(data.raw["technology"]) do
    local added = {}
    for _, effect in pairs(technology.effects or {}) do
      if (effect.type == "ammo-damage" or effect.type == "gun-speed") and effect.ammo_category == "cannon-shell" then
        local copy = table.deepcopy(effect)
        copy.ammo_category = config.shell_category
        copy.hidden = true
        added[#added + 1] = copy
      end
    end
    for _, effect in pairs(added) do
      table.insert(technology.effects, effect)
    end
  end
end
