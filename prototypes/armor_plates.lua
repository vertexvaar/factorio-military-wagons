-- The wagons' equipment grid and the armour plates that go into it.
--
-- Plates are powerless dummy equipment: their resistances are applied by control.lua,
-- since equipment cannot give a vehicle resistances. The grid also takes everything a
-- tank's grid takes (added in data-final-fixes.lua, after all mods have set up theirs).

local config = require("config")

local PLATE_ICON = "__base__/graphics/icons/steel-plate.png"
local PLATE_TINT = { 0.7, 0.8, 0.95 }

data:extend({
  { type = "equipment-category", name = config.armor_category },
  {
    type = "equipment-grid",
    name = config.grid,
    width = 16,
    height = 16,
    equipment_categories = { config.armor_category },
  },
})

-- placeholder graphics until the plate renders are done
local function plate(name, order)
  return {
    {
      type = "item",
      name = name,
      icons = { { icon = PLATE_ICON, icon_size = 64, tint = PLATE_TINT } },
      place_as_equipment_result = name,
      subgroup = "military-equipment",
      order = "f[military-wagon-armor]-" .. order,
      stack_size = 20,
    },
    {
      type = "battery-equipment",
      name = name,
      sprite = { filename = PLATE_ICON, width = 64, height = 64, scale = 2, tint = PLATE_TINT },
      shape = { width = 4, height = 4, type = "full" },
      -- a battery that holds nothing: equipment needs an energy source
      energy_source = { type = "electric", buffer_capacity = "1J", usage_priority = "tertiary" },
      categories = { config.armor_category },
    },
  }
end

data:extend(plate("composite-armor-plate", "a[composite]"))
data:extend({
  {
    type = "recipe",
    name = "composite-armor-plate",
    energy_required = 10,
    enabled = false,
    ingredients = {
      { type = "item", name = "armor-steel", amount = 10 },
      { type = "item", name = "steel-plate", amount = 5 },
    },
    results = { { type = "item", name = "composite-armor-plate", amount = 1 } },
  },
  {
    type = "technology",
    name = "composite-armor-plate",
    icons = { { icon = "__base__/graphics/technology/steel-processing.png", icon_size = 256, tint = PLATE_TINT } },
    effects = { { type = "unlock-recipe", recipe = "composite-armor-plate" } },
    prerequisites = { "armor-steel" },
    unit = {
      count = 150,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "military-science-pack", 1 },
      },
      time = 30,
    },
  },
})
