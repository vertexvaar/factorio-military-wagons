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
