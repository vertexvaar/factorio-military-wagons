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
