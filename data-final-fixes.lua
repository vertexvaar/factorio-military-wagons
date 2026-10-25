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

-- Tank shells are projectiles that hit whatever they cross, also on their own side. From a
-- wagon turret a shell starts inside its own train whenever the target lies ahead or
-- behind, so the cannon wagons would shoot themselves. Shells pass their own side instead
-- (this applies to the tank as well).
if data.raw["ammo-turret"]["twin-cannon-wagon-turret"] or data.raw["ammo-turret"]["howitzer-wagon-turret"] then
  local function projectiles(node, found)
    if type(node) ~= "table" then return end
    if node.type == "projectile" and node.projectile then found[node.projectile] = true end
    for _, child in pairs(node) do
      projectiles(child, found)
    end
  end
  local found = {}
  for _, ammo in pairs(data.raw["ammo"]) do
    local category = ammo.ammo_category or (ammo.ammo_type and ammo.ammo_type.category)
    if category == "cannon-shell" then projectiles(ammo.ammo_type, found) end
  end
  for name in pairs(found) do
    local projectile = data.raw["projectile"][name]
    if projectile then projectile.force_condition = "not-same" end
  end
end
