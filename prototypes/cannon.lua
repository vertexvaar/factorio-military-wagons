local rig = require("prototypes.rig")
local graphics = require("prototypes.graphics")

-- The tank's turret graphics, without the layers tinted in the player colour.
local function tank_turret_animation()
  local animation = table.deepcopy(data.raw["car"]["tank"].turret_animation)
  local layers = {}
  for _, layer in pairs(animation.layers or { animation }) do
    if not layer.apply_runtime_tint then layers[#layers + 1] = layer end
  end
  return { layers = layers }
end

-- What sets the cannon wagons apart. Both fire tank shells.
local KINDS = {
  -- two tank turrets, exactly like the tank's
  twin = {
    order = "v[twin-cannon-wagon]",
    ingredients = {
      { type = "item", name = "cargo-wagon", amount = 1 },
      { type = "item", name = "steel-plate", amount = 50 },
      { type = "item", name = "iron-gear-wheel", amount = 20 },
      { type = "item", name = "advanced-circuit", amount = 10 },
    },
    count = 250,
  },
  -- one long barrel: further, but not close up; half the tank's rate of fire, and it turns
  -- slower than a tank turret, though faster than artillery
  howitzer = {
    order = "w[howitzer-wagon]",
    range = 36,
    min_range = 12,
    cooldown_factor = 2,
    rotation_speed = 0.003,
    ingredients = {
      { type = "item", name = "cargo-wagon", amount = 1 },
      { type = "item", name = "steel-plate", amount = 80 },
      { type = "item", name = "iron-gear-wheel", amount = 30 },
      { type = "item", name = "advanced-circuit", amount = 20 },
    },
    count = 300,
  },
}

-- config: this wagon's entry in config.wagons
return function(config)
  local kind = KINDS[config.variant]
  -- The wagon: a cargo wagon whose shells feed the turrets on its roof.
  local wagon = table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
  wagon.name = config.name
  wagon.icons = {
    { icon = "__base__/graphics/icons/cargo-wagon.png", icon_size = 64 },
    { icon = "__base__/graphics/icons/tank.png", icon_size = 64, scale = 0.3, shift = { 8, -8 } },
  }
  wagon.icon = nil
  wagon.minable = { mining_time = 0.5, result = config.name }
  wagon.inventory_size = 10
  wagon.color = { r = 0.3, g = 0.35, b = 0.25, a = 1 }
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
  wagon.icons = graphics.icons(config.variant, "__base__/graphics/icons/tank.png") or wagon.icons

  local item = table.deepcopy(data.raw["item-with-entity-data"]["cargo-wagon"])
  item.name = config.name
  item.icons = wagon.icons
  item.icon = nil
  item.place_result = config.name
  item.order = "c[rolling-stock]-b[cargo-wagon]-" .. kind.order

  -- A tank turret: the tank's cannon, range and turning speed, unless the kind says otherwise.
  local turret = rig.turret(data.raw["ammo-turret"]["gun-turret"], config.turret, 0)
  local tank = data.raw["car"]["tank"]
  local cannon = data.raw["gun"]["tank-cannon"]
  turret.attack_parameters = table.deepcopy(cannon.attack_parameters)
  turret.attack_parameters.turn_range = 1
  turret.attack_parameters.range = kind.range or turret.attack_parameters.range
  turret.attack_parameters.min_range = kind.min_range
  turret.attack_parameters.cooldown = turret.attack_parameters.cooldown * (kind.cooldown_factor or 1)
  turret.prepare_range = turret.attack_parameters.range + 4
  -- turret_rotation_speed is in turns per tick, like rotation_speed
  turret.rotation_speed = kind.rotation_speed or tank.turret_rotation_speed
  local animation = tank_turret_animation()
  turret.folded_animation = animation
  turret.prepared_animation = table.deepcopy(animation)
  turret.preparing_animation = nil
  turret.folding_animation = nil
  turret.attacking_animation = nil
  turret.starting_attack_animation = nil
  turret.ending_attack_animation = nil
  turret.energy_glow_animation = nil
  turret.muzzle_animation = nil
  turret.preparing_sound = nil
  turret.folding_sound = nil
  -- the tank turret already sits at tank roof height; the wagon deck is higher
  rig.lift_turret(turret, -0.55)
  -- Shells are real projectiles that hit whatever they cross, the own wagon too. They
  -- start where the tank starts them, near the turret's foot, not up at the drawn barrel:
  -- lifted, they would start north of the wagon and fly through it at targets to the south.
  turret.attack_parameters.projectile_center = table.deepcopy(cannon.attack_parameters.projectile_center)
  -- the tank starts shells 1.6 tiles out, past enemies that gnaw at the wagon; shells pass
  -- the own side (data-final-fixes.lua), so they can start at the turret
  turret.attack_parameters.projectile_creation_distance = 0.3

  data:extend({
    wagon,
    item,
    {
      type = "recipe",
      name = config.name,
      energy_required = 5,
      enabled = false,
      ingredients = kind.ingredients,
      results = { { type = "item", name = config.name, amount = 1 } },
    },
    {
      type = "technology",
      name = config.name,
      icons = {
        { icon = "__base__/graphics/technology/railway.png", icon_size = 256 },
        { icon = "__base__/graphics/technology/tank.png", icon_size = 256, scale = 0.25, shift = { 32, 32 } },
      },
      effects = { { type = "unlock-recipe", recipe = config.name } },
      prerequisites = { "railway", "tank" },
      unit = {
        count = kind.count,
        ingredients = {
          { "automation-science-pack", 1 },
          { "logistic-science-pack", 1 },
          { "military-science-pack", 1 },
          { "chemical-science-pack", 1 },
        },
        time = 30,
      },
    },
  })
  data:extend(rig.variants(turret, config.mounts))
end
