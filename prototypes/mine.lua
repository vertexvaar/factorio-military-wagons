local rig = require("prototypes.rig")
local graphics = require("prototypes.graphics")

-- Mine launcher wagon: an artillery wagon that throws land mines, only where the player
-- points the mine launcher remote. Its flares carry their own shot category, so real
-- artillery ignores them, and the vanilla artillery flare gets the artillery shell
-- category in data-final-fixes.lua, so the launcher ignores those in turn.
local CATEGORY = "wagon-mine"
local RANGE = 120
local MIN_RANGE = 16
-- one thrown mine is a package of this many land mines, scattered around the target
local MINES_PER_SHOT = 5
local SCATTER = 2.5

-- config: this wagon's entry in config.wagons
return function(config)
  local wagon = table.deepcopy(data.raw["artillery-wagon"]["artillery-wagon"])
  wagon.name = config.name
  wagon.icons = {
    { icon = "__base__/graphics/icons/artillery-wagon.png", icon_size = 64 },
    { icon = "__base__/graphics/icons/land-mine.png", icon_size = 64, scale = 0.3, shift = { 8, -8 } },
  }
  wagon.icon = nil
  wagon.minable = { mining_time = 0.5, result = config.name }
  wagon.gun = "mine-launcher"
  wagon.disable_automatic_firing = true
  wagon.inventory_size = 2
  wagon.ammo_stack_limit = 100
  wagon.automated_ammo_count = 20
  wagon.color = { r = 0.33, g = 0.35, b = 0.24, a = 1 }
  wagon.allow_manual_color = true
  wagon.factoriopedia_simulation = nil
  -- the launcher baskets are part of the wagon picture and do not turn: no vanilla cannon
  -- on the roof, and the aim needs no turning before a shot
  wagon.cannon_base_pictures = nil
  wagon.cannon_barrel_pictures = nil
  wagon.cannon_base_shift_when_horizontal = 0
  wagon.cannon_base_shift_when_vertical = 0
  wagon.cannon_base_height = 1.9
  wagon.cannon_parking_frame_count = 0
  wagon.turret_rotation_speed = 1
  wagon.turn_after_shooting_cooldown = 0
  wagon.rotating_sound = nil
  rig.armour(wagon)
  local pictures = graphics.wagon_pictures(config.variant)
  if pictures then wagon.pictures = pictures end
  wagon.icons = graphics.icons(config.variant, "__base__/graphics/icons/land-mine.png") or wagon.icons

  local item = table.deepcopy(data.raw["item-with-entity-data"]["artillery-wagon"])
  item.name = config.name
  item.icons = wagon.icons
  item.icon = nil
  item.place_result = config.name
  item.order = "c[rolling-stock]-e[artillery-wagon]-m[mine-launcher-wagon]"

  local gun = table.deepcopy(data.raw["gun"]["artillery-wagon-cannon"])
  gun.name = "mine-launcher"
  gun.attack_parameters.ammo_category = CATEGORY
  gun.attack_parameters.ammo_categories = nil
  gun.attack_parameters.range = RANGE
  gun.attack_parameters.min_range = MIN_RANGE
  gun.attack_parameters.cooldown = 60
  gun.attack_parameters.projectile_creation_distance = 0
  gun.attack_parameters.projectile_center = { 0, 0 }
  gun.attack_parameters.projectile_creation_parameters = nil

  -- the package flies like a shell and scatters armed land mines of the wagon's force
  local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
  projectile.name = "wagon-mine-projectile"
  projectile.reveal_map = false
  projectile.picture = {
    filename = "__base__/graphics/icons/land-mine.png",
    width = 64,
    height = 64,
    scale = 0.25,
  }
  projectile.chart_picture = nil
  projectile.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        {
          type = "create-entity",
          entity_name = "land-mine",
          repeat_count = MINES_PER_SHOT,
          offset_deviation = { { -SCATTER, -SCATTER }, { SCATTER, SCATTER } },
          find_non_colliding_position = true,
          non_colliding_search_radius = 2,
          check_buildability = true,
        },
      },
    },
  }
  projectile.final_action = nil

  local shell = data.raw["ammo"]["artillery-shell"]
  local ammo_type = table.deepcopy(shell.ammo_type)
  ammo_type.action.action_delivery.projectile = "wagon-mine-projectile"

  local flare = table.deepcopy(data.raw["artillery-flare"]["artillery-flare"])
  flare.name = "mine-launcher-flare"
  flare.shot_category = CATEGORY
  flare.shots_per_flare = 1
  flare.map_color = { 0.9, 0.6, 0.1 }

  local remote = table.deepcopy(data.raw["capsule"]["artillery-targeting-remote"])
  remote.name = "mine-launcher-remote"
  remote.icons = {
    { icon = "__base__/graphics/icons/artillery-targeting-remote.png", icon_size = 64, tint = { 1, 0.75, 0.4 } },
    { icon = "__base__/graphics/icons/land-mine.png", icon_size = 64, scale = 0.3, shift = { 8, 8 } },
  }
  remote.icon = nil
  remote.capsule_action = { type = "artillery-remote", flare = "mine-launcher-flare" }
  remote.order = "zz[mine-launcher-remote]"

  local tech_units = {
    count = 200,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "military-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  }

  data:extend({
    { type = "ammo-category", name = CATEGORY },
    wagon,
    item,
    gun,
    projectile,
    flare,
    remote,
    {
      type = "ammo",
      name = "wagon-mine",
      icons = {
        { icon = "__base__/graphics/icons/land-mine.png", icon_size = 64 },
        { icon = "__base__/graphics/icons/explosives.png", icon_size = 64, scale = 0.3, shift = { 8, 8 } },
      },
      ammo_category = CATEGORY,
      ammo_type = ammo_type,
      subgroup = "ammo",
      order = "e[wagon-mine]",
      stack_size = 20,
    },
    {
      type = "recipe",
      name = "wagon-mine",
      energy_required = 4,
      enabled = false,
      ingredients = {
        { type = "item", name = "land-mine", amount = MINES_PER_SHOT },
        { type = "item", name = "explosives", amount = 1 },
      },
      results = { { type = "item", name = "wagon-mine", amount = 1 } },
    },
    {
      type = "recipe",
      name = "mine-launcher-remote",
      energy_required = 1,
      enabled = false,
      ingredients = {
        { type = "item", name = "electronic-circuit", amount = 1 },
        { type = "item", name = "land-mine", amount = 1 },
      },
      results = { { type = "item", name = "mine-launcher-remote", amount = 1 } },
    },
    {
      type = "recipe",
      name = config.name,
      energy_required = 5,
      enabled = false,
      ingredients = {
        { type = "item", name = "cargo-wagon", amount = 1 },
        { type = "item", name = "steel-plate", amount = 40 },
        { type = "item", name = "iron-gear-wheel", amount = 20 },
        { type = "item", name = "advanced-circuit", amount = 10 },
      },
      results = { { type = "item", name = config.name, amount = 1 } },
    },
    {
      type = "technology",
      name = config.name,
      icons = {
        { icon = "__base__/graphics/technology/railway.png", icon_size = 256 },
        { icon = "__base__/graphics/technology/land-mine.png", icon_size = 256, scale = 0.25, shift = { 32, 32 } },
      },
      effects = {
        { type = "unlock-recipe", recipe = config.name },
        { type = "unlock-recipe", recipe = "wagon-mine" },
        { type = "unlock-recipe", recipe = "mine-launcher-remote" },
      },
      prerequisites = { "railway", "land-mine", "explosives" },
      unit = tech_units,
    },
  })
end
