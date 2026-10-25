local rig = require("prototypes.rig")
local graphics = require("prototypes.graphics")

-- config: this wagon's entry in config.wagons
return function(config)
  -- The wagon: a fluid wagon whose oil feeds the flamethrowers on its roof.
  local wagon = table.deepcopy(data.raw["fluid-wagon"]["fluid-wagon"])
  wagon.name = config.name
  wagon.icons = {
    { icon = "__base__/graphics/icons/fluid-wagon.png", icon_size = 64 },
    { icon = "__base__/graphics/icons/flamethrower-turret.png", icon_size = 64, scale = 0.3, shift = { 8, -8 } },
  }
  wagon.icon = nil
  wagon.minable = { mining_time = 0.5, result = config.name }
  wagon.capacity = 25000
  wagon.color = { r = 0.55, g = 0.3, b = 0.15, a = 1 }
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
  wagon.icons = graphics.icons(config.variant, "__base__/graphics/icons/flamethrower-turret.png") or wagon.icons
  -- its own flames must not hurt it: enemies that attack the train stand right next to it
  for _, r in pairs(wagon.resistances) do
    if r.type == "fire" then r.percent = 100 end
  end

  local item = table.deepcopy(data.raw["item-with-entity-data"]["fluid-wagon"])
  item.name = config.name
  item.icons = wagon.icons
  item.icon = nil
  item.place_result = config.name
  item.order = "c[rolling-stock]-c[fluid-wagon]-t[flamethrower-turret-wagon]"

  local turret = rig.turret(data.raw["fluid-turret"]["flamethrower-turret"], config.turret, -0.9)
  -- a roof turret has no pipes and covers all sides, not just the front
  turret.fluid_box.pipe_connections = {}
  turret.fluid_box.pipe_covers = nil
  turret.fluid_box.pipe_picture = nil
  turret.attack_parameters.turn_range = 1
  -- enemies attacking the train stand next to it; the wagon itself is fireproof
  turret.attack_parameters.min_range = 2
  turret.not_enough_fuel_indicator_picture = nil
  turret.enough_fuel_indicator_picture = nil
  turret.not_enough_fuel_indicator_light = nil
  turret.enough_fuel_indicator_light = nil

  data:extend({
    wagon,
    item,
    {
      type = "recipe",
      name = config.name,
      energy_required = 5,
      enabled = false,
      ingredients = {
        { type = "item", name = "fluid-wagon", amount = 1 },
        { type = "item", name = "flamethrower-turret", amount = 2 },
        { type = "item", name = "steel-plate", amount = 20 },
      },
      results = { { type = "item", name = config.name, amount = 1 } },
    },
    {
      type = "technology",
      name = config.name,
      icons = {
        { icon = "__base__/graphics/technology/railway.png", icon_size = 256 },
        { icon = "__base__/graphics/technology/flamethrower.png", icon_size = 256, scale = 0.25, shift = { 32, 32 } },
      },
      effects = { { type = "unlock-recipe", recipe = config.name } },
      prerequisites = { "fluid-wagon", "flamethrower" },
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
  data:extend(rig.variants(turret, config.mounts))
end
