local rig = require("prototypes.rig")
local graphics = require("prototypes.graphics")

-- config: this wagon's entry in config.wagons
return function(config)
  -- The wagon: a cargo wagon whose cargo feeds the turrets on its roof.
  local wagon = table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
  wagon.name = config.name
  wagon.icons = {
    { icon = "__base__/graphics/icons/cargo-wagon.png", icon_size = 64 },
    { icon = "__base__/graphics/icons/gun-turret.png", icon_size = 64, scale = 0.3, shift = { 8, -8 } },
  }
  wagon.icon = nil
  wagon.minable = { mining_time = 0.5, result = config.name }
  wagon.inventory_size = 10
  wagon.color = { r = 0.35, g = 0.4, b = 0.25, a = 1 }
  wagon.allow_manual_color = true
  wagon.factoriopedia_simulation = nil
  rig.armour(wagon)
  local pictures = graphics.wagon_pictures(config.variant)
  if pictures then
    wagon.pictures = pictures
    -- an armoured wagon has no sliding doors
    wagon.horizontal_doors = nil
    wagon.vertical_doors = nil
  end
  wagon.icons = graphics.icons(config.variant, "__base__/graphics/icons/gun-turret.png") or wagon.icons

  local item = table.deepcopy(data.raw["item-with-entity-data"]["cargo-wagon"])
  item.name = config.name
  item.icons = wagon.icons
  item.icon = nil
  item.place_result = config.name
  item.order = "c[rolling-stock]-b[cargo-wagon]-t[gun-turret-wagon]"

  local turret = rig.turret(data.raw["ammo-turret"]["gun-turret"], config.turret, -0.75)

  data:extend({
    wagon,
    item,
    {
      type = "recipe",
      name = config.name,
      energy_required = 5,
      enabled = false,
      ingredients = {
        { type = "item", name = "cargo-wagon", amount = 1 },
        { type = "item", name = "gun-turret", amount = 3 },
        { type = "item", name = "steel-plate", amount = 20 },
      },
      results = { { type = "item", name = config.name, amount = 1 } },
    },
    {
      type = "technology",
      name = config.name,
      icons = {
        { icon = "__base__/graphics/technology/railway.png", icon_size = 256 },
        { icon = "__base__/graphics/technology/gun-turret.png", icon_size = 256, scale = 0.25, shift = { 32, 32 } },
      },
      effects = { { type = "unlock-recipe", recipe = config.name } },
      prerequisites = { "railway", "gun-turret", "steel-processing" },
      unit = {
        count = 100,
        ingredients = {
          { "automation-science-pack", 1 },
          { "logistic-science-pack", 1 },
        },
        time = 15,
      },
    },
  })
  data:extend(rig.variants(turret, config.mounts))
end
